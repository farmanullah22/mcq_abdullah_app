const express = require('express');
const notificationController = require('../controllers/notificationController');
const router = express.Router();

router.get('/', notificationController.listNotifications);
router.get('/unread-count', notificationController.unreadCount);
router.post('/token', notificationController.registerToken);
router.put('/read-all', notificationController.markAllRead);
router.put('/:id/read', notificationController.markRead);
// Bulk delete must be registered before the ':id' route so it is not swallowed by it.
router.delete('/', notificationController.deleteAllNotifications);
router.delete('/:id', notificationController.deleteNotification);

module.exports = router;
