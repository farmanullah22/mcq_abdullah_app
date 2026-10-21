/**
 * End to end check for the manager -> admin notification with full details.
 *
 * A manager adds, edits and deletes a record inside their own branch /
 * warehouse. The admin must receive a notification that says exactly what
 * happened: which item, which fields, old value -> new value.
 *
 * Usage:  node scripts/testManagerNotifications.js
 * The script cleans up after itself (test product + test notifications).
 */

const BASE = process.env.API_BASE_URL || 'http://localhost:5000/api';

const MANAGER = { identifier: 'ali@muallimcarpets.com', password: 'Manager@123' };
const ADMIN = { identifier: 'admin@muallimcarpets.com', password: 'Admin@123' };

const post = async (path, body, token) => {
  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`${path} -> ${res.status} ${JSON.stringify(json)}`);
  return json.data;
};

const patch = async (path, body, token) => {
  const res = await fetch(`${BASE}${path}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`${path} -> ${res.status} ${JSON.stringify(json)}`);
  return json.data;
};

const del = async (path, body, token) => {
  const res = await fetch(`${BASE}${path}`, {
    method: 'DELETE',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify(body || {}),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`${path} -> ${res.status} ${JSON.stringify(json)}`);
  return json.data;
};

const get = async (path, token) => {
  const res = await fetch(`${BASE}${path}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`${path} -> ${res.status} ${JSON.stringify(json)}`);
  return json.data;
};

const stamp = Date.now();
const productName = `ZZ Notification Probe ${stamp}`;

const printNotification = (n) => {
  console.log('--------------------------------------------------');
  console.log(`title : ${n.title}`);
  console.log(`body  : ${n.body}`);
  console.log(`type  : ${n.type}`);
  const d = n.data || {};
  console.log(`shop  : ${d.shopName || '-'}   by ${d.performedByName || '-'}`);
  console.log(`action: ${d.actionType || '-'}  (${d.recordType || '-'})`);
  if (d.facts && d.facts.length) {
    console.log('facts :');
    d.facts.forEach((f) => console.log(`         ${f.label}: ${f.value}`));
  }
  if (d.changes && d.changes.length) {
    console.log('changes:');
    d.changes.forEach((c) =>
      console.log(`         ${c.label}: ${c.from} -> ${c.to}${c.delta ? `  (${c.delta})` : ''}`)
    );
  }
  if (d.itemLines && d.itemLines.length) {
    console.log('items :');
    d.itemLines.forEach((l) => console.log(`         ${l}`));
  }
};

