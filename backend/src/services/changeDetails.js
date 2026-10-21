/**
 * Turns an audit record (old/new snapshots) into a human readable description
 * of *what* actually changed: which item, which fields, old value -> new value
 * and by how much.
 *
 * The admin needs to see this without opening raw JSON, e.g.
 *   "Premium Carpet 12x18" · Qty 120 -> 95 (-25) · Selling price Rs. 1,200 -> Rs. 1,350
 *
 * The result is used for three places:
 *   1. the admin notification (title/body + structured `data.details`)
 *   2. the audit log entry (`facts` / `changes` columns)
 *   3. the "Recent Activity" feed on the dashboard
 */

const TEXT = 'text';
const NUMBER = 'number';
const MONEY = 'money';
const BOOL = 'bool';
const DATE = 'date';

// Never report these: they carry no business meaning and would only add noise.
const IGNORED_FIELDS = new Set([
  '_id',
  '__v',
  'createdAt',
  'updatedAt',
  'deletedAt',
  'deletedBy',
  'isDeleted',
  'deleteReason',
  'whatsappReceipt',
  'images',
  'variants',
  'colorStocks',
  'sizeStocks',
  'carpetPiecesData',
  'transactions',
  'restocked',
  'shop',
  'createdBy',
  'by',
  'performedBy',
]);

// Ordered per record type. The first entries are the ones shown as "facts"
// when something is created or deleted.
const FIELD_SPECS = {
  Product: [
    { key: 'name', label: 'Name' },
    { key: 'productName', label: 'Name' },
    { key: 'sku', label: 'SKU' },
    { key: 'barcode', label: 'Barcode' },
    { key: 'productType', label: 'Type' },
    { key: 'category', label: 'Category' },
    { key: 'brand', label: 'Brand' },
    { key: 'supplier', label: 'Supplier' },
    { key: 'quantity', label: 'Quantity', kind: NUMBER },
    { key: 'costPrice', label: 'Cost price', kind: MONEY },
    { key: 'sellingPrice', label: 'Selling price', kind: MONEY },
    { key: 'lowStockThreshold', label: 'Low-stock limit', kind: NUMBER },
    { key: 'color', label: 'Colour' },
    { key: 'size', label: 'Size' },
    { key: 'carpetWidth', label: 'Carpet width', kind: NUMBER },
    { key: 'carpetHeight', label: 'Carpet height', kind: NUMBER },
    { key: 'carpetPieces', label: 'Carpet pieces', kind: NUMBER },
    { key: 'meterLength', label: 'Meter length', kind: NUMBER },
    { key: 'costPerSqft', label: 'Cost / sqft', kind: MONEY },
    { key: 'costPerPiece', label: 'Cost / piece', kind: MONEY },
    { key: 'costPerMeter', label: 'Cost / meter', kind: MONEY },
    { key: 'foamLength', label: 'Foam length', kind: NUMBER },
    { key: 'foamWidth', label: 'Foam width', kind: NUMBER },
    { key: 'foamThickness', label: 'Foam thickness', kind: NUMBER },
    { key: 'foamType', label: 'Foam type' },
    { key: 'pillowSize', label: 'Pillow size' },
    { key: 'pillowStock', label: 'Pillow stock', kind: NUMBER },
    { key: 'coverStock', label: 'Cover stock', kind: NUMBER },
    { key: 'description', label: 'Description' },
  ],
  Sale: [
    { key: 'invoiceNo', label: 'Invoice' },
    { key: 'customerName', label: 'Customer' },
    { key: 'customerPhone', label: 'Phone' },
    { key: 'subtotal', label: 'Subtotal', kind: MONEY },
    { key: 'discount', label: 'Discount', kind: MONEY },
    { key: 'totalAmount', label: 'Total', kind: MONEY },
    { key: 'paidAmount', label: 'Paid', kind: MONEY },
    { key: 'dueAmount', label: 'Due', kind: MONEY },
    { key: 'profit', label: 'Profit', kind: MONEY },
    { key: 'paymentMethod', label: 'Payment method' },
    { key: 'notes', label: 'Notes' },
  ],
  Expense: [
    { key: 'category', label: 'Category' },
    { key: 'amount', label: 'Amount', kind: MONEY },
    { key: 'expenseDate', label: 'Date', kind: DATE },
    { key: 'description', label: 'Description' },
  ],
  Customer: [
    { key: 'name', label: 'Name' },
    { key: 'phone', label: 'Phone' },
    { key: 'email', label: 'Email' },
    { key: 'address', label: 'Address' },
    { key: 'city', label: 'City' },
    { key: 'balance', label: 'Balance', kind: MONEY },
    { key: 'adjustment', label: 'Amount', kind: MONEY },
    { key: 'totalSpent', label: 'Total spent', kind: MONEY },
    { key: 'purchaseCount', label: 'Purchases', kind: NUMBER },
    { key: 'notes', label: 'Notes' },
  ],
  Supplier: [
    { key: 'name', label: 'Name' },
    { key: 'phone', label: 'Phone' },
    { key: 'email', label: 'Email' },
    { key: 'address', label: 'Address' },
    { key: 'city', label: 'City' },
    { key: 'balance', label: 'Balance', kind: MONEY },
    { key: 'adjustment', label: 'Amount', kind: MONEY },
    { key: 'notes', label: 'Notes' },
  ],
  Category: [
    { key: 'name', label: 'Name' },
    { key: 'description', label: 'Description' },
  ],
  Shop: [
    { key: 'name', label: 'Name' },
    { key: 'shopType', label: 'Type' },
    { key: 'address', label: 'Address' },
    { key: 'contactNumber', label: 'Contact' },
    { key: 'manager', label: 'Manager' },
  ],
  User: [
    { key: 'name', label: 'Name' },
    { key: 'email', label: 'Email' },
    { key: 'phone', label: 'Phone' },
    { key: 'role', label: 'Role' },
  ],
  Manager: [
    { key: 'name', label: 'Name' },
    { key: 'email', label: 'Email' },
    { key: 'phone', label: 'Phone' },
    { key: 'role', label: 'Role' },
  ],
  KhataEntry: [
    { key: 'customerName', label: 'Customer' },
    { key: 'customerNumber', label: 'Number' },
    { key: 'direction', label: 'Direction' },
    { key: 'amount', label: 'Amount', kind: MONEY },
    { key: 'method', label: 'Method' },
    { key: 'entryDate', label: 'Date', kind: DATE },
    { key: 'notes', label: 'Notes' },
  ],
  Report: [{ key: 'reportType', label: 'Report' }],
  AuditLog: [{ key: 'actionType', label: 'Action' }],
};

