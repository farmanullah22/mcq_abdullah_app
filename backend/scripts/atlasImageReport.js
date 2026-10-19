// Reports how pictures are stored in MongoDB Atlas (base64 strings inside docs).
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');

const uri = process.env.MONGO_URI;
if (!uri) {
  console.error('MONGO_URI is not set');
  process.exit(1);
}

const kb = (n) => `${(n / 1024).toFixed(1)} KB`;

const run = async () => {
  const conn = await mongoose.connect(uri, { serverSelectionTimeoutMS: 20000 });
  const db = conn.connection.db;

  console.log(`Connected: ${conn.connection.host} / ${db.databaseName}\n`);

  // --- Products ---------------------------------------------------------
  const productStats = await db
    .collection('products')
    .aggregate([
      { $match: { isDeleted: false } },
      {
        $project: {
          name: 1,
          imageCount: { $size: { $ifNull: ['$images', []] } },
          imageBytes: {
            $sum: {
              $map: {
                input: { $ifNull: ['$images', []] },
                as: 'i',
                in: { $strLenBytes: '$$i' },
              },
            },
          },
        },
      },
      { $group: { _id: null, docs: { $sum: 1 }, withImages: { $sum: { $cond: [{ $gt: ['$imageCount', 0] }, 1, 0] } }, bytes: { $sum: '$imageBytes' } } },
    ])
    .toArray();
  const ps = productStats[0] || { docs: 0, withImages: 0, bytes: 0 };
  console.log(`PRODUCTS: ${ps.docs} active, ${ps.withImages} have a picture, total image payload ${kb(ps.bytes)}`);

  const biggestProduct = await db
    .collection('products')
    .aggregate([
      { $unwind: { path: '$images', preserveNullAndEmptyArrays: true } },
      { $project: { name: 1, len: { $strLenBytes: { $ifNull: ['$images', ''] } } } },
      { $sort: { len: -1 } },
      { $limit: 3 },
    ])
    .toArray();
  biggestProduct.forEach((p) => console.log(`  largest: "${p.name}" -> ${kb(p.len)}`));

  // --- Sales ------------------------------------------------------------
  const saleStats = await db
    .collection('sales')
    .aggregate([
      { $unwind: '$items' },
      {
        $group: {
          _id: null,
          items: { $sum: 1 },
          withImage: { $sum: { $cond: [{ $gt: [{ $strLenBytes: { $ifNull: ['$items.image', ''] } }, 0] }, 1, 0] } },
          bytes: { $sum: { $strLenBytes: { $ifNull: ['$items.image', ''] } } },
        },
      },
    ])
    .toArray();
  const ss = saleStats[0] || { items: 0, withImage: 0, bytes: 0 };
  console.log(`\nSALES: ${ss.items} line items, ${ss.withImage} carry a captured picture, total ${kb(ss.bytes)}`);

  const biggestSale = await db
    .collection('sales')
    .aggregate([
      { $unwind: '$items' },
      {
        $project: {
          invoiceNo: 1,
          name: '$items.productName',
          len: { $strLenBytes: { $ifNull: ['$items.image', ''] } },
        },
      },
      { $sort: { len: -1 } },
      { $limit: 3 },
    ])
    .toArray();
  biggestSale.forEach((s) => console.log(`  largest: ${s.invoiceNo} "${s.name}" -> ${kb(s.len)}`));

  // --- Collection physical size ----------------------------------------
  console.log('\nCOLLECTION SIZES:');
  for (const c of ['products', 'sales']) {
    const st = await db.command({ collStats: c });
    console.log(`  ${c}: data ${(st.size / 1024 / 1024).toFixed(2)} MB, avg obj ${kb(st.avgObjSize || 0)}, max ${st.maxSize ? kb(st.maxSize) : 'no cap'}`);
  }

  // BSON document size of the biggest sale (16 MB hard limit per document).
  const biggestDoc = await db.collection('sales').aggregate([{ $project: { bytes: { $bsonSize: '$$ROOT' }, invoiceNo: 1 } }, { $sort: { bytes: -1 } }, { $limit: 1 }]).toArray();
  if (biggestDoc[0]) {
    const pct = ((biggestDoc[0].bytes / (16 * 1024 * 1024)) * 100).toFixed(2);
    console.log(`\nLargest sale document ${biggestDoc[0].invoiceNo}: ${kb(biggestDoc[0].bytes)} (${pct}% of the 16 MB BSON limit)`);
  }

  await mongoose.disconnect();
};

run().catch(async (e) => {
  console.error('FAILED:', e.message);
  try { await mongoose.disconnect(); } catch (_) {}
  process.exit(1);
});
