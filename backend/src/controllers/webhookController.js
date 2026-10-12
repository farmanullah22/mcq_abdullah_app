const Sale = require('../models/Sale');
const config = require('../config');
const {
  verifyWebhookSignature,
  parseWebhookEntries,
} = require('../services/whatsappService');

// GET /api/whatsapp/webhook?hub.mode=subscribe&hub.verify_token=...&hub.challenge=...
// Meta's webhook "verify and subscribe" handshake.
const handleVerification = (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  if (
    mode === 'subscribe' &&
    token &&
    config.whatsapp.webhookVerifyToken &&
    token === config.whatsapp.webhookVerifyToken
  ) {
    return res.status(200).send(challenge);
  }
  return res.status(403).json({ success: false, message: 'Verification failed' });
};

// POST /api/whatsapp/webhook — Meta deliveries delivery status events.
const handleEvent = async (req, res) => {
  // Reject unauthenticated events before doing anything else. Meta does not
  // send a signature until the App Secret is configured.
  if (config.whatsapp.appSecret) {
    const signature = req.headers['x-hub-signature-256'];
    if (!verifyWebhookSignature(req.rawBody, signature, config.whatsapp.appSecret)) {
      console.warn('[whatsapp-webhook] rejected event: bad X-Hub-Signature-256');
      return res.status(401).json({ success: false, message: 'Invalid signature' });
    }
  }

  // Reply immediately so Meta does not retry; status processing is async below.
  res.status(200).json({ success: true });

  const entries = parseWebhookEntries(req.body);
  if (!entries.length) return;

  for (const entry of entries) {
    try {
      const sale = await Sale.findOne({ 'whatsappReceipt.messageId': entry.messageId });
      if (!sale) continue;

      const current = sale.whatsappReceipt || {};
      const sameStatus =
        current.status === entry.status &&
        current.statusChangedAt &&
        entry.statusChangedAt &&
        current.statusChangedAt.getTime() === entry.statusChangedAt.getTime();

      // Idempotent: skip re-processing the exact same delivery event.
      if (sameStatus) {
        sale.whatsappReceipt.error = entry.error || current.error || '';
        continue;
      }

      sale.whatsappReceipt.status = entry.status;
      sale.whatsappReceipt.statusChangedAt = entry.statusChangedAt;
      if (entry.error) sale.whatsappReceipt.error = entry.error;
      if (entry.status === 'sent' && !sale.whatsappReceipt.sentAt) {
        sale.whatsappReceipt.sentAt = entry.statusChangedAt || new Date();
      }
      await sale.save();
      console.log(`[whatsapp-webhook] sale ${sale.invoiceNo} -> ${entry.status}`);
    } catch (err) {
      console.error('[whatsapp-webhook] failed to apply status', err.message);
    }
  }
};

module.exports = { handleVerification, handleEvent };