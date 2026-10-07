const express = require('express');
const supplierController = require('../controllers/supplierController');
const { restrictTo, scopedShop } = require('../middleware/auth');
const router = express.Router();

router.get('/', scopedShop, supplierController.listSuppliers);
router.get('/:id', supplierController.getSupplier);

router.post('/', restrictTo('manager', 'admin'), supplierController.createSupplier);
router.put('/:id', restrictTo('manager', 'admin'), supplierController.updateSupplier);
router.delete('/:id', restrictTo('manager', 'admin'), supplierController.deleteSupplier);
router.post('/:id/restore', restrictTo('manager', 'admin'), supplierController.restoreSupplier);
router.post('/:id/balance', restrictTo('manager', 'admin'), supplierController.adjustBalance);

module.exports = router;