// Fallback for anything not listed above.
const GENERIC_SPEC = [
  { key: 'name', label: 'Name' },
  { key: 'title', label: 'Title' },
  { key: 'amount', label: 'Amount', kind: MONEY },
  { key: 'quantity', label: 'Quantity', kind: NUMBER },
  { key: 'description', label: 'Description' },
];

// How many facts are shown for a create/delete.
const MAX_FACTS = 6;
// How many field-level changes are kept for an update.
const MAX_CHANGES = 12;

const formatNumber = (value) => {
  const num = Number(value);
  if (!Number.isFinite(num)) return String(value);
  const abs = Math.abs(num);
  const [int, dec] = abs.toFixed(2).split('.');
  const withCommas = int.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  const fraction = dec && dec !== '00' ? `.${dec}` : '';
  return `${num < 0 ? '-' : ''}${withCommas}${fraction}`;
};

const formatMoney = (value) => `Rs. ${formatNumber(value)}`;

// A populated reference (e.g. category) arrives as an object, a raw one as an id.
const refName = (value) => {
  if (value == null) return '';
  if (typeof value === 'object') {
    return String(value.name || value.title || value.email || value._id || '');
  }
  return String(value);
};

const isEmpty = (value) => {
  if (value === undefined || value === null) return true;
  if (typeof value === 'string') return value.trim() === '';
  if (Array.isArray(value)) return value.length === 0;
  if (typeof value === 'object') return Object.keys(value).length === 0;
  return false;
};

const formatValue = (spec, value) => {
  if (value === undefined || value === null || value === '') return '';
  switch (spec.kind) {
    case MONEY:
      return formatMoney(value);
    case NUMBER:
      return formatNumber(value);
    case BOOL:
      return value === true || value === 'true' ? 'Yes' : 'No';
    case DATE: {
      const d = new Date(value);
      if (Number.isNaN(d.getTime())) return String(value);
      return d.toISOString().slice(0, 10);
    }
    default:
      return refName(value);
  }
};

