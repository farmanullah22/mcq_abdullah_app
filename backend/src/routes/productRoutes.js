const express = require('express');
const productController = require('../controllers/productController');
const { restrictTo, scopedShop } = require('../middleware/auth');
const router = express.Router();

router.get('/', scopedShop, productController.listProducts);
router.get('/low-stock', scopedShop, productController.lowStockProducts);
router.get('/:id', productController.getProduct);

router.post('/', restrictTo('manager', 'admin'), productController.createProduct);
router.put('/:id', restrictTo('manager', 'admin'), productController.updateProduct);
router.delete('/:id', restrictTo('manager', 'admin'), productController.deleteProduct);
router.post('/:id/restore', restrictTo('manager', 'admin'), productController.restoreProduct);

module.exports = router;
