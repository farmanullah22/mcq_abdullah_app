const express = require('express');
const expenseController = require('../controllers/expenseController');
const { restrictTo, scopedShop } = require('../middleware/auth');
const router = express.Router();

router.get('/', scopedShop, expenseController.listExpenses);

router.post('/', restrictTo('manager', 'admin'), expenseController.createExpense);
router.put('/:id', restrictTo('manager', 'admin'), expenseController.updateExpense);
router.delete('/:id', restrictTo('manager', 'admin'), expenseController.deleteExpense);
router.post('/:id/restore', restrictTo('manager', 'admin'), expenseController.restoreExpense);

module.exports = router;
