// End-to-end write test against the DEPLOYED Heroku API.
// Creates a product that includes a small base64 picture, reads it back,
// then soft-deletes it. Cleanup of the test rows happens via MongoDB Atlas.
const BASE = process.env.API_BASE || 'https://abdullahcarpets-f997ce1dad43.herokuapp.com/api';
const EMAIL = process.env.ADMIN_EMAIL || 'admin@muallimcarpets.com';
const PASSWORD = process.env.ADMIN_PASSWORD || 'Admin@123';

// 1x1 transparent PNG, small payload that still exercises the image column.
const PNG = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

const req = async (method, path, body, token) => {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(BASE + path, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try { data = await res.json(); } catch (_) {}
  return { status: res.status, data };
};

const run = async () => {
  const startedAt = new Date().toISOString();
  console.log(`Target: ${BASE}`);
  console.log(`Started: ${startedAt}\n`);

  let r = await req('GET', '/health');
  console.log(`health: ${r.status} ${r.data && r.data.message}`);

  r = await req('POST', '/auth/login', { email: EMAIL, password: PASSWORD });
  if (r.status !== 200) throw new Error(`login failed: ${r.status} ${JSON.stringify(r.data)}`);
  const token = r.data.data.token;
  console.log(`login: ${r.status} as ${r.data.data.user.role} (${r.data.data.user.email})`);

  const name = `ZZ-Heroku-E2E-${Date.now()}`;
  r = await req('POST', '/products', {
    name,
    sku: `ZZ${Date.now()}`,
    productType: 'foam',
    costPrice: 50,
    sellingPrice: 80,
    quantity: 2,
    images: [PNG],
  }, token);
  console.log(`POST /products: ${r.status} -> ${r.data && r.data.message}`);
  const created = r.data && r.data.data;
  if (!created || !created._id) throw new Error(`product not created: ${JSON.stringify(r.data)}`);
  const id = created._id;
  console.log(`  _id: ${id}`);
  console.log(`  image stored in response: ${created.images && created.images[0] === PNG}`);

  r = await req('GET', `/products/${id}`, null, token);
  console.log(`GET /products/:id: ${r.status}, image round-trip: ${r.data.data.images && r.data.data.images[0] === PNG}`);

  r = await req('GET', `/products?search=${encodeURIComponent(name)}&limit=5`, null, token);
  const found = r.data && r.data.data && r.data.data.products ? r.data.data.products.length : 0;
  console.log(`GET /products?search=...: ${r.status}, matches: ${found}`);

  r = await req('DELETE', `/products/${id}`, { deleteReason: 'Heroku E2E test cleanup' }, token);
  console.log(`DELETE /products/:id: ${r.status} -> ${r.data && r.data.message}`);

  console.log(`\nTEST_PRODUCT_ID=${id}`);
  console.log(`WINDOW_START=${startedAt}`);
  console.log('PRODUCTION TEST DONE');
};

run().catch((e) => {
  console.error('PRODUCTION TEST FAILED:', e.message);
  process.exit(1);
});
