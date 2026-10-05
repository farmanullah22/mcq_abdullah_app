const KhataEntry = require('../models/KhataEntry');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { recordAudit } = require('../middleware/auth');

const METHODS = ['cash', 'bank', 'cheque', 'online', 'easypaisa', 'jazzcard'];

// Every read/write is scoped to the admin who owns the khata, so one admin can
// never see or touch another admin's notebook.
const ownedBy = (req) => ({ createdBy: req.user._id });

const loadOwned = async (req, id) => {
  const entry = await KhataEntry.findOne({ _id: id, ...ownedBy(req) });
  if (!entry || entry.isDeleted) throw new ApiError(404, 'Khata entry not found.');
  return entry;
};

const listKhataEntries = asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page, 10) || 1;
  const limit = parseInt(req.query.limit, 10) || 30;
  const filter = { ...ownedBy(req), isDeleted: false };

  if (req.query.method) filter.method = req.query.method;
  if (req.query.direction === 'in' || req.query.direction === 'out') {
    filter.direction = req.query.direction;
  }
  if (req.query.customer) {
    // One free-text box matches either the name or the number.
    const rx = new RegExp(String(req.query.customer).trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
    filter.$or = [{ customerName: rx }, { customerNumber: rx }];
  }
  if (req.query.from || req.query.to) {
    filter.entryDate = {};
    if (req.query.from) filter.entryDate.$gte = new Date(req.query.from);
    if (req.query.to) filter.entryDate.$lte = new Date(req.query.to);
  }

  const [entries, total, summary] = await Promise.all([
    KhataEntry.find(filter)
      .sort({ entryDate: -1, createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit),
    KhataEntry.countDocuments(filter),
    // Totals and per-customer balances are computed over every entry the admin
    // owns, not just the current page, so the figures stay truthful while paging.
    KhataEntry.aggregate([
      { $match: { ...ownedBy(req), isDeleted: false } },
      {
        $facet: {
          totals: [
            {
              $group: {
                _id: null,
                given: { $sum: { $cond: [{ $eq: ['$direction', 'out'] }, '$amount', 0] } },
                received: { $sum: { $cond: [{ $eq: ['$direction', 'in'] }, '$amount', 0] } },
                entryCount: { $sum: 1 },
              },
            },
          ],
          balances: [
            {
              $group: {
                _id: { name: '$customerName', number: '$customerNumber' },
                customerName: { $first: '$customerName' },
                customerNumber: { $first: '$customerNumber' },
                given: { $sum: { $cond: [{ $eq: ['$direction', 'out'] }, '$amount', 0] } },
                received: { $sum: { $cond: [{ $eq: ['$direction', 'in'] }, '$amount', 0] } },
                entryCount: { $sum: 1 },
                lastActivity: { $max: '$entryDate' },
              },
            },
            { $addFields: { outstanding: { $subtract: ['$given', '$received'] } } },
            { $sort: { outstanding: -1, lastActivity: -1 } },
            { $limit: 50 },
          ],
        },
      },
    ]),
  ]);

  const totals = summary[0]?.totals?.[0] || { given: 0, received: 0, entryCount: 0 };

  res.json(
    ApiResponse.ok('Khata fetched', {
      entries,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
      totals: {
        given: totals.given,
        received: totals.received,
        outstanding: totals.given - totals.received,
        entryCount: totals.entryCount,
      },
      balances: summary[0]?.balances || [],
    })
  );
});

