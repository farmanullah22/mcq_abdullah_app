const Product = require('../models/Product');
const Category = require('../models/Category');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const { recordAudit } = require('../middleware/auth');
const { getWarehouseShop } = require('../utils/warehouse');
const { isVariantType, usesColorRows, isLegacyCarpet, normalizeVariants, variantTotal } = require('../utils/variants');

const buildProductQuery = (req) => {
  const filter = { isDeleted: false };
  if (req.user.role === 'manager') {
    filter.shop = req.user.assignedShop._id;
  } else if (req.shopId) {
    filter.shop = req.shopId;
  }

  const { search, category, brand, supplier, lowStock } = req.query;
  if (search) {
    filter.$or = [
      { name: { $regex: search, $options: 'i' } },
      { sku: { $regex: search, $options: 'i' } },
      { barcode: { $regex: search, $options: 'i' } },
    ];
  }
  if (category) filter.category = category;
  if (brand) filter.brand = { $regex: brand, $options: 'i' };
  if (supplier) filter.supplier = { $regex: supplier, $options: 'i' };
  if (lowStock === 'true') {
    filter.$expr = { $lte: ['$quantity', '$lowStockThreshold'] };
  }
  return filter;
};

const listProducts = asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page, 10) || 1;
  const limit = parseInt(req.query.limit, 10) || 50;
  const filter = buildProductQuery(req);

  const [products, total] = await Promise.all([
    Product.find(filter)
      .populate('category', 'name')
      .populate('shop', 'name')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit),
    Product.countDocuments(filter),
  ]);

  res.json(ApiResponse.ok('Products fetched', { products, total, page, limit, totalPages: Math.ceil(total / limit) }));
});

const getProduct = asyncHandler(async (req, res) => {
  const product = await Product.findById(req.params.id)
    .populate('category', 'name')
    .populate('shop', 'name');
  if (!product || product.isDeleted) throw new ApiError(404, 'Product not found.');
  if (req.user.role === 'manager' && product.shop._id.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage products of your assigned shop.');
  }
  res.json(ApiResponse.ok('Product fetched', product));
});

// Foam Cover, Pillow Cover and Carpet cannot exist without at least one colour
// row, otherwise they would silently have zero stock. Foam carries a plain
// quantity and legacy carpets keep their piece/sqft flow, so both are exempt.
const assertVariantGrid = (body) => {
  const pt = body.productType || 'qaleen';
  if (!usesColorRows(pt) || isLegacyCarpet(body)) return;
  if (normalizeVariants(body.variants).length === 0) {
    throw new ApiError(
      400,
      'Add at least one colour with a quantity greater than zero. Stock is tracked per colour.'
    );
  }
};

const calcQuantityAndCost = (body) => {
  const pt = body.productType || 'qaleen';
  const colorStockQty =
    Array.isArray(body.colorStocks) && body.colorStocks.length > 0
      ? body.colorStocks.reduce((sum, c) => sum + (Number(c.pieces) || 0), 0)
      : null;
  // Foam Cover / Pillow Cover / Carpet stock by colour rows; quantity is the sum
  // of those rows and the cost is a single per-piece figure. Foam only takes this
  // path when it still carries legacy variant rows, otherwise it falls through
  // to its plain-quantity branch below.
  if (isVariantType(pt)) {
    const variants = normalizeVariants(body.variants);
    if (variants.length > 0) {
      return { quantity: variantTotal(variants), costPrice: Number(body.costPrice) || 0 };
    }
  }
  if (pt === 'carpet') {
    const costPerSqft = Number(body.costPerSqft) || 0;
    const pieces = Array.isArray(body.carpetPiecesData) ? body.carpetPiecesData : [];
    let qty = 0;
    if (pieces.length > 0) {
      pieces.forEach((p) => {
        const pw = Number(p.width) || 0;
        const ph = Number(p.height) || 0;
        qty += pw * ph;
      });
    } else {
      const w = Number(body.carpetWidth) || 0;
      const h = Number(body.carpetHeight) || 0;
      qty = w * h;
    }
    // costPrice is per-unit (per sqft so that qty * costPrice equals stock value
    // and (unitPrice - costPrice) * qty yields correct sale profit).
    return { quantity: colorStockQty !== null ? colorStockQty : qty, costPrice: costPerSqft };
  }
  if (pt === 'qaleen') {
    if (colorStockQty !== null) {
      return { quantity: colorStockQty, costPrice: Number(body.costPerPiece) || 0 };
    }
    if (Array.isArray(body.qaleenSizes) && body.qaleenSizes.length > 0) {
      let totalPieces = 0;
      body.qaleenSizes.forEach((s) => { totalPieces += Number(s.pieces) || 0; });
      return { quantity: totalPieces, costPrice: Number(body.costPerPiece) || 0 };
    }
    return { quantity: Number(body.quantity) || 0, costPrice: Number(body.costPerPiece) || 0 };
  }
  if (pt === 'meter') {
    const length = colorStockQty !== null ? colorStockQty : Number(body.meterLength) || 0;
    // costPrice is per meter (per-unit) so the same qty * costPrice / profit math holds.
    return { quantity: length, costPrice: Number(body.costPerMeter) || 0 };
  }
  if (pt === 'foam') {
    const colorStockQtyF = (() => {
      if (!Array.isArray(body.colorStocks) || body.colorStocks.length === 0) return null;
      return body.colorStocks.reduce(
        (sum, c) => sum + Math.max(Number(c.quantity) || 0, Number(c.pieces) || 0),
        0
      );
    })();
    const sizes = Array.isArray(body.sizeStocks) ? body.sizeStocks : [];
    const qty = sizes.length > 0
      ? sizes.reduce((sum, s) => sum + (Number(s.pieces) || 0), 0)
      : (colorStockQtyF !== null ? colorStockQtyF : Number(body.quantity) || 0);
    return { quantity: qty, costPrice: Number(body.costPrice) || 0 };
  }
  if (pt === 'pillow') {
    const qty = colorStockQty !== null ? colorStockQty : Number(body.quantity) || 0;
    return { quantity: qty, costPrice: Number(body.costPrice) || 0 };
  }
  return { quantity: colorStockQty !== null ? colorStockQty : Number(body.quantity) || 0, costPrice: Number(body.costPrice) || 0 };
};

