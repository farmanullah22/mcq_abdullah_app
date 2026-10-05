const mongoose = require('mongoose');

// A personal cash-book ("khata") kept by an admin. Entries are private to the
// admin who recorded them and are deliberately NOT attached to a shop, because
// they track money the admin personally hands out or collects, not shop
// operational expenses.
const khataEntrySchema = new mongoose.Schema(
  {
    customerName: { type: String, required: true, trim: true },
    customerNumber: { type: String, default: '', trim: true },
    // 'out' = admin gave the money, 'in' = admin received it back.
    direction: { type: String, enum: ['in', 'out'], required: true },
    amount: { type: Number, required: true, min: 0 },
    method: {
      type: String,
      enum: ['cash', 'bank', 'cheque', 'online', 'easypaisa', 'jazzcard'],
      default: 'cash',
    },
    entryDate: { type: Date, default: Date.now },
    notes: { type: String, default: '' },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    isDeleted: { type: Boolean, default: false },
    deletedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    deletedAt: { type: Date, default: null },
    deleteReason: { type: String, default: '' },
  },
  { timestamps: true }
);

khataEntrySchema.index({ createdBy: 1, entryDate: -1 });
khataEntrySchema.index({ isDeleted: 1 });

module.exports = mongoose.model('KhataEntry', khataEntrySchema);