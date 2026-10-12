const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const crypto = require('node:crypto');

const ROOT = path.resolve(__dirname, '..');
const CONFIG_PATH = path.join(ROOT, 'src', 'config');
const SERVICE_PATH = path.join(ROOT, 'src', 'services', 'whatsappService');

// Loads a fresh copy of config + whatsappService with the given env overrides.
// dotenv never overrides variables already present in process.env, so values
// set here always win and no real .env secrets are used.
const load = (overrides = {}) => {
  process.env.WHATSAPP_API_TOKEN = 'test-token';
  process.env.WHATSAPP_PHONE_ID = '1234567890';
  process.env.WHATSAPP_API_VERSION = 'v21.0';
  process.env.WHATSAPP_RECEIPTS_ENABLED = 'true';
  process.env.WHATSAPP_TEST_MODE = 'false';
  process.env.WHATSAPP_TEST_RECIPIENT = '';
  process.env.WHATSAPP_COUNTRY_CODE = '92';
  process.env.WHATSAPP_UTILITY_TEMPLATE = '';
  process.env.WHATSAPP_APP_SECRET = '';
  process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN = '';
  Object.assign(process.env, overrides);

  for (const key of Object.keys(require.cache)) {
    if (key === require.resolve(CONFIG_PATH) || key === require.resolve(SERVICE_PATH)) {
      delete require.cache[key];
    }
  }
  return {
    config: require(CONFIG_PATH),
    service: require(SERVICE_PATH),
  };
};

const makeSale = (extra = {}) => ({
  invoiceNo: 'INV-1001',
  customerName: 'Test Customer',
  totalAmount: 1000,
  subtotal: 1000,
  discount: 0,
  paidAmount: 1000,
  dueAmount: 0,
  paymentMethod: 'cash',
  createdAt: new Date(),
  shop: { name: 'Branch 1' },
  items: [],
  ...extra,
});

test('normalizePhone handles local, +92, and 00 prefixes', () => {
  const { service } = load();
  assert.equal(service.normalizePhone('03001234567'), '923001234567');
  assert.equal(service.normalizePhone('+92 300 1234567'), '923001234567');
  assert.equal(service.normalizePhone('0092-300-1234567'), '923001234567');
  assert.equal(service.normalizePhone('30012345678'), '30012345678');
  assert.equal(service.normalizePhone('123'), '');
  assert.equal(service.normalizePhone(''), '');
});

test('returns not_configured when credentials are missing', async () => {
  const { service } = load({ WHATSAPP_API_TOKEN: '', WHATSAPP_PHONE_ID: '' });
  const result = await service.sendWhatsAppReceipt(makeSale(), '03001234567');
  assert.equal(result.attempted, false);
  assert.equal(result.reason, 'not_configured');
});

test('returns invalid_phone for a malformed number', async () => {
  const { service } = load();
  const result = await service.sendWhatsAppReceipt(makeSale(), '12');
  assert.equal(result.attempted, true);
  assert.equal(result.reason, 'invalid_phone');
});

test('never resends a receipt that was already attempted', async () => {
  const { service } = load();
  const sale = makeSale({
    whatsappReceipt: { attempted: true, sent: true, messageId: 'wamid.OLD' },
  });
  const result = await service.sendWhatsAppReceipt(sale, '03001234567');
  assert.equal(result.reason, 'already_attempted');
  assert.equal(result.sent, true);
  assert.equal(result.messageId, 'wamid.OLD');
});

test('test mode blocks any number other than the test recipient', async () => {
  const { service } = load({
    WHATSAPP_TEST_MODE: 'true',
    WHATSAPP_TEST_RECIPIENT: '923001234567',
  });
  const result = await service.sendWhatsAppReceipt(makeSale(), '03009999999');
  assert.equal(result.attempted, false);
  assert.equal(result.reason, 'test_mode_blocked');
});

test('test mode with no recipient set sends nothing', async () => {
  const { service } = load({ WHATSAPP_TEST_MODE: 'true', WHATSAPP_TEST_RECIPIENT: '' });
  const result = await service.sendWhatsAppReceipt(makeSale(), '03001234567');
  assert.equal(result.reason, 'test_mode_no_recipient');
});

test('sends the PDF and returns the Meta message id (test recipient)', async () => {
  const { service } = load({
    WHATSAPP_TEST_MODE: 'true',
    WHATSAPP_TEST_RECIPIENT: '923001234567',
  });

  const calls = [];
  global.fetch = async (url, options) => {
    calls.push({ url: String(url), options });
    if (String(url).endsWith('/media')) {
      return { ok: true, json: async () => ({ id: 'MEDIA_1' }) };
    }
    return { ok: true, json: async () => ({ messages: [{ id: 'wamid.TEST123' }] }) };
  };

  const result = await service.sendWhatsAppReceipt(makeSale(), '03001234567');
  assert.equal(result.sent, true);
  assert.equal(result.reason, 'sent');
  assert.equal(result.messageId, 'wamid.TEST123');
  assert.equal(calls.length, 2);
  assert.ok(calls[0].url.includes('/v21.0/1234567890/media'));
  assert.ok(calls[1].url.includes('/v21.0/1234567890/messages'));
});

test('returns a safe error object when the Graph API rejects the send', async () => {
  const { service } = load();
  global.fetch = async () => ({
    ok: false,
    json: async () => ({ error: { message: 'Recipient not in allowed list' } }),
  });

  const result = await service.sendWhatsAppReceipt(makeSale(), '03001234567');
  assert.equal(result.attempted, true);
  assert.equal(result.sent, false);
  assert.equal(result.reason, 'error');
  assert.match(result.error, /Recipient not in allowed list/);
});

test('verifyWebhookSignature accepts valid HMAC and rejects tampering', () => {
  const { service } = load();
  const raw = JSON.stringify({ object: 'whatsapp_business_account', entry: [] });
  const secret = 's3cret';
  const valid = 'sha256=' + crypto.createHmac('sha256', secret).update(raw).digest('hex');

  assert.equal(service.verifyWebhookSignature(raw, valid, secret), true);
  assert.equal(service.verifyWebhookSignature(raw, valid, 'wrong-secret'), false);
  assert.equal(service.verifyWebhookSignature(raw, 'sha256=deadbeef', secret), false);
  assert.equal(service.verifyWebhookSignature(raw, undefined, secret), false);
  assert.equal(service.verifyWebhookSignature(raw, valid, ''), false);
});

test('parseWebhookEntries flattens delivery statuses including failures', () => {
  const { service } = load();
  const payload = {
    entry: [
      {
        changes: [
          {
            value: {
              statuses: [
                { id: 'wamid.A', status: 'delivered', timestamp: 1700000000 },
                {
                  id: 'wamid.B',
                  status: 'failed',
                  timestamp: 1700000001,
                  errors: [{ message: 'Re-engagement message' }],
                },
              ],
            },
          },
        ],
      },
    ],
  };

  const entries = service.parseWebhookEntries(payload);
  assert.equal(entries.length, 2);
  assert.equal(entries[0].messageId, 'wamid.A');
  assert.equal(entries[0].status, 'delivered');
  assert.ok(entries[0].statusChangedAt instanceof Date);
  assert.equal(entries[1].status, 'failed');
  assert.match(entries[1].error, /Re-engagement message/);

  assert.deepEqual(service.parseWebhookEntries({}), []);
  assert.deepEqual(service.parseWebhookEntries(null), []);
});
