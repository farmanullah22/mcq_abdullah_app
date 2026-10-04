const ApiError = require('./ApiError');

// The four re-designed products all stock by quantity across a colour x size
// grid and are priced by cost-per-piece. Older types (qaleen, meter, legacy
// carpet with tracked pieces, legacy foam with pillow/cover stocks) keep their
// dedicated flows untouched.
const VARIANT_TYPES = new Set(['foam', 'foam_cover', 'pillow_cover', 'carpet']);

const isVariantType = (productType) => VARIANT_TYPES.has(productType);

// Foam is catalogued as a foam type plus one plain quantity, so it never has a
// colour grid. Foam Cover, Pillow Cover and Carpet stock by colour rows.
const PLAIN_QUANTITY_TYPES = new Set(['foam']);

const usesColorRows = (productType) =>
  isVariantType(productType) && !PLAIN_QUANTITY_TYPES.has(productType);

const hasVariants = (product) =>
  product && isVariantType(product.productType) && Array.isArray(product.variants) && product.variants.length > 0;

// Carpets that carry real piece data or a roll width predate the re-design and
// keep their sqft-based flow. The re-designed carpet is a colour x size x
// quantity product like foam, so it needs a variant grid.
const isLegacyCarpet = (product) => {
  if (!product) return false;
  return (
    (Array.isArray(product.carpetPiecesData) && product.carpetPiecesData.length > 0) ||
    Number(product.carpetWidth) > 0
  );
};

const variantKey = (v) => `${v.color || ''}\u0001${v.size || ''}`;

// Clean incoming rows: drop blank colour+size pairs, drop zero/negative
// quantities and merge rows that repeat the same colour + size so a stored
// product never carries two rows for one combination.
const normalizeVariants = (arr) => {
  if (!Array.isArray(arr)) return [];
  const map = new Map();
  for (const v of arr) {
    if (!v) continue;
    const color = String(v.color || '').trim();
    const size = String(v.size || '').trim();
    const quantity = Math.floor(Number(v.quantity));
    if (color === '' && size === '') continue;
    if (!(quantity > 0)) continue;
    const key = variantKey({ color, size });
    const cur = map.get(key);
    if (cur) cur.quantity += quantity;
    else map.set(key, { color, size, quantity });
  }
  return Array.from(map.values());
};

const variantTotal = (arr) =>
  (Array.isArray(arr) ? arr : []).reduce((sum, v) => sum + Math.max(0, Math.floor(Number(v.quantity) || 0)), 0);

const _copy = (existing) =>
  (Array.isArray(existing) ? existing : []).map((v) => ({
    color: v.color || '',
    size: v.size || '',
    quantity: Math.floor(Number(v.quantity) || 0),
  }));

const _label = (v) => {
  if (v.color && v.size) return `${v.color} - ${v.size}`;
  return v.color || v.size || 'item';
};

// Add incoming quantities to existing variants (stock in / transfer in). Same
// colour + size merge into one row; zero-quantity rows are dropped.
const mergeVariants = (existing, incoming) => {
  const map = new Map();
  for (const v of _copy(existing)) map.set(variantKey(v), v);
  for (const v of normalizeVariants(incoming)) {
    const key = variantKey(v);
    const cur = map.get(key);
    if (cur) cur.quantity += v.quantity;
    else map.set(key, { color: v.color, size: v.size, quantity: v.quantity });
  }
  return Array.from(map.values()).filter((v) => v.quantity > 0);
};

// Remove exact (colour x size) quantities. Throws when a requested variant has
// less stock than requested. Returns the surviving variants plus what moved.
const subtractVariants = (existing, requested) => {
  const working = _copy(existing);
  const moved = [];
  for (const r of normalizeVariants(requested)) {
    const idx = working.findIndex((v) => variantKey(v) === variantKey(r));
    if (idx < 0) throw new ApiError(400, `Variant "${_label(r)}" not found in stock.`);
    if (working[idx].quantity < r.quantity) {
      throw new ApiError(400, `Insufficient stock for "${_label(r)}". Only ${working[idx].quantity} available.`);
    }
    working[idx].quantity -= r.quantity;
    moved.push({ color: r.color, size: r.size, quantity: r.quantity });
  }
  return { variants: working.filter((v) => v.quantity > 0), moved };
};

// Reduce total stock across variants (sales, plain-quantity stock out /
// transfer). Drains the biggest variants first so the least crowded ones stay
// available longer. Throws when total stock is insufficient. Returns the
// surviving rows plus the exact rows that were taken, so a reversed sale can
// return the pieces to the same colour and size.
const drainVariants = (existing, qty) => {
  const working = _copy(existing);
  if (!(qty > 0)) return { variants: working, moved: [] };
  const total = working.reduce((s, v) => s + v.quantity, 0);
  if (total < qty) throw new ApiError(400, `Insufficient stock. Only ${total} pieces available.`);
  const ordered = working.slice().sort((a, b) => b.quantity - a.quantity);
  const moved = [];
  let remaining = qty;
  for (const v of ordered) {
    if (remaining <= 0) break;
    const take = Math.min(v.quantity, remaining);
    v.quantity -= take;
    remaining -= take;
    moved.push({ color: v.color, size: v.size, quantity: take });
  }
  return { variants: working.filter((v) => v.quantity > 0), moved };
};

// Enforce the invariant product.quantity === sum(variants) after any mutation.
const syncQuantity = (product) => {
  if (product && Array.isArray(product.variants)) {
    product.quantity = variantTotal(product.variants);
  }
  return product;
};

module.exports = {
  VARIANT_TYPES,
  PLAIN_QUANTITY_TYPES,
  isVariantType,
  usesColorRows,
  hasVariants,
  isLegacyCarpet,
  normalizeVariants,
  variantTotal,
  variantKey,
  mergeVariants,
  subtractVariants,
  drainVariants,
  syncQuantity,
};