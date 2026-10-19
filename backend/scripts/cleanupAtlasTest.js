// Remove the artifacts left behind by scripts/test-api.js runs against Atlas.
// 1. "Test Product <timestamp>" docs created during the test window.
// 2. Audit-log entries written during the test window (login/logout traces).
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');

// Uses MONGO_URI from the environment or backend/.env (never hardcode credentials).
const SRV_URI = process.env.MONGO_URI;
if (!SRV_URI) {
  console.error('FAILED -> MONGO_URI is not set (backend/.env or environment)');
  process.exit(1);
}

const WINDOW_START = new Date(process.argv[2] || '2026-10-19T16:10:00Z');
const WINDOW_END = new Date(process.argv[3] || '2026-10-19T16:13:00Z');

const run = async () => {
  const conn = await mongoose.connect(SRV_URI, { serverSelectionTimeoutMS: 20000 });
  const db = conn.connection.db;

  console.log(`Window: ${WINDOW_START.toISOString()} .. ${WINDOW_END.toISOString()}`);

  const products = await db
    .collection('products')
    .find({ createdAt: { $gte: WINDOW_START, $lte: WINDOW_END } })
    .toArray();
  console.log(`\nProducts created in window (${products.length}):`);
  products.forEach((p) => console.log(`  ${p._id} | ${p.name} | ${p.createdAt && p.createdAt.toISOString()}`));
  const prodIds = products.map((p) => p._id);

  const audits = await db
    .collection('auditlogs')
    .find({ createdAt: { $gte: WINDOW_START, $lte: WINDOW_END } })
    .toArray();
  console.log(`\nAudit logs created in window (${audits.length}):`);
  audits.forEach((a) =>
    console.log(`  ${a.createdAt && a.createdAt.toISOString()} | ${a.actionType} | ${a.module} | ${a.remarks}`)
  );
  const auditIds = audits.map((a) => a._id);

  if (process.argv.includes('--apply')) {
    if (prodIds.length) {
      const r = await db.collection('products').deleteMany({ _id: { $in: prodIds } });
      console.log(`\nDeleted products: ${r.deletedCount}`);
    }
    if (auditIds.length) {
      const r = await db.collection('auditlogs').deleteMany({ _id: { $in: auditIds } });
      console.log(`Deleted audit logs: ${r.deletedCount}`);
    }
  } else {
    console.log('\n(dry run — pass --apply to delete)');
  }

  console.log('\nCurrent counts:');
  for (const c of (await db.listCollections().toArray()).sort((a, b) => a.name.localeCompare(b.name))) {
    console.log(`  ${c.name}: ${await db.collection(c.name).countDocuments()}`);
  }

  await mongoose.disconnect();
};

run().catch(async (e) => {
  console.error('FAILED:', e.message);
  try { await mongoose.disconnect(); } catch (_) {}
  process.exit(1);
});