(async () => {
  // Remove leftovers from an earlier aborted run.
  const mongoose = require('mongoose');
  const connectDB = require('../src/config/db');
  await connectDB();
  const Notification = require('../src/models/Notification');
  const Product = require('../src/models/Product');
  const Customer = require('../src/models/Customer');
  await Product.deleteMany({ name: { $regex: '^ZZ Notification Probe' } });
  await Customer.deleteMany({ name: { $regex: '^ZZ Probe Customer' } });
  await Notification.deleteMany({ 'data.identity': { $regex: '^ZZ' } });
  const AuditLog = require('../src/models/AuditLog');
  await AuditLog.deleteMany({ remarks: { $regex: 'ZZ (Notification Probe|Probe Customer)' } });
  await mongoose.disconnect();

  const manager = await post('/auth/login', MANAGER);
  const admin = await post('/auth/login', ADMIN);
  const mToken = manager.token;
  const aToken = admin.token;
  console.log(`manager: ${manager.user.name} @ ${manager.user.assignedShop?.name || '-'}`);
  console.log(`admin  : ${admin.user.name}`);

  const before = await get('/notifications?limit=50', aToken);

  const branchId = manager.user.assignedShop?.id || manager.user.assignedShop?._id;
  if (!branchId) throw new Error('manager has no assigned shop');

  // 0. The admin seeds a throw away product inside the manager's branch so
  //    the manager can act on it (a manager can only manage their own branch).
  const created = await post(
    '/products',
    {
      name: productName,
      sku: `ZZ-PROBE-${stamp}`,
      productType: 'foam',
      colorStocks: [{ color: 'Red', quantity: 40 }],
      costPrice: 500,
      sellingPrice: 900,
      lowStockThreshold: 5,
      shopId: branchId,
    },
    aToken
  );
  console.log(`\nseeded probe product ${created.name} in the manager's branch (${created._id})`);

  // 1. UPDATE - price and stock
  await patch(
    `/products/${created._id}`,
    { sellingPrice: 1150, colorStocks: [{ color: 'Red', quantity: 25 }] },
    mToken
  );
  console.log('manager updated product (selling price 900 -> 1150, stock 40 -> 25)');

  // 2. CREATE - a customer in the manager's own branch
  const customer = await post(
    '/customers',
    { name: `ZZ Probe Customer ${stamp}`, phone: '+92 300 0000000', balance: 1500 },
    mToken
  );
  console.log(`manager added customer ${customer.name}`);

  // 3. DELETE - the customer and the product
  await del(`/customers/${customer._id}`, {}, mToken);
  console.log('manager deleted customer');

  // 4. STOCK IN - the manager adds stock to a branch product
  await post('/inventory/in', { productId: created._id, quantity: 10, notes: 'probe restock' }, mToken);
  console.log('manager added stock to the product');

  await del(`/products/${created._id}`, { deleteReason: 'probe cleanup' }, mToken);
  console.log('manager deleted product');

  await new Promise((r) => setTimeout(r, 800));

  const after = await get('/notifications?limit=50', aToken);
  // The API returns `_id` only (no `id` virtual), so compare on that.
  const idOf = (n) => String(n.id ?? n._id);
  const beforeIds = new Set(before.notifications.map(idOf));
  const created2 = after.notifications.filter((n) => !beforeIds.has(idOf(n)));
  const managerActions = created2.filter((n) => n.type === 'manager_action');

  console.log(`\nnew notifications for the admin: ${created2.length} (manager actions: ${managerActions.length})`);
  managerActions.forEach(printNotification);

  // The same breakdown must be available in the audit log and in the admin
  // dashboard "recent activity" feed.
  const audit = await get('/audit?limit=10', aToken);
  const auditLogs = audit.logs || audit.data || [];
  const withDetails = auditLogs.filter((l) => (l.changes || []).length || (l.facts || []).length);
  console.log(`\naudit logs with details: ${withDetails.length}/${auditLogs.length}`);
  withDetails.slice(0, 3).forEach((l) => {
    console.log(`  ${l.actionType} - ${l.performedByName} @ ${l.shopName}`);
    (l.changes || []).forEach((c) => console.log(`      ${c.label}: ${c.from} -> ${c.to}`));
    (l.facts || []).forEach((f) => console.log(`      ${f.label}: ${f.value}`));
  });

  const dash = await get('/dashboard', aToken);
  const activity = dash.recentActivity || [];
  const dashWithDetails = activity.filter((a) => (a.changes || []).length || (a.facts || []).length);
  console.log(`\nadmin dashboard recent activity with details: ${dashWithDetails.length}/${activity.length}`);

  const ok =
    managerActions.length >= 5 &&
    managerActions.some((n) => (n.data.changes || []).some((c) => c.label === 'Selling price')) &&
    managerActions.some((n) => (n.data.changes || []).some((c) => c.label === 'Quantity')) &&
    managerActions.some((n) => (n.data.changes || []).some((c) => c.label === 'Added')) &&
    managerActions.some((n) => (n.data.facts || []).some((f) => f.label === 'Quantity')) &&
    managerActions.every((n) => n.data.shopName && n.data.performedByName) &&
    withDetails.length > 0 &&
    dashWithDetails.length > 0;
  console.log(`\nRESULT: ${ok ? 'PASS' : 'FAIL'}`);

  // cleanup: remove the probe notifications, the audit entries and the records
  await connectDB();
  const ids = created2.map((n) => n._id || n.id);
  await Notification.deleteMany({ _id: { $in: ids } });
  await AuditLog.deleteMany({ remarks: { $regex: 'ZZ (Notification Probe|Probe Customer)' } });
  await Product.deleteMany({ name: productName });
  await Customer.deleteMany({ name: { $regex: '^ZZ Probe Customer' } });
  console.log('cleaned up probe notifications, audit entries, product and customer');
  await mongoose.disconnect();
  process.exit(ok ? 0 : 1);
})().catch(async (err) => {
  console.error('FAILED:', err.message);
  process.exit(1);
});
