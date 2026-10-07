const express = require('express');
const inventoryController = require('../controllers/inventoryController');
const { restrictTo } = require('../middleware/auth');
const router = express.Router();

router.post('/in', restrictTo('manager', 'admin'), inventoryController.stockIn);
router.post('/out', restrictTo('manager', 'admin'), inventoryController.stockOut);
router.post('/transfer', restrictTo('manager', 'admin'), inventoryController.transferStock);
router.get('/shops', inventoryController.transferShops);
router.get('/products/:shopId', inventoryController.shopProducts);
router.get('/history', inventoryController.inventoryHistory);

module.exports = router;
