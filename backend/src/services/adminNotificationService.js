/**
 * Creates the admin-facing notification for a change a manager made inside
 * their own branch / warehouse.
 *
 * The notification carries a structured `data` payload so the app can render
 * the full picture (what changed, old value -> new value, how much) instead of
 * a one line message.
 */

const User = require('../models/User');
const Shop = require('../models/Shop');
const Notification = require('../models/Notification');
const { describeChange } = require('./changeDetails');

// Noise that should not reach the admin's inbox.
const SKIP_ACTIONS = new Set(['LOGIN', 'LOGOUT', 'REPORT_DOWNLOAD']);

// Actions that already raise their own (enriched) notification.
const SKIP_ACTIONS_WITH_OWN_NOTIFICATION = new Set(['CREATE_SALE', 'CREATE_EXPENSE']);

const shopNameFor = async (log, req) => {
  if (log.shopName) return log.shopName;
  if (!log.shopId) return '';
  const assigned = req.user && req.user.assignedShop ? String(req.user.assignedShop._id) : '';
  if (assigned && assigned === String(log.shopId)) {
    return req.user.assignedShop.name || '';
  }
  const shop = await Shop.findById(log.shopId).select('name').lean();
  return shop ? shop.name : '';
};

/**
 * @param {object} params
 * @param {object} params.req    the express request (for the acting user)
 * @param {object} params.log    the created AuditLog document
 * @param {object} params.detail result of describeChange()
 */
const notifyAdminsOfChange = async ({ req, log, detail }) => {
  try {
    if (!req.user || req.user.role !== 'manager') return;
    if (SKIP_ACTIONS.has(log.actionType)) return;
    if (SKIP_ACTIONS_WITH_OWN_NOTIFICATION.has(log.actionType)) return;

    const admins = await User.find({ role: 'admin', isActive: true }).select('_id');
    if (!admins.length) return;

    const shopName = await shopNameFor(log, req);
    const actor = req.user.name || 'A manager';

    const verb = detail.verb;
    const label = detail.label;
    const where = shopName ? ` at ${shopName}` : '';

    const title = `${actor} ${verb} a ${label.toLowerCase()}${where}`;

    // The body is a one line summary: the record identity plus the key facts.
    // When the facts already name the record the identity would be a repeat.
    const hasNameFact = detail.facts.some((f) => f.label === 'Name');
    const parts = [];
    if (detail.identity && !hasNameFact) parts.push(detail.identity);
    for (const fact of detail.facts.slice(0, 3)) parts.push(`${fact.label}: ${fact.value}`);
    const body = parts.join(' · ') || log.remarks || '';

    const data = {
      actionType: log.actionType,
      module: log.module,
      recordType: log.recordType,
      recordId: log.recordId ? String(log.recordId) : null,
      auditLogId: String(log._id),
      shopId: log.shopId ? String(log.shopId) : null,
      shopName,
      performedById: req.user._id ? String(req.user._id) : null,
      performedByName: actor,
      status: log.status,
      remarks: log.remarks || '',
      identity: detail.identity,
      facts: detail.facts,
      changes: detail.changes,
      itemLines: detail.itemLines,
    };

    await Notification.insertMany(
      admins.map((admin) => ({
        user: admin._id,
        title,
        body,
        type: 'manager_action',
        data,
      }))
    );
  } catch (err) {
    // A failed notification must never break the action the manager performed.
    console.error('Failed to notify admins of change:', err.message);
  }
};

module.exports = { notifyAdminsOfChange, SKIP_ACTIONS };