const createProduct = asyncHandler(async (req, res) => {
  const {
    name, sku, barcode, category, brand, supplier, sellingPrice,
    lowStockThreshold, description, color, size, images, colorStocks,
    productType,
    carpetWidth, carpetHeight, carpetPieces, carpetPiecesData, costPerSqft,
    costPerPiece, qaleenSizes,
    meterLength, costPerMeter,
    foamLength, foamWidth, foamThickness, foamType, pillowSize, sizeStocks, pillowStock, coverStock,
    variants,
  } = req.body;

  if (!name) throw new ApiError(400, 'Product name is required.');

  assertVariantGrid({ ...req.body, productType: productType || 'qaleen' });

  // Products are born at the warehouse: branch managers create catalog
  // entries centrally and stock enters here, then Stock Transfer pushes it to
  // branches. Admins may still pass an explicit shopId to repair data, but
  // the default target is the warehouse too.
  const Shop = require('../models/Shop');
  const warehouse = await getWarehouseShop(Shop);
  const shopId =
    req.user.role === 'manager'
      ? warehouse?._id
      : req.body.shopId || req.shopId || warehouse?._id;
  if (!shopId) throw new ApiError(503, 'No warehouse is configured. Add a shop with shopType=warehouse.');

  const existing = await Product.findOne({ shop: shopId, name, isDeleted: false });
  if (existing) {
    throw new ApiError(
      409,
      `A product named "${name}" already exists at the ${req.user.role === 'manager' || !req.body.shopId ? 'warehouse' : 'selected shop'}. Use Stock In to add quantity, or edit the existing product.`
    );
  }

  const { quantity, costPrice } = calcQuantityAndCost(req.body);

  const product = await Product.create({
    name,
    sku: sku || '',
    barcode: barcode || '',
    category: category || null,
    brand: brand || '',
    supplier: supplier || '',
    productType: productType || 'qaleen',
    carpetWidth: carpetWidth || 0,
    carpetHeight: carpetHeight || 0,
    carpetPieces: carpetPieces || 0,
    carpetPiecesData: carpetPiecesData || [],
    costPerSqft: costPerSqft || 0,
    costPerPiece: costPerPiece || 0,
    qaleenSizes: qaleenSizes || [],
    meterLength: meterLength || 0,
    costPerMeter: costPerMeter || 0,
    foamLength: foamLength || 0,
    foamWidth: foamWidth || 0,
    foamThickness: foamThickness || 0,
    foamType: foamType || '',
    pillowSize: pillowSize || '',
    sizeStocks: sizeStocks || [],
    pillowStock: pillowStock || 0,
    coverStock: coverStock || 0,
    costPrice,
    sellingPrice: sellingPrice || 0,
    quantity,
    lowStockThreshold: lowStockThreshold !== undefined ? lowStockThreshold : 5,
    color: color || '',
    size: size || '',
    description: description || '',
    images: images || [],
    colorStocks: colorStocks || [],
    variants: normalizeVariants(variants),
    shop: shopId,
  });

  await recordAudit(req, {
    actionType: 'CREATE_PRODUCT',
    module: 'products',
    recordId: product._id,
    recordType: 'Product',
    newData: product.toObject(),
    remarks: `Product "${product.name}" created at warehouse`,
    shopId,
  });

  res.status(201).json(ApiResponse.created('Product created', product));
});

const updateProduct = asyncHandler(async (req, res) => {
  const product = await Product.findById(req.params.id);
  if (!product || product.isDeleted) throw new ApiError(404, 'Product not found.');
  if (req.user.role === 'manager' && product.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage products of your assigned shop.');
  }
  const oldData = product.toObject();

  const allowed = [
    'name', 'sku', 'barcode', 'category', 'brand', 'supplier', 'sellingPrice',
    'lowStockThreshold', 'color', 'size', 'description', 'images', 'colorStocks',
    'productType',
    'carpetWidth', 'carpetHeight', 'carpetPieces', 'carpetPiecesData', 'costPerSqft',
    'costPerPiece', 'qaleenSizes',
    'meterLength', 'costPerMeter',
    'foamLength', 'foamWidth', 'foamThickness', 'foamType', 'pillowSize', 'sizeStocks',
    'pillowStock', 'coverStock',
    'costPrice', 'variants',
  ];
  allowed.forEach((field) => {
    if (req.body[field] !== undefined) product[field] = req.body[field];
  });

  if (Array.isArray(product.variants)) product.variants = normalizeVariants(product.variants);

  assertVariantGrid(product.toObject());

  // The cost price is recalculated from the body below, so an explicit cost
  // that was just copied in must not be treated as a derived value.
  const requestedCost = req.body.costPrice !== undefined ? Number(req.body.costPrice) || 0 : null;

  const { quantity, costPrice } = calcQuantityAndCost(product.toObject());
  product.quantity = quantity;
  product.costPrice = requestedCost !== null ? requestedCost : costPrice;

  await product.save();
  // Document#populate resolves to a promise, so the two paths are awaited
  // separately instead of being chained.
  await product.populate('category', 'name');
  await product.populate('shop', 'name');

  await recordAudit(req, {
    actionType: 'UPDATE_PRODUCT',
    module: 'products',
    recordId: product._id,
    recordType: 'Product',
    oldData,
    newData: product.toObject(),
    remarks: `Product "${product.name}" updated`,
    shopId: product.shop,
  });

  res.json(ApiResponse.ok('Product updated', product));
});

const deleteProduct = asyncHandler(async (req, res) => {
  const { deleteReason } = req.body;
  const product = await Product.findById(req.params.id).populate('category', 'name');
  if (!product) throw new ApiError(404, 'Product not found.');
  if (req.user.role === 'manager' && product.shop.toString() !== req.user.assignedShop._id.toString()) {
    throw new ApiError(403, 'You can only manage products of your assigned shop.');
  }

  const oldData = product.toObject();
  product.isDeleted = true;
  product.deletedBy = req.user._id;
  product.deletedAt = new Date();
  product.deleteReason = deleteReason || '';
  await product.save();

  await recordAudit(req, {
    actionType: 'DELETE_PRODUCT',
    module: 'products',
    recordId: product._id,
    recordType: 'Product',
    oldData,
    newData: null,
    status: 'deleted',
    remarks: `Product "${product.name}" soft-deleted${deleteReason ? ` - ${deleteReason}` : ''}`,
    shopId: product.shop,
  });

  res.json(ApiResponse.ok('Product deleted'));
});

const restoreProduct = asyncHandler(async (req, res) => {
  const product = await Product.findById(req.params.id);
  if (!product) throw new ApiError(404, 'Product not found.');

  product.isDeleted = false;
  product.deletedBy = null;
  product.deletedAt = null;
  product.deleteReason = '';
  await product.save();

  await recordAudit(req, {
    actionType: 'RESTORE_PRODUCT',
    module: 'products',
    recordId: product._id,
    recordType: 'Product',
    oldData: null,
    newData: product.toObject(),
    status: 'restored',
    remarks: `Product "${product.name}" restored`,
    shopId: product.shop,
  });

  res.json(ApiResponse.ok('Product restored', product));
});

const lowStockProducts = asyncHandler(async (req, res) => {
  const filter = { isDeleted: false, $expr: { $lte: ['$quantity', '$lowStockThreshold'] } };
  if (req.user.role === 'manager') filter.shop = req.user.assignedShop._id;
  else if (req.shopId) filter.shop = req.shopId;

  const products = await Product.find(filter).populate('category', 'name').populate('shop', 'name').sort({ quantity: 1 });
  res.json(ApiResponse.ok('Low stock products fetched', products));
});

module.exports = { listProducts, getProduct, createProduct, updateProduct, deleteProduct, restoreProduct, lowStockProducts };