const createKhataEntry = asyncHandler(async (req, res) => {
  const { customerName, customerNumber, direction, amount, method, entryDate, notes } = req.body;

  if (!customerName || !String(customerName).trim()) throw new ApiError(400, 'Customer name is required.');
  if (direction !== 'in' && direction !== 'out') throw new ApiError(400, 'Direction must be either in or out.');
  const value = Number(amount);
  if (!Number.isFinite(value) || value <= 0) throw new ApiError(400, 'Amount must be greater than 0.');
  if (method && !METHODS.includes(method)) throw new ApiError(400, 'Invalid payment method.');

  const entry = await KhataEntry.create({
    customerName: String(customerName).trim(),
    customerNumber: customerNumber ? String(customerNumber).trim() : '',
    direction,
    amount: value,
    method: method || 'cash',
    entryDate: entryDate || new Date(),
    notes: notes ? String(notes).trim() : '',
    createdBy: req.user._id,
  });

  await recordAudit(req, {
    actionType: 'CREATE_KHATA',
    module: 'khata',
    recordId: entry._id,
    recordType: 'KhataEntry',
    newData: entry.toObject(),
    remarks: `Khata: ${direction === 'out' ? 'gave' : 'received'} Rs. ${value} ${method || 'cash'} ${direction === 'out' ? 'to' : 'from'} ${entry.customerName}`,
  });

  res.status(201).json(ApiResponse.created('Khata entry added', entry));
});

const updateKhataEntry = asyncHandler(async (req, res) => {
  const entry = await loadOwned(req, req.params.id);
  const oldData = entry.toObject();

  const { customerName, customerNumber, direction, amount, method, entryDate, notes } = req.body;
  if (customerName !== undefined) {
    if (!String(customerName).trim()) throw new ApiError(400, 'Customer name is required.');
    entry.customerName = String(customerName).trim();
  }
  if (customerNumber !== undefined) entry.customerNumber = String(customerNumber || '').trim();
  if (direction !== undefined) {
    if (direction !== 'in' && direction !== 'out') throw new ApiError(400, 'Direction must be either in or out.');
    entry.direction = direction;
  }
  if (amount !== undefined) {
    const value = Number(amount);
    if (!Number.isFinite(value) || value <= 0) throw new ApiError(400, 'Amount must be greater than 0.');
    entry.amount = value;
  }
  if (method !== undefined) {
    if (!METHODS.includes(method)) throw new ApiError(400, 'Invalid payment method.');
    entry.method = method;
  }
  if (entryDate !== undefined) entry.entryDate = entryDate;
  if (notes !== undefined) entry.notes = String(notes).trim();

  await entry.save();

  await recordAudit(req, {
    actionType: 'UPDATE_KHATA',
    module: 'khata',
    recordId: entry._id,
    recordType: 'KhataEntry',
    oldData,
    newData: entry.toObject(),
    remarks: `Khata entry for ${entry.customerName} updated`,
  });

  res.json(ApiResponse.ok('Khata entry updated', entry));
});

const deleteKhataEntry = asyncHandler(async (req, res) => {
  const { deleteReason } = req.body;
  const entry = await loadOwned(req, req.params.id);
  const oldData = entry.toObject();

  entry.isDeleted = true;
  entry.deletedBy = req.user._id;
  entry.deletedAt = new Date();
  entry.deleteReason = deleteReason ? String(deleteReason) : '';
  await entry.save();

  await recordAudit(req, {
    actionType: 'DELETE_KHATA',
    module: 'khata',
    recordId: entry._id,
    recordType: 'KhataEntry',
    oldData,
    newData: null,
    status: 'deleted',
    remarks: `Khata entry for ${entry.customerName} deleted`,
  });

  res.json(ApiResponse.ok('Khata entry deleted'));
});

const restoreKhataEntry = asyncHandler(async (req, res) => {
  const entry = await KhataEntry.findOne({ _id: req.params.id, ...ownedBy(req) });
  if (!entry) throw new ApiError(404, 'Khata entry not found.');

  entry.isDeleted = false;
  entry.deletedBy = null;
  entry.deletedAt = null;
  entry.deleteReason = '';
  await entry.save();

  await recordAudit(req, {
    actionType: 'RESTORE_KHATA',
    module: 'khata',
    recordId: entry._id,
    recordType: 'KhataEntry',
    oldData: null,
    newData: entry.toObject(),
    status: 'restored',
    remarks: `Khata entry for ${entry.customerName} restored`,
  });

  res.json(ApiResponse.ok('Khata entry restored', entry));
});

module.exports = {
  listKhataEntries,
  createKhataEntry,
  updateKhataEntry,
  deleteKhataEntry,
  restoreKhataEntry,
};