// Compares two raw values; numbers are compared numerically so "120" and 120
// are not reported as a change.
const isDifferent = (a, b) => {
  if (a === b) return false;
  const aEmpty = isEmpty(a);
  const bEmpty = isEmpty(b);
  if (aEmpty && bEmpty) return false;
  if (aEmpty !== bEmpty) return true;
  if (typeof a === 'number' || typeof b === 'number') {
    const na = Number(a);
    const nb = Number(b);
    if (Number.isFinite(na) && Number.isFinite(nb)) return na !== nb;
  }
  if (Array.isArray(a) && Array.isArray(b)) {
    return JSON.stringify(a) !== JSON.stringify(b);
  }
  if (typeof a === 'object' && typeof b === 'object') {
    return JSON.stringify(a) !== JSON.stringify(b);
  }
  return String(a) !== String(b);
};

const deltaFor = (spec, from, to) => {
  if (spec.kind !== NUMBER && spec.kind !== MONEY) return '';
  const a = Number(from);
  const b = Number(to);
  if (!Number.isFinite(a) || !Number.isFinite(b)) return '';
  const diff = b - a;
  if (diff === 0) return '';
  const sign = diff > 0 ? '+' : '-';
  const text = spec.kind === MONEY ? formatMoney(Math.abs(diff)) : formatNumber(Math.abs(diff));
  return `${sign}${text}`;
};

// Stock movements carry their own meaning (how much went in / out).
// Returns the change list for a stock movement.
const stockChanges = (actionType, oldData, newData) => {
  const changes = [];
  if (!newData) return changes;
  const num = (v) => (v === undefined || v === null ? '' : formatNumber(v));

  if (actionType === 'STOCK_IN' || actionType === 'STOCK_OUT') {
    const added = actionType === 'STOCK_IN' ? newData.stockIn : newData.stockOut;
    const label = actionType === 'STOCK_IN' ? 'Added' : 'Removed';
    if (added !== undefined) {
      changes.push({ field: 'movement', label, from: '—', to: num(added), delta: '' });
    }
    if (oldData && oldData.quantity !== undefined && newData.quantity !== undefined) {
      changes.push({
        field: 'quantity',
        label: 'Stock',
        from: num(oldData.quantity),
        to: num(newData.quantity),
        delta: deltaFor({ kind: NUMBER }, oldData.quantity, newData.quantity),
      });
    }
  } else if (actionType === 'STOCK_TRANSFER') {
    if (newData.transferred !== undefined) {
      changes.push({ field: 'movement', label: 'Transferred', from: '—', to: num(newData.transferred), delta: '' });
    }
    if (oldData && oldData.fromQuantity !== undefined && newData.fromQuantity !== undefined) {
      changes.push({
        field: 'fromQuantity',
        label: 'Source stock',
        from: num(oldData.fromQuantity),
        to: num(newData.fromQuantity),
        delta: deltaFor({ kind: NUMBER }, oldData.fromQuantity, newData.fromQuantity),
      });
    }
    if (oldData && oldData.toQuantity !== undefined && newData.toQuantity !== undefined) {
      changes.push({
        field: 'toQuantity',
        label: 'Target stock',
        from: num(oldData.toQuantity),
        to: num(newData.toQuantity),
        delta: deltaFor({ kind: NUMBER }, oldData.toQuantity, newData.toQuantity),
      });
    }
  }
  return changes;
};

// One line per sold line item - the admin wants to see what was actually sold.
const saleItemLines = (data) => {
  if (!data || !Array.isArray(data.items)) return [];
  return data.items.slice(0, 12).map((item) => {
    const name = item.productName || 'Item';
    const qty = Number(item.quantity) || 0;
    const price = Number(item.unitPrice) || 0;
    const total = Number(item.totalAmount) || qty * price;
    return `${qty} x ${name} @ ${formatMoney(price)} = ${formatMoney(total)}`;
  });
};

// A short, human name for the record the action was performed on.
const identityOf = (spec, data, recordType) => {
  if (!data) return '';
  const primary = spec.find((f) => !isEmpty(data[f.key]) && f.kind !== MONEY && f.kind !== NUMBER);
  let identity = primary ? refName(data[primary.key]) : '';
  if (!identity) {
    identity = refName(data.productName) || refName(data.description) || '';
  }
  if (!identity) return recordType || '';

  const sku = data.sku;
  if (sku && !String(identity).includes(String(sku))) identity += ` (${sku})`;
  return identity;
};

const recordLabel = (recordType) => {
  switch (recordType) {
    case 'Product':
      return 'Product';
    case 'Sale':
      return 'Sale';
    case 'Expense':
      return 'Expense';
    case 'Customer':
      return 'Customer';
    case 'Supplier':
      return 'Supplier';
    case 'Category':
      return 'Category';
    case 'Shop':
      return 'Shop';
    case 'User':
    case 'Manager':
      return 'Manager';
    case 'KhataEntry':
      return 'Khata entry';
    default:
      return recordType || 'Record';
  }
};

