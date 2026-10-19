// Read-only inventory of the Atlas database: collections + document counts.
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');

// Uses MONGO_URI from the environment or backend/.env (never hardcode credentials).
const SRV_URI = process.env.MONGO_URI;
if (!SRV_URI) {
  console.error('FAILED -> MONGO_URI is not set (backend/.env or environment)');
  process.exit(1);
}

const run = async () => {
  const conn = await mongoose.connect(SRV_URI, { serverSelectionTimeoutMS: 20000 });
  console.log('srv:// connection OK ->', conn.connection.host, '| db:', conn.connection.name);

  const db = conn.connection.db;
  const collections = await db.listCollections().toArray();
  console.log(`Collections (${collections.length}):`);
  for (const c of collections.sort((a, b) => a.name.localeCompare(b.name))) {
    const n = await db.collection(c.name).countDocuments();
    console.log(`  ${c.name}: ${n}`);
  }

  const users = await db
    .collection('users')
    .find({}, { projection: { name: 1, email: 1, phone: 1, role: 1, isActive: 1 } })
    .toArray();
  console.log('\nUsers:');
  users.forEach((u) => console.log(`  ${u.role} | ${u.name} | ${u.email || u.phone} | active:${u.isActive !== false}`));

  await mongoose.disconnect();
};

run().catch(async (e) => {
  console.error('FAILED:', e.message);
  try { await mongoose.disconnect(); } catch (_) {}
  process.exit(1);
});
