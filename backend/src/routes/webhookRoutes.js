const express = require('express');
const { handleVerification, handleEvent } = require('../controllers/webhookController');

const router = express.Router();

// Meta sends a verification handshake here when you configure the webhook.
router.get('/webhook', handleVerification);
// Meta POSTs delivery status events here (sent, delivered, read, failed).
router.post('/webhook', handleEvent);

module.exports = router;