const verbFor = (actionType) => {
  if (actionType.startsWith('CREATE_')) return 'created';
  if (actionType.startsWith('UPDATE_')) return 'updated';
  if (actionType.startsWith('DELETE_')) return 'deleted';
  if (actionType.startsWith('RESTORE_')) return 'restored';
  if (actionType === 'STOCK_IN') return 'added stock to';
  if (actionType === 'STOCK_OUT') return 'removed stock from';
  if (actionType === 'STOCK_TRANSFER') return 'transferred stock of';
  return 'changed';
};

/**
 * Builds the detail payload for an audit record.
 *
 * @param {object} log  { actionType, recordType, oldData, newData, status }
 * @returns {{ identity: string, label: string, verb: string, facts: Array, changes: Array, itemLines: Array }}
 */
const describeChange = (log) => {
  const actionType = (log && log.actionType) || '';
  const recordType = (log && log.recordType) || '';
  const oldData = (log && log.oldData) || null;
  const newData = (log && log.newData) || null;

  const spec = FIELD_SPECS[recordType] || GENERIC_SPEC;
  const label = recordLabel(recordType);
  const verb = verbFor(actionType);

  const isUpdate = actionType.startsWith('UPDATE_');
  const isStock = actionType === 'STOCK_IN' || actionType === 'STOCK_OUT' || actionType === 'STOCK_TRANSFER';

  // The snapshot that describes the record after (or at the time of) the action.
  const snapshot = newData || oldData || {};
  const identity = identityOf(spec, snapshot, recordType);

  const facts = [];
  const changes = [];
  const itemLines = saleItemLines(newData || oldData);

  if (isStock) {
    // A stock movement is a change: show what went in / out and the new level.
    changes.push(...stockChanges(actionType, oldData, newData));
    for (const field of spec) {
      if (IGNORED_FIELDS.has(field.key)) continue;
      if (!['name', 'productName', 'sku'].includes(field.key)) continue;
      const value = snapshot[field.key];
      if (isEmpty(value)) continue;
      facts.push({ label: field.label, value: formatValue(field, value) });
    }
  } else if (isUpdate && oldData && newData) {
    // Only report the fields that actually differ.
    for (const field of spec) {
      if (IGNORED_FIELDS.has(field.key)) continue;
      const from = oldData[field.key];
      const to = newData[field.key];
      if (isEmpty(from) && isEmpty(to)) continue;
      if (!isDifferent(from, to)) continue;
      changes.push({
        field: field.key,
        label: field.label,
        from: formatValue(field, from) || '—',
        to: formatValue(field, to) || '—',
        delta: deltaFor(field, from, to),
      });
      if (changes.length >= MAX_CHANGES) break;
    }
  } else {
    // Created / deleted: report the key facts of the record.
    for (const field of spec) {
      if (IGNORED_FIELDS.has(field.key)) continue;
      const value = snapshot[field.key];
      if (isEmpty(value)) continue;
      const text = formatValue(field, value);
      if (!text) continue;
      facts.push({ label: field.label, value: text });
      if (facts.length >= MAX_FACTS) break;
    }
  }

  // The total value of the record - the number an admin cares about most.
  if (!isUpdate && snapshot.quantity !== undefined && snapshot.costPrice !== undefined) {
    const value = Number(snapshot.quantity) * Number(snapshot.costPrice);
    if (Number.isFinite(value) && value > 0 && !facts.some((f) => f.label === 'Stock value')) {
      facts.push({ label: 'Stock value', value: formatMoney(value) });
    }
  }
  if (isUpdate) {
    const qty = changes.find((c) => c.field === 'quantity');
    const cost = changes.find((c) => c.field === 'costPrice');
    if (qty && cost) {
      const before = Number(oldData.quantity) * Number(oldData.costPrice);
      const after = Number(newData.quantity) * Number(newData.costPrice);
      if (Number.isFinite(before) && Number.isFinite(after) && before !== after) {
        changes.push({
          field: 'stockValue',
          label: 'Stock value',
          from: formatMoney(before),
          to: formatMoney(after),
          delta: deltaFor({ kind: MONEY }, before, after),
        });
      }
    }
  }

  return { identity, label, verb, facts, changes, itemLines };
};

module.exports = {
  describeChange,
  recordLabel,
  verbFor,
  formatMoney,
  formatNumber,
  FIELD_SPECS,
};
