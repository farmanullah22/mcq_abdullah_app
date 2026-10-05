const express = require('express');
const khataController = require('../controllers/khataController');
const { restrictTo } = require('../middleware/auth');
const router = express.Router();

// The khata is a private admin notebook. Every endpoint is admin-only, and the
// controller additionally scopes reads and writes to the calling admin.
router.use(restrictTo('admin'));

router.get('/', khataController.listKhataEntries);
router.post('/', khataController.createKhataEntry);
router.put('/:id', khataController.updateKhataEntry);
router.delete('/:id', khataController.deleteKhataEntry);
router.post('/:id/restore', khataController.restoreKhataEntry);

module.exports = router;