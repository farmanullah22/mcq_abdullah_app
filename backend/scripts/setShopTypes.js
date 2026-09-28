// One-off migration: mark the warehouse shop in production/live DBs.
//
// Usage: node scripts/setShopTypes.js
//
// Marks any shop whose name contains "warehouse" as shopType=warehouse and
// every other shop as shopType=branch. Run against the LIVE db (the app uses
// .env's MONGO_URI). Safe to run repeatedly.
require('dotenv').config();
const connectDB = require('../src/config/db');
const Shop = require('../src/models/Shop');

const run = async () => {
  await connectDB();

  const all = await Shop.find({ isDeleted: false });
  let updated = 0;

  for (const shop of all) {
    const type = /warehouse/i.test(String(shop.name || '')) ? 'warehouse' : 'branch';
    if (shop.shopType !== type) {
      shop.shopType = type;
      await shop.save();
      updated++;
      console.log(`-> ${shop.name}  =>  ${type}`);
    } else {
      console.log(`   ${shop.name}  =  ${type} (already set)`);
    }
  }

  const warehouses = all.filter((s) => /warehouse/i.test(String(s.name || '')));
  console.log(`\nDone. ${updated} shop(s) updated; ${warehouses.length} warehouse(s): ${warehouses.map((s) => s.name).join(', ') || 'NONE'}`);
  console.log('Warehouse shop =', warehouses.length === 1 ? warehouses[0]._id.toString() : 'Ambiguous - fix manually');
  process.exit(0);
};

run().catch((err) => {
  console.error('Migration failed:', err.message);
  process.exit(1);
});