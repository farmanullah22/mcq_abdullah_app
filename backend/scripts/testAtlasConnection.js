// Quick connectivity + read/write probe for MongoDB Atlas.
// Usage: node scripts/testAtlasConnection.js
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');

// Uses MONGO_URI from the environment or backend/.env (never hardcode credentials).
const uri = process.env.MONGO_URI;
if (!uri) {
  console.error('RESULT: FAILED -> MONGO_URI is not set (backend/.env or environment)');
  process.exit(1);
}

const run = async () => {
  console.log('Connecting to Atlas...');
  const conn = await mongoose.connect(uri, { serverSelectionTimeoutMS: 20000 });
  console.log('OK connected ->', conn.connection.host, '| db:', conn.connection.name);

  const coll = conn.connection.db.collection('atlas_probe');
  const doc = {
    message: 'Atlas write probe',
    at: new Date(),
    node: process.version,
  };

  const ins = await coll.insertOne(doc);
  console.log('OK insertOne -> _id:', ins.insertedId.toString());

  const found = await coll.findOne({ _id: ins.insertedId });
  console.log('OK findOne  ->', JSON.stringify(found));

  const count = await coll.countDocuments();
  console.log('OK countDocuments ->', count);

  const del = await coll.deleteOne({ _id: ins.insertedId });
  console.log('OK deleteOne -> deletedCount:', del.deletedCount);

  await mongoose.disconnect();
  console.log('\nRESULT: Atlas read/write OK');
};

run().catch(async (err) => {
  console.error('RESULT: Atlas FAILED ->', err.message);
  try { await mongoose.disconnect(); } catch (_) {}
  process.exit(1);
});
