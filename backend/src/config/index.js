require('dotenv').config();

module.exports = {
  port: process.env.PORT || 5000,
  nodeEnv: process.env.NODE_ENV || 'development',
  mongoUri: process.env.MONGO_URI || 'mongodb://localhost:27017/mcq',
  jwtSecret: process.env.JWT_SECRET || 'dev_secret_change_me',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  admin: {
    name: process.env.ADMIN_NAME || 'Admin Muallim',
    email: process.env.ADMIN_EMAIL || 'admin@muallimcarpets.com',
    password: process.env.ADMIN_PASSWORD || 'Admin@123',
  },
  managerPassword: process.env.MANAGER_PASSWORD || 'Manager@123',
  email: {
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT, 10) || 465,
    secure: process.env.SMTP_SECURE === 'true' || true,
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    from: process.env.SMTP_FROM || process.env.SMTP_USER || '',
    to: process.env.REPORT_RECIPIENT_EMAIL || process.env.SMTP_USER || '',
    enabled: (process.env.SMTP_USER && process.env.SMTP_PASS) ? true : false,
  },
  whatsapp: {
    // Meta WhatsApp Business Cloud API credentials.
    token: process.env.WHATSAPP_API_TOKEN || '',
    phoneId: process.env.WHATSAPP_PHONE_ID || '',
    // Graph API version, e.g. v21.0.
    apiVersion: process.env.WHATSAPP_API_VERSION || 'v21.0',
    // Destination country code used to normalise local numbers (e.g. 0300... -> 92300...).
    countryCode: process.env.WHATSAPP_COUNTRY_CODE || '92',
    // When true (default), a PDF receipt is sent to the customer's WhatsApp
    // after every sale that includes a phone number.
    receiptsEnabled: process.env.WHATSAPP_RECEIPTS_ENABLED !== 'false',
    // When true, invoices are ONLY delivered to WHATSAPP_TEST_RECIPIENT.
    // Real customer numbers are never messaged while test mode is enabled.
    testMode: process.env.WHATSAPP_TEST_MODE === 'true',
    testRecipient: process.env.WHATSAPP_TEST_RECIPIENT || '',
    // Webhook verification token and Meta App Secret (HMAC signature checks).
    webhookVerifyToken: process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN || '',
    appSecret: process.env.WHATSAPP_APP_SECRET || '',
    // Optional approved utility template name used as a fallback if the
    // document delivery fails. Must exist and be approved for the WABA.
    utilityTemplate: process.env.WHATSAPP_UTILITY_TEMPLATE || '',
    enabled: !!(process.env.WHATSAPP_API_TOKEN && process.env.WHATSAPP_PHONE_ID),
  },
  dailyReportCron: process.env.DAILY_REPORT_CRON || '0 21 * * *',
};
