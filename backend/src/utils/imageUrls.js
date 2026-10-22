// Product photos are stored as base64 data URLs inside the product document.
// Embedding them in every list response turned a product list into a
// multi-megabyte payload (a single foam product carried ~2.3 MB of base64),
// which made the stock screens crawl on slow connections. Lists now point at
// the bytes and /products/:id/image/:index serves them on demand.
const imageUrl = (productId, index) => `/api/products/${productId}/image/${index}`;

// Rewrites the base64 gallery of one or many product documents into URL
// references. The documents are only serialised afterwards, so the heavy
// payload never leaves the server.
const withImageUrls = (docs) => {
  const list = Array.isArray(docs) ? docs : [docs];
  for (const doc of list) {
    if (!doc) continue;
    const images = doc.images;
    if (!Array.isArray(images) || images.length === 0) continue;
    const id = (doc._id || doc.id || '').toString();
    doc.images = images.map((_, i) => imageUrl(id, i));
  }
  return docs;
};

module.exports = { imageUrl, withImageUrls };
