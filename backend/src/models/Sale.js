const mongoose = require('mongoose');

const carpetPieceSchema = new mongoose.Schema(
  {
    width: { type: Number, default: 0 },
    height: { type: Number, default: 0 },
    area: { type: Number, default: 0 },
    color: { type: String, default: '' },
    image: { type: String, default: '' },
  },
  { _id: false }
);

const variantSchema = new mongoose.Schema(
  {
    color: { type: String, default: '' },
    size: { type: String, default: '' },
    quantity: { type: Number, default: 0, min: 0 },
  },
  { _id: false }
);

const saleItemSchema = new mongoose.Schema(
  {
    product: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', required: true },
    productName: { type: String, default: '' },
    quantity: { type: Number, required: true, min: 1 },
    unitPrice: { type: Number, required: true, min: 0 },
    totalAmount: { type: Number, required: true, min: 0 },
    costPrice: { type: Number, default: 0 },
    foamQty: { type: Number, default: 0, min: 0 },
    pillowQty: { type: Number, default: 0, min: 0 },
    coverQty: { type: Number, default: 0, min: 0 },
    // The exact physical piece / meters deducted from dimensional stock.
    carpetPiece: { type: carpetPieceSchema, default: null },
    // The exact colour x size rows deducted, so reversing the sale returns
    // stock to the same rows instead of guessing.
    variants: { type: [variantSchema], default: [] },
    length: { type: Number, default: 0 },
  },
  { _id: false }
);

const saleSchema = new mongoose.Schema(
  {
    invoiceNo: { type: String, required: true, unique: true },
    shop: { type: mongoose.Schema.Types.ObjectId, ref: 'Shop', required: true },
    customerName: { type: String, default: 'Walk-in Customer' },
    customerPhone: { type: String, default: '' },
    items: { type: [saleItemSchema], required: true },
    subtotal: { type: Number, required: true, min: 0, default: 0 },
    discount: { type: Number, default: 0, min: 0 },
    totalAmount: { type: Number, required: true, min: 0 },
    paidAmount: { type: Number, default: 0, min: 0 },
    dueAmount: { type: Number, default: 0, min: 0 },
    profit: { type: Number, default: 0 },
    paymentMethod: {
      type: String,
      enum: ['cash', 'bank', 'easypaisa', 'jazzcash', 'credit'],
      default: 'cash',
    },
    notes: { type: String, default: '' },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    isDeleted: { type: Boolean, default: false },
    deletedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    deletedAt: { type: Date, default: null },
    deleteReason: { type: String, default: '' },
  },
  { timestamps: true }
);

saleSchema.index({ shop: 1, createdAt: -1 });
saleSchema.index({ isDeleted: 1 });

module.exports = mongoose.model('Sale', saleSchema);
