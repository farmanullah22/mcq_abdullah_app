const Sale = require('../models/Sale');
const Product = require('../models/Product');
const Shop = require('../models/Shop');
const Notification = require('../models/Notification');
const InventoryLog = require('../models/InventoryLog');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { recordAudit } = require('../middleware/auth');
const { getWarehouseShop } = require('../utils/warehouse');

const generateInvoiceNo = async () => {
  const date = new Date();
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  for (let attempt = 0; attempt < 5; attempt++) {
    const rand = Math.floor(1000 + Math.random() * 9000);
    const invoiceNo = `INV-${y}${m}${d}-${rand}`;
    const exists = await Sale.findOne({ invoiceNo });
    if (!exists) return invoiceNo;
  }
  return `INV-${y}${m}${d}-${String(Date.now() % 100000).padStart(5, '0')}`;
};

const listSales = asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page, 10) || 1;
  const limit = parseInt(req.query.limit, 10) || 30;
  const filter = { isDeleted: false };
  if (req.user.role === 'manager') filter.shop = req.user.assignedShop._id;
  else if (req.shopId) filter.shop = req.shopId;
  if (req.query.from || req.query.to) {
    filter.createdAt = {};
    if (req.query.from) filter.createdAt.$gte = new Date(req.query.from);
    if (req.query.to) filter.createdAt.$lte = new Date(req.query.to);
  }
  if (req.query.paymentMethod) filter.paymentMethod = req.query.paymentMethod;

  const [sales, total] = await Promise.all([
    Sale.find(filter)
      .populate('shop', 'name')
      .populate('createdBy', 'name role')
      // Managers must not see profit margins or cost prices.
      .select(req.user.role === 'manager' ? '-profit -items.costPrice' : '')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit),
    Sale.countDocuments(filter),
  ]);

  res.json(ApiResponse.ok('Sales fetched', { sales, total, page, limit, totalPages: Math.ceil(total / limit) }));
});

const getSale = asyncHandler(async (req, res) => {
  const sale = await Sale.findById(req.params.id)
    .populate('shop', 'name address contactNumber')
    .populate('createdBy', 'name role')
    .select(req.user.role === 'manager' ? '-profit -items.costPrice' : '');
  if (!sale || sale.isDeleted) throw new ApiError(404, 'Sale not found.');
  res.json(ApiResponse.ok('Sale fetched', sale));
});

const createSale = asyncHandler(async (req, res) => {
  const { customerName, customerPhone, items, discount, paymentMethod, notes, paidAmount } = req.body;
  if (!items || !Array.isArray(items) || items.length === 0) {
    throw new ApiError(400, 'At least one product item is required.');
  }

  const shopId =
    req.user.role === 'manager'
      ? req.user.assignedShop._id
      : req.body.shopId || (await require('../models/Shop').findOne({ isDeleted: false }))._id;
  if (!shopId) throw new ApiError(400, 'shopId is required.');

  const warehouse = await getWarehouseShop(Shop);
  if (warehouse && String(shopId) === String(warehouse._id)) {
    throw new ApiError(403, 'The warehouse does not sell. Transfer stock to a branch and record the sale there.');
  }

  const saleItems = [];
  const inventoryLogs = [];
  let subtotal = 0;
  let profit = 0;

  const invoiceNo = await generateInvoiceNo();

  for (const item of items) {
    const product = await Product.findById(item.productId).populate('category', 'name');
    if (!product || product.isDeleted) throw new ApiError(404, `Product not found for item.`);
    if (product.shop.toString() !== shopId.toString()) {
      throw new ApiError(400, `"${product.name}" does not belong to this shop.`);
    }

    const productId = product._id;
    const productName = product.name;
    const unitPrice = item.unitPrice !== undefined ? Number(item.unitPrice) : product.sellingPrice;
    if (!unitPrice || unitPrice < 0) throw new ApiError(400, 'Unit price must be positive.');
    const beforeQty = product.quantity;

    if (product.productType === 'foam') {
      const foamQty = Math.floor(Number(item.foamQty) || 0);
      const pillowQty = Math.floor(Number(item.pillowQty) || 0);
      const coverQty = Math.floor(Number(item.coverQty) || 0);
      if (foamQty + pillowQty + coverQty <= 0) {
        throw new ApiError(400, `Enter a quantity for "${product.name}".`);
      }
      if (product.quantity < foamQty) {
        throw new ApiError(400, `Insufficient foam stock for "${product.name}" (only ${product.quantity} foam left).`);
      }
      if (product.pillowStock < pillowQty) {
        throw new ApiError(400, `Insufficient pillow stock for "${product.name}" (only ${product.pillowStock} pillows left).`);
      }
      if (product.coverStock < coverQty) {
        throw new ApiError(400, `Insufficient foam cover stock for "${product.name}" (only ${product.coverStock} covers left).`);
      }

      product.quantity -= foamQty;
      product.pillowStock -= pillowQty;
      product.coverStock -= coverQty;
      if (foamQty > 0 && Array.isArray(product.colorStocks) && product.colorStocks.length > 0) {
        let remaining = foamQty;
        for (const cs of product.colorStocks) {
          const avail = Math.max(Number(cs.quantity) || 0, Number(cs.pieces) || 0);
          const deduct = Math.min(avail, remaining);
          if (deduct > 0) {
            if (Number(cs.quantity)) cs.quantity -= deduct;
            else cs.pieces -= deduct;
            remaining -= deduct;
          }
          if (remaining <= 0) break;
        }
      }
      await product.save();

      const totalQty = foamQty + pillowQty + coverQty;
      const itemTotal = totalQty * unitPrice;
      saleItems.push({
        product: productId,
        productName,
        quantity: totalQty,
        unitPrice,
        totalAmount: itemTotal,
        costPrice: product.costPrice,
        foamQty,
        pillowQty,
        coverQty,
        carpetPiece: null,
        length: 0,
      });
      subtotal += itemTotal;
      profit += (unitPrice - product.costPrice) * totalQty;
      inventoryLogs.push({
        shop: shopId,
        product: productId,
        productName,
        actionType: 'stock_out',
        previousStock: beforeQty,
        newStock: product.quantity,
        quantity: totalQty,
        reason: `Sale ${invoiceNo}`,
        notes: `foam ${foamQty}, pillows ${pillowQty}, covers ${coverQty}`,
      });
      continue;
    }

    const qty = Number(item.quantity);
    if (!qty || qty <= 0) throw new ApiError(400, 'Quantity must be positive.');

    let removedCarpetPiece = null;
    let lengthSold = 0;

    if (product.productType === 'carpet') {
      const soldW = Number(item.width) || 0;
      const soldH = Number(item.height) || 0;
      const pieces = Array.isArray(product.carpetPiecesData) ? product.carpetPiecesData : [];
      if (pieces.length > 0) {
        if (soldW <= 0 || soldH <= 0) {
          throw new ApiError(400, `Select the carpet piece being sold for "${product.name}".`);
        }
        const tolerance = 0.05;
        const idx = pieces.findIndex(
          (p) => Math.abs(Number(p.width) - soldW) < tolerance && Math.abs(Number(p.height) - soldH) < tolerance
        );
        if (idx < 0) {
          throw new ApiError(
            400,
            `No ${product.name} piece matches ${soldW}m x ${soldH}m. Available: ${pieces
              .map((p) => `${p.width}m x ${p.height}m`)
              .join(', ') || 'none'}`
          );
        }
        removedCarpetPiece = pieces.splice(idx, 1)[0];
        product.carpetPieces = pieces.length;
        const area = Number(removedCarpetPiece.area) || soldW * soldH;
        if (product.quantity + 1e-9 < area) {
          throw new ApiError(400, `Insufficient carpet stock for "${product.name}" (only ${product.quantity} sqft left).`);
        }
        product.quantity = Number(product.quantity || 0) - area;
      } else if (product.quantity + 1e-9 < qty) {
        throw new ApiError(400, `Insufficient carpet stock for "${product.name}" (only ${product.quantity} sqft left).`);
      } else {
        product.quantity -= qty;
      }
    } else if (product.productType === 'meter') {
      if (product.meterLength + 1e-9 < qty) {
        throw new ApiError(400, `Insufficient length for "${product.name}" (only ${product.meterLength}m left).`);
      }
      product.meterLength = Number(product.meterLength || 0) - qty;
      product.quantity = Math.max(0, Number(product.quantity || 0) - qty);
      lengthSold = qty;
    } else if (product.productType === 'qaleen') {
      const sizes = Array.isArray(product.qaleenSizes) ? product.qaleenSizes : [];
      const availSizes = sizes.reduce((a, s) => a + (Number(s.pieces) || 0), 0);
      if (product.quantity + 1e-9 < qty) {
        throw new ApiError(400, `Insufficient stock for "${product.name}" (only ${product.quantity} pieces left).`);
      }
      if (sizes.length > 0 && availSizes + 1e-9 < qty) {
        throw new ApiError(400, `Only ${availSizes} pieces of "${product.name}" are tracked by size. Transfer more to this branch first.`);
      }
      let remaining = qty;
      for (const s of sizes) {
        const take = Math.min(Number(s.pieces) || 0, remaining);
        if (take > 0) {
          s.pieces = (Number(s.pieces) || 0) - take;
          remaining -= take;
        }
      }
      product.qaleenSizes = sizes.filter((s) => (Number(s.pieces) || 0) > 0);
      product.quantity = Math.max(0, Number(product.quantity || 0) - qty);
    } else {
      if (product.quantity + 1e-9 < qty) {
        throw new ApiError(400, `Insufficient stock for "${product.name}" (only ${product.quantity} left).`);
      }
      product.quantity -= qty;
    }

    await product.save();

    const itemTotal = qty * unitPrice;
    saleItems.push({
      product: productId,
      productName,
      quantity: qty,
      unitPrice,
      totalAmount: itemTotal,
      costPrice: product.costPrice,
      foamQty: 0,
      pillowQty: 0,
      coverQty: 0,
      carpetPiece: removedCarpetPiece
        ? {
            width: Number(removedCarpetPiece.width) || 0,
            height: Number(removedCarpetPiece.height) || 0,
            area: Number(removedCarpetPiece.area) || 0,
            color: removedCarpetPiece.color || '',
            image: removedCarpetPiece.image || '',
          }
        : null,
      length: lengthSold,
    });
    subtotal += itemTotal;
    profit += (unitPrice - product.costPrice) * qty;
    inventoryLogs.push({
      shop: shopId,
      product: productId,
      productName,
      actionType: 'stock_out',
      previousStock: beforeQty,
      newStock: product.quantity,
      quantity: qty,
      reason: `Sale ${invoiceNo}`,
      notes:
        product.productType === 'carpet' && removedCarpetPiece
          ? `Sold piece ${removedCarpetPiece.width}m x ${removedCarpetPiece.height}m`
          : '',
    });
  }

  const discountValue = Number(discount) || 0;
  if (discountValue > subtotal) throw new ApiError(400, 'Discount cannot exceed subtotal.');

  const totalAmount = subtotal - discountValue;
  const paidValue = Math.min(Math.max(Number(paidAmount) || 0, 0), totalAmount);
  const dueValue = totalAmount - paidValue;

  const sale = await Sale.create({
    invoiceNo,
    shop: shopId,
    customerName: customerName || 'Walk-in Customer',
    customerPhone: customerPhone || '',
    items: saleItems,
    subtotal,
    discount: discountValue,
    totalAmount,
    paidAmount: paidValue,
    dueAmount: dueValue,
    profit,
    paymentMethod: paymentMethod || 'cash',
    notes: notes || '',
    createdBy: req.user._id,
  });

  if (inventoryLogs.length > 0) await InventoryLog.insertMany(inventoryLogs);

  await recordAudit(req, {
    actionType: 'CREATE_SALE',
    module: 'sales',
    recordId: sale._id,
    recordType: 'Sale',
    newData: sale.toObject(),
    remarks: `Sale ${invoiceNo} created - Rs. ${sale.totalAmount}`,
    shopId,
  });

  // Notify admins about the new sale
  const User = require('../models/User');
  const admins = await User.find({ role: 'admin', isActive: true });
  await Notification.insertMany(
    admins.map((admin) => ({
      user: admin._id,
      title: 'New Sale',
      body: `New sale ${invoiceNo} of Rs. ${sale.totalAmount}`,
      type: 'new_sale',
      data: { saleId: sale._id, invoiceNo },
    }))
  );

  // Send the PDF receipt to the customer's WhatsApp number (if one is given
  // and WhatsApp is configured). Failures never affect the sale itself.
  const whatsappService = require('../services/whatsappService');
  sale.whatsappReceipt = await whatsappService.sendWhatsAppReceipt(sale, sale.customerPhone);

  // Link the sale to a registered customer (matched by phone) and update
  // their purchase history. Credit sales also increase the outstanding due.
  const phone = (sale.customerPhone || '').trim();
  if (phone) {
    const Customer = require('../models/Customer');
    const customer = await Customer.findOne({
      isDeleted: false,
      shop: shopId,
      phone: { $regex: `^${phone.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, $options: 'i' },
    });
    if (customer) {
      customer.totalSpent += sale.totalAmount;
      customer.purchaseCount += 1;
      customer.lastPurchaseAt = new Date();
      if (sale.dueAmount > 0) {
        customer.balance += sale.dueAmount;
        customer.transactions.push({
          amount: sale.dueAmount,
          type: 'charge',
          note: `Sale ${invoiceNo} (paid ${paidValue}, due ${dueValue})`,
          date: new Date(),
          by: req.user._id,
        });
      }
      if (sale.paidAmount > 0) {
        customer.transactions.push({
          amount: sale.paidAmount,
          type: 'payment',
          note: `Payment received on sale ${invoiceNo}`,
          date: new Date(),
          by: req.user._id,
        });
      }
      await customer.save();
    }
  }

  res.status(201).json(ApiResponse.created('Sale created successfully', sale));
});

const updateSale = asyncHandler(async (req, res) => {
  const sale = await Sale.findById(req.params.id);
  if (!sale || sale.isDeleted) throw new ApiError(404, 'Sale not found.');
  if (req.user.role === 'manager' && sale.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage sales of your assigned shop.');
  }
  const oldData = sale.toObject();

  const allowed = ['customerName', 'customerPhone', 'discount', 'paymentMethod', 'notes'];
  allowed.forEach((field) => {
    if (req.body[field] !== undefined) sale[field] = req.body[field];
  });
  if (sale.discount > sale.subtotal) throw new ApiError(400, 'Discount cannot exceed subtotal.');
  sale.totalAmount = sale.subtotal - sale.discount;
  await sale.save();

  await recordAudit(req, {
    actionType: 'UPDATE_SALE',
    module: 'sales',
    recordId: sale._id,
    recordType: 'Sale',
    oldData,
    newData: sale.toObject(),
    remarks: `Sale ${sale.invoiceNo} updated`,
    shopId: sale.shop,
  });

  res.json(ApiResponse.ok('Sale updated', sale));
});

const deleteSale = asyncHandler(async (req, res) => {
  const { deleteReason, restock = false } = req.body;
  const sale = await Sale.findById(req.params.id);
  if (!sale) throw new ApiError(404, 'Sale not found.');
  if (req.user.role === 'manager' && sale.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage sales of your assigned shop.');
  }
  const oldData = sale.toObject();

  if (restock) {
    const restockLogs = [];
    for (const item of sale.items) {
      const product = await Product.findById(item.product);
      if (!product) continue;
      const beforeQty = product.quantity;

      if (item.foamQty || item.pillowQty || item.coverQty) {
        product.quantity += item.foamQty || 0;
        product.pillowStock += item.pillowQty || 0;
        product.coverStock += item.coverQty || 0;
      } else if (item.carpetPiece) {
        if (Array.isArray(product.carpetPiecesData)) {
          product.carpetPiecesData.push(item.carpetPiece);
          product.carpetPieces = product.carpetPiecesData.length;
        }
        product.quantity += item.quantity;
      } else if (item.length) {
        product.meterLength = (Number(product.meterLength) || 0) + item.length;
        product.quantity += item.length;
      } else {
        product.quantity += item.quantity;
      }
      await product.save();
      restockLogs.push({
        shop: sale.shop,
        product: item.product,
        productName: item.productName,
        actionType: 'stock_in',
        previousStock: beforeQty,
        newStock: product.quantity,
        quantity: item.quantity,
        reason: `Sale ${sale.invoiceNo} reversed`,
        notes: item.carpetPiece ? 'Returned carpet piece to stock' : '',
      });
    }
    if (restockLogs.length > 0) await InventoryLog.insertMany(restockLogs);
  }

  sale.isDeleted = true;
  sale.deletedBy = req.user._id;
  sale.deletedAt = new Date();
  sale.deleteReason = deleteReason || '';
  await sale.save();

  await recordAudit(req, {
    actionType: 'DELETE_SALE',
    module: 'sales',
    recordId: sale._id,
    recordType: 'Sale',
    oldData,
    newData: null,
    status: 'deleted',
    remarks: `Sale ${sale.invoiceNo} soft-deleted${restock ? ' (restocked)' : ''}`,
    shopId: sale.shop,
  });

  res.json(ApiResponse.ok('Sale deleted'));
});

const restoreSale = asyncHandler(async (req, res) => {
  const sale = await Sale.findById(req.params.id);
  if (!sale) throw new ApiError(404, 'Sale not found.');

  sale.isDeleted = false;
  sale.deletedBy = null;
  sale.deletedAt = null;
  sale.deleteReason = '';
  await sale.save();

  await recordAudit(req, {
    actionType: 'RESTORE_SALE',
    module: 'sales',
    recordId: sale._id,
    recordType: 'Sale',
    oldData: null,
    newData: sale.toObject(),
    status: 'restored',
    remarks: `Sale ${sale.invoiceNo} restored`,
    shopId: sale.shop,
  });

  res.json(ApiResponse.ok('Sale restored', sale));
});

module.exports = { listSales, getSale, createSale, updateSale, deleteSale, restoreSale };
