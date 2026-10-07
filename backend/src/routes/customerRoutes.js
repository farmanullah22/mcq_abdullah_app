const express = require('express');
const customerController = require('../controllers/customerController');
const { restrictTo, scopedShop } = require('../middleware/auth');
const router = express.Router();

router.get('/', scopedShop, customerController.listCustomers);
router.get('/:id', customerController.getCustomer);

router.post('/', restrictTo('manager', 'admin'), customerController.createCustomer);
router.put('/:id', restrictTo('manager', 'admin'), customerController.updateCustomer);
router.delete('/:id', restrictTo('manager', 'admin'), customerController.deleteCustomer);
router.post('/:id/restore', restrictTo('manager', 'admin'), customerController.restoreCustomer);
router.post('/:id/balance', restrictTo('manager', 'admin'), customerController.adjustBalance);

module.exports = router;
