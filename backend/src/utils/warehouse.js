const Product = require('../models/Product');

// Resolve the single warehouse shop. Prefers the explicit shopType flag but
// falls back to a name match so datasets seeded before the flag existed still
// behave correctly.
const getWarehouseShop = async (Shop = require('../models/Shop')) => {
  const byFlag = await Shop.findOne({ shopType: 'warehouse', isDeleted: false }).sort({ createdAt: 1 });
  if (byFlag) return byFlag;
  const byName = await Shop.findOne({ name: /warehouse/i, isDeleted: false }).sort({ createdAt: 1 });
  if (byName) {
    byName.shopType = 'warehouse';
    await byName.save().catch(() => {});
  }
  return byName;
};

const shopTypeOf = (shop) => {
  if (!shop) return 'branch';
  if (shop.shopType) return shop.shopType;
  return /warehouse/i.test(String(shop.name || '')) ? 'warehouse' : 'branch';
};

const isWarehouse = (shop) => shopTypeOf(shop) === 'warehouse';

// The warehouse's copy of a product. If the given product already lives at the
// warehouse it is returned as-is; otherwise the warehouse copy is looked up by
// name (as transfers do) and created if it does not exist yet.
const ensureWarehouseCopy = async (source, warehouse) => {
  if (String(source.shop) === String(warehouse._id)) return source;

  const existing = await Product.findOne({
    shop: warehouse._id,
    name: source.name,
    isDeleted: false,
  });
  if (existing) return existing;

  return Product.create({
    name: source.name,
    sku: source.sku || '',
    barcode: source.barcode || '',
    category: source.category || null,
    brand: source.brand || '',
    supplier: source.supplier || '',
    productType: source.productType || 'qaleen',
    carpetWidth: 0,
    carpetHeight: 0,
    carpetPieces: 0,
    costPerSqft: source.costPerSqft || 0,
    costPerPiece: source.costPerPiece || 0,
    qaleenSizes: [],
    meterLength: 0,
    costPerMeter: source.costPerMeter || 0,
    foamLength: source.foamLength || 0,
    foamWidth: source.foamWidth || 0,
    foamThickness: source.foamThickness || 0,
    pillowSize: source.pillowSize || '',
    sizeStocks: [],
    pillowStock: 0,
    coverStock: 0,
    costPrice: source.costPrice || 0,
    sellingPrice: source.sellingPrice || 0,
    quantity: 0,
    lowStockThreshold: source.lowStockThreshold || 5,
    color: source.color || '',
    size: source.size || '',
    description: source.description || '',
    images: source.images || [],
    colorStocks: [],
    shop: warehouse._id,
  });
};

module.exports = { getWarehouseShop, ensureWarehouseCopy, isWarehouse, shopTypeOf };