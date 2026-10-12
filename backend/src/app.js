const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const routes = require('./routes');
const { errorHandler } = require('./middleware/errorHandler');

const app = express();

// Trust exactly one reverse proxy (Nginx) so req.ip reflects the real client
// from X-Forwarded-For instead of the proxy address. Nginx must be the only
// path to this server; never expose the Node port directly, otherwise clients
// could spoof X-Forwarded-For and bypass IP-based rate limiting.
app.set('trust proxy', 1);

app.use(helmet());
app.use(cors({ origin: true, credentials: true }));
// Keep the raw request bytes so WhatsApp webhook signatures can be verified.
app.use(
  express.json({
    limit: '10mb',
    verify: (req, _res, buf) => {
      req.rawBody = buf;
    },
  })
);
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(morgan('dev'));

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100000,
  message: { success: false, message: 'Too many requests, please try again later.' },
});
app.use('/api', limiter);

app.get('/', (req, res) =>
  res.json({ success: true, name: 'MCQ (Muallim Carpets) API', version: '1.0.0', docs: '/api/health' })
);

app.use('/api', routes);

app.use(errorHandler);

module.exports = app;
