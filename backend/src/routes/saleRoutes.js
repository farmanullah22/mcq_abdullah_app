const express = require('express');
const saleController = require('../controllers/saleController');
const { restrictTo, scopedShop } = require('../middleware/auth');
const router = express.Router();

router.get('/', scopedShop, saleController.listSales);
router.get('/:id', saleController.getSale);

router.post('/', restrictTo('manager', 'admin'), saleController.createSale);
router.put('/:id', restrictTo('manager', 'admin'), saleController.updateSale);
router.delete('/:id', restrictTo('manager', 'admin'), saleController.deleteSale);
router.post('/:id/restore', restrictTo('manager', 'admin'), saleController.restoreSale);

module.exports = router;
