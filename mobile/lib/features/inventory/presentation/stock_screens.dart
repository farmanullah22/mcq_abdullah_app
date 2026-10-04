import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../../products/models/product.dart';
import '../../products/providers/product_providers.dart';
import '../../suppliers/models/supplier.dart';
import '../../suppliers/presentation/supplier_form_screen.dart';
import '../providers/inventory_meta.dart';
import '../providers/inventory_providers.dart';

String _unitFor(String productType, {bool variantCarpet = false}) {
  if (variantCarpet) return 'pcs';
  switch (productType) {
    case 'carpet':
      return 'sqft';
    case 'meter':
      return 'm';
    default:
      return 'pcs';
  }
}

// Mirrors the backend rule: Foam Cover / Pillow Cover are always colour
// products, a carpet only uses variants when it is not an old piece-tracked
// (width x height) carpet, and foam is stocked as a plain quantity.
bool _usesVariantsType(
  String productType, {
  List<CarpetPieceData> pieces = const [],
  double width = 0,
  double height = 0,
}) {
  if (productType == 'foam_cover' || productType == 'pillow_cover') {
    return true;
  }
  if (productType == 'carpet') {
    final legacy = pieces.isNotEmpty || (width > 0 && height > 0);
    return !legacy;
  }
  return false;
}

class _ShopBadgeLabel extends StatelessWidget {
  const _ShopBadgeLabel({required this.shop});

  final TransferShopMeta shop;

  @override
  Widget build(BuildContext context) {
    final isWh = shop.isWarehouse;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isWh
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isWh ? 'Warehouse' : 'Branch',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isWh ? AppColors.primary : AppColors.gold,
            ),
          ),
        ),
      ],
    );
  }
}

String _fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

String _dataUrl(Uint8List bytes) {
  final ext = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50
      ? 'png'
      : 'jpeg';
  return 'data:image/$ext;base64,${base64.encode(bytes)}';
}

Widget _pieceThumb(CarpetPieceData piece) {
  final fallback = Container(
    height: 34,
    width: 34,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Icon(Icons.crop_landscape, size: 18, color: AppColors.primary),
  );
  final img = piece.image;
  if (img.startsWith('data:image')) {
    try {
      final bytes = base64.decode(img.split(',').last);
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(bytes, height: 34, width: 34, fit: BoxFit.cover),
      );
    } catch (_) {
      return fallback;
    }
  }
  if (img.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        img,
        height: 34,
        width: 34,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
  return fallback;
}

class _CarpetPieceDraft {
  final double width;
  final double height;
  final String color;
  final Uint8List? imageBytes;

  const _CarpetPieceDraft(
    this.width,
    this.height, {
    this.color = '',
    this.imageBytes,
  });

  double get area => width * height;
}

class _QaleenSizeDraft {
  final double height;
  final double width;
  final int pieces;

  const _QaleenSizeDraft(this.height, this.width, this.pieces);
}

class _VariantDraft {
  _VariantDraft({String color = '', String size = '', String qty = ''}) {
    colorCtrl = TextEditingController(text: color);
    sizeCtrl = TextEditingController(text: size);
    qtyCtrl = TextEditingController(text: qty);
  }

  late final TextEditingController colorCtrl;
  late final TextEditingController sizeCtrl;
  late final TextEditingController qtyCtrl;

  String get color => colorCtrl.text.trim();
  String get size => sizeCtrl.text.trim();
  int get quantity => int.tryParse(qtyCtrl.text.trim()) ?? 0;

  Map<String, dynamic> toJson() => {
    'color': color,
    'size': size,
    'quantity': quantity,
  };

  void dispose() {
    colorCtrl.dispose();
    sizeCtrl.dispose();
    qtyCtrl.dispose();
  }
}

class _MovementPayload {
  final num total;
  final List<Map<String, dynamic>> carpetPieces;
  final List<Map<String, dynamic>> qaleenSizes;
  final List<Map<String, dynamic>> variants;
  final double? length;

  const _MovementPayload({
    this.total = 0,
    this.carpetPieces = const [],
    this.qaleenSizes = const [],
    this.variants = const [],
    this.length,
  });
}

class _TransferProduct {
  final String id;
  final String name;
  final int quantity;
  final String productType;
  final List<CarpetPieceData> pieces;
  final List<QaleenSize> sizes;
  final double meterLength;
  final List<ProductVariant> variants;
  final bool usesVariants;

  const _TransferProduct({
    required this.id,
    required this.name,
    required this.quantity,
    required this.productType,
    this.pieces = const [],
    this.sizes = const [],
    this.meterLength = 0,
    this.variants = const [],
    this.usesVariants = false,
  });
}

_TransferProduct _parseTransferProduct(Map<String, dynamic> p) {
  final piecesRaw = (p['carpetPiecesData'] as List?) ?? const [];
  var pieces = piecesRaw
      .map((e) => CarpetPieceData.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  final cw = (p['carpetWidth'] as num?)?.toDouble() ?? 0;
  final ch = (p['carpetHeight'] as num?)?.toDouble() ?? 0;
  if (pieces.isEmpty && cw > 0 && ch > 0) {
    pieces = [CarpetPieceData(width: cw, height: ch, area: cw * ch)];
  }
  final sizesRaw = (p['qaleenSizes'] as List?) ?? const [];
  final sizes = sizesRaw
      .map((e) => QaleenSize.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  final variantsRaw = (p['variants'] as List?) ?? const [];
  final variants = variantsRaw
      .map((e) => ProductVariant.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  return _TransferProduct(
    id: (p['_id'] ?? p['id']).toString(),
    name: p['name']?.toString() ?? '',
    quantity: (p['quantity'] as num?)?.toInt() ?? 0,
    productType: p['productType']?.toString() ?? 'qaleen',
    pieces: pieces,
    sizes: sizes,
    meterLength: (p['meterLength'] as num?)?.toDouble() ?? 0,
    variants: variants,
    usesVariants: _usesVariantsType(
      p['productType']?.toString() ?? 'qaleen',
      pieces: pieces,
      width: cw,
      height: ch,
    ),
  );
}

// Conversion from the full product list (same data that powers Stock Out), so
// the transfer flow can show the same per-piece / per-size selectors.
_TransferProduct _transferFromProduct(Product p) {
  var pieces = p.carpetPiecesData;
  if (pieces.isEmpty && p.carpetWidth > 0 && p.carpetHeight > 0) {
    pieces = [
      CarpetPieceData(
        width: p.carpetWidth,
        height: p.carpetHeight,
        area: p.carpetWidth * p.carpetHeight,
      ),
    ];
  }
  return _TransferProduct(
    id: p.id,
    name: p.name,
    quantity: p.quantity,
    productType: p.productType,
    pieces: pieces,
    sizes: p.qaleenSizes,
    meterLength: p.meterLength,
    variants: p.variants,
    usesVariants: p.usesVariants,
  );
}

Future<_CarpetPieceDraft?> _showAddPieceSheet(
  BuildContext context,
  int index,
) async {
  final imagePicker = ImagePicker();
  final wCtrl = TextEditingController();
  final hCtrl = TextEditingController();
  final colorCtrl = TextEditingController();
  Uint8List? imageBytes;
  var areaText = 'Total area: 0 sqft';

  final result = await showModalBottomSheet<_CarpetPieceDraft>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        void refresh() {
          final w = double.tryParse(wCtrl.text) ?? 0;
          final h = double.tryParse(hCtrl.text) ?? 0;
          areaText = 'Total area: ${(w * h).toStringAsFixed(2)} sqft';
          setSheetState(() {});
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Piece', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Piece $index',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: wCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => refresh(),
                      decoration: const InputDecoration(labelText: 'Width (m)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: hCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => refresh(),
                      decoration: const InputDecoration(
                        labelText: 'Height (m)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                areaText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  prefixIcon: Icon(Icons.color_lens_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (imageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        imageBytes!,
                        height: 60,
                        width: 60,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await imagePicker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );
                      if (picked != null) {
                        final bytes = await picked.readAsBytes();
                        setSheetState(() => imageBytes = bytes);
                      }
                    },
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await imagePicker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 80,
                      );
                      if (picked != null) {
                        final bytes = await picked.readAsBytes();
                        setSheetState(() => imageBytes = bytes);
                      }
                    },
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Camera'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  final w = double.tryParse(wCtrl.text) ?? 0;
                  final h = double.tryParse(hCtrl.text) ?? 0;
                  if (w <= 0 || h <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter valid width and height'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(
                    ctx,
                    _CarpetPieceDraft(
                      w,
                      h,
                      color: colorCtrl.text.trim(),
                      imageBytes: imageBytes,
                    ),
                  );
                },
                child: const Text('Add Piece'),
              ),
            ],
          ),
        );
      },
    ),
  );
  return result;
}

Future<_QaleenSizeDraft?> _showAddSizeSheet(BuildContext context) async {
  final hCtrl = TextEditingController();
  final wCtrl = TextEditingController();
  final pCtrl = TextEditingController();

  final result = await showModalBottomSheet<_QaleenSizeDraft>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add Size', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: hCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Height (m)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: wCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Width (m)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: pCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pieces'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final h = double.tryParse(hCtrl.text) ?? 0;
              final w = double.tryParse(wCtrl.text) ?? 0;
              final pcs = int.tryParse(pCtrl.text) ?? 0;
              if (h > 0 && w > 0 && pcs > 0) {
                Navigator.pop(ctx, _QaleenSizeDraft(h, w, pcs));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
  return result;
}

/// Dimension-aware fields for STOCK IN. Based on product type the manager
/// records pieces (width x height -> auto area), qaleen sizes or meters.
class _StockInFields extends StatefulWidget {
  const _StockInFields({
    super.key,
    required this.productType,
    this.existingPieces = const [],
    this.hasLegacyRoll = false,
    this.existingSizes = const [],
    this.usesVariants = false,
    this.onChanged,
  });

  final String productType;
  final List<CarpetPieceData> existingPieces;
  final bool hasLegacyRoll;
  final List<QaleenSize> existingSizes;
  final bool usesVariants;
  final ValueChanged<_MovementPayload>? onChanged;

  @override
  State<_StockInFields> createState() => _StockInFieldsState();
}

class _StockInFieldsState extends State<_StockInFields> {
  final List<_CarpetPieceDraft> _pieces = [];
  final List<_QaleenSizeDraft> _sizes = [];
  final List<_VariantDraft> _variants = [];
  final _lengthCtrl = TextEditingController();
  final _genericQtyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _lengthCtrl.addListener(_emit);
    _genericQtyCtrl.addListener(_emit);
  }

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _genericQtyCtrl.dispose();
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  _MovementPayload _buildPayload() {
    final pt = widget.productType;
    if (widget.usesVariants) {
      final rows = _variants
          .where((v) => v.quantity > 0)
          .map((v) => v.toJson())
          .toList();
      return _MovementPayload(
        total: rows.fold<num>(0, (sum, r) => sum + (r['quantity'] as int)),
        variants: rows,
      );
    }
    if (pt == 'carpet') {
      if (_pieces.isNotEmpty) {
        return _MovementPayload(
          total: _pieces.fold<num>(0, (sum, p) => sum + p.area),
          carpetPieces: _pieces
              .map(
                (p) => {
                  'width': p.width,
                  'height': p.height,
                  'color': p.color,
                  if (p.imageBytes != null) 'image': _dataUrl(p.imageBytes!),
                },
              )
              .toList(),
        );
      }
      final g = num.tryParse(_genericQtyCtrl.text) ?? 0;
      return _MovementPayload(total: g);
    }
    if (pt == 'qaleen') {
      if (_sizes.isNotEmpty) {
        return _MovementPayload(
          total: _sizes.fold<num>(0, (sum, z) => sum + z.pieces),
          qaleenSizes: _sizes
              .map(
                (z) => {
                  'height': z.height,
                  'width': z.width,
                  'pieces': z.pieces,
                },
              )
              .toList(),
        );
      }
      final g = num.tryParse(_genericQtyCtrl.text) ?? 0;
      return _MovementPayload(total: g);
    }
    if (pt == 'meter') {
      final l = double.tryParse(_lengthCtrl.text) ?? 0;
      return _MovementPayload(total: l, length: l > 0 ? l : null);
    }
    final g = num.tryParse(_genericQtyCtrl.text) ?? 0;
    return _MovementPayload(total: g);
  }

  void _emit() => widget.onChanged?.call(_buildPayload());

  void _addVariant() {
    final draft = _VariantDraft();
    draft.qtyCtrl.addListener(_emit);
    setState(() => _variants.add(draft));
  }

  void _removeVariant(int index) {
    final draft = _variants.removeAt(index);
    draft.dispose();
    setState(() => _emit());
  }

  Future<void> _addPiece() async {
    final draft = await _showAddPieceSheet(context, _pieces.length + 1);
    if (draft != null) {
      setState(() => _pieces.add(draft));
      _emit();
    }
  }

  Future<void> _addSize() async {
    final draft = await _showAddSizeSheet(context);
    if (draft != null) {
      setState(() => _sizes.add(draft));
      _emit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = widget.productType;
    final payload = _buildPayload();
    final unit = widget.usesVariants
        ? 'pcs'
        : (pt == 'meter' ? 'm' : _unitFor(pt));
    final showGeneric =
        (pt == 'carpet' &&
            widget.existingPieces.isEmpty &&
            !widget.hasLegacyRoll) ||
        (pt == 'qaleen' && widget.existingSizes.isEmpty);

    Widget fields;
    if (widget.usesVariants) {
      fields = _buildVariantFields(payload, unit);
    } else {
      switch (pt) {
        case 'carpet':
          fields = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Carpet Pieces (width x height -> area)',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addPiece,
                icon: const Icon(Icons.add_box_outlined, size: 18),
                label: const Text('Add Piece'),
              ),
              const SizedBox(height: 6),
              if (_pieces.isEmpty)
                Text(
                  'No pieces added yet',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                )
              else
                Column(
                  children: [
                    const Divider(height: 12),
                    ...List.generate(_pieces.length, (i) {
                      final p = _pieces[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            if (p.imageBytes != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.memory(
                                  p.imageBytes!,
                                  height: 32,
                                  width: 32,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_fmtNum(p.width)}m x ${_fmtNum(p.height)}m | ${_fmtNum(p.area)} sqft'
                                '${p.color.isNotEmpty ? ' | ${p.color}' : ''}',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  setState(() => _pieces.removeAt(i)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              if (showGeneric)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: _genericQtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Quantity (sqft) - add without size',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                  ),
                ),
              if (_pieces.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Total to add: ${_fmtNum(payload.total.toDouble())} $unit',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          );
          break;
        case 'qaleen':
          fields = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Qaleen Sizes (height x width x pieces)',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addSize,
                icon: const Icon(Icons.add_box_outlined, size: 18),
                label: const Text('Add Size'),
              ),
              const SizedBox(height: 6),
              if (_sizes.isEmpty)
                Text(
                  'No sizes added yet',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                )
              else
                Column(
                  children: [
                    const Divider(height: 12),
                    ...List.generate(_sizes.length, (i) {
                      final z = _sizes[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_fmtNum(z.height)}m x ${_fmtNum(z.width)}m',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Text(
                              '${z.pieces} pcs',
                              style: const TextStyle(fontSize: 13),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  setState(() => _sizes.removeAt(i)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              if (showGeneric)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: _genericQtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity (pieces) - add without size',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                  ),
                ),
              if (_sizes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Total to add: ${_fmtNum(payload.total.toDouble())} $unit',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          );
          break;
        case 'meter':
          fields = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meter Length',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _lengthCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Length to add (m)',
                  prefixIcon: Icon(Icons.straighten),
                ),
              ),
              if (payload.total > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Total to add: ${_fmtNum(payload.total.toDouble())} $unit',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          );
          break;
        default:
          fields = TextField(
            controller: _genericQtyCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
          );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [fields],
    );
  }

  Widget _buildVariantFields(_MovementPayload payload, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Colours, Sizes & Quantity to add',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ..._variants.indexed.map((e) {
          final i = e.$1;
          final v = e.$2;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: v.colorCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Colour',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: v.sizeCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Size',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  child: TextField(
                    controller: v.qtyCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: 'Qty',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _removeVariant(i),
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: _addVariant,
          icon: const Icon(Icons.add_box_outlined, size: 18),
          label: const Text('Add Row'),
        ),
        if (payload.total > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Total to add: ${_fmtNum(payload.total.toDouble())} $unit',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Dimension-aware fields for STOCK OUT and STOCK TRANSFER. The manager picks
/// the exact carpet pieces / qaleen sizes / meters that leave the source shop.
class _StockOutFields extends StatefulWidget {
  const _StockOutFields({
    super.key,
    required this.productType,
    this.pieces = const [],
    this.sizes = const [],
    this.meterLength = 0,
    this.variants = const [],
    this.usesVariants = false,
    this.onChanged,
  });

  final String productType;
  final List<CarpetPieceData> pieces;
  final List<QaleenSize> sizes;
  final double meterLength;
  final List<ProductVariant> variants;
  final bool usesVariants;
  final ValueChanged<_MovementPayload>? onChanged;

  @override
  State<_StockOutFields> createState() => _StockOutFieldsState();
}

class _StockOutFieldsState extends State<_StockOutFields> {
  late List<bool> _selected;
  late List<TextEditingController> _sizeCtrls;
  late List<TextEditingController> _variantCtrls;
  final _lengthCtrl = TextEditingController();
  final _genericQtyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = List.filled(widget.pieces.length, false);
    _sizeCtrls = widget.sizes.map((_) => TextEditingController()).toList();
    for (final c in _sizeCtrls) {
      c.addListener(_emit);
    }
    _variantCtrls = widget.variants
        .map((_) => TextEditingController())
        .toList();
    for (final c in _variantCtrls) {
      c.addListener(_emit);
    }
    _lengthCtrl.addListener(_emit);
    _genericQtyCtrl.addListener(_emit);
  }

  @override
  void dispose() {
    for (final c in _sizeCtrls) {
      c.dispose();
    }
    for (final c in _variantCtrls) {
      c.dispose();
    }
    _lengthCtrl.dispose();
    _genericQtyCtrl.dispose();
    super.dispose();
  }

  _MovementPayload _buildPayload() {
    final pt = widget.productType;
    if (widget.usesVariants) {
      final rows = <Map<String, dynamic>>[];
      var total = 0;
      for (var i = 0; i < widget.variants.length; i++) {
        final qty = int.tryParse(_variantCtrls[i].text.trim()) ?? 0;
        if (qty > 0) {
          final capped = qty.clamp(0, widget.variants[i].quantity);
          rows.add({
            'color': widget.variants[i].color,
            'size': widget.variants[i].size,
            'quantity': capped,
          });
          total += capped;
        }
      }
      return _MovementPayload(total: total, variants: rows);
    }
    if (pt == 'carpet') {
      final sel = <CarpetPieceData>[];
      for (var i = 0; i < widget.pieces.length; i++) {
        if (_selected[i]) sel.add(widget.pieces[i]);
      }
      if (sel.isNotEmpty) {
        return _MovementPayload(
          total: sel.fold<num>(
            0,
            (sum, p) => sum + (p.area > 0 ? p.area : p.width * p.height),
          ),
          carpetPieces: sel
              .map(
                (p) => {
                  'width': p.width,
                  'height': p.height,
                  'color': p.color,
                  if (p.image.isNotEmpty) 'image': p.image,
                },
              )
              .toList(),
        );
      }
      final g = num.tryParse(_genericQtyCtrl.text) ?? 0;
      return _MovementPayload(total: g);
    }
    if (pt == 'qaleen') {
      final out = <QaleenSize>[];
      var total = 0;
      for (var i = 0; i < widget.sizes.length; i++) {
        final qty = int.tryParse(_sizeCtrls[i].text) ?? 0;
        if (qty > 0) {
          final capped = qty.clamp(0, widget.sizes[i].pieces);
          out.add(
            QaleenSize(
              height: widget.sizes[i].height,
              width: widget.sizes[i].width,
              pieces: capped,
            ),
          );
          total += capped;
        }
      }
      if (out.isNotEmpty) {
        return _MovementPayload(
          total: total,
          qaleenSizes: out.map((s) => s.toJson()).toList(),
        );
      }
      final g = num.tryParse(_genericQtyCtrl.text) ?? 0;
      return _MovementPayload(total: g);
    }
    if (pt == 'meter') {
      final l = double.tryParse(_lengthCtrl.text) ?? 0;
      return _MovementPayload(total: l, length: l > 0 ? l : null);
    }
    final g = num.tryParse(_genericQtyCtrl.text) ?? 0;
    return _MovementPayload(total: g);
  }

  void _emit() => widget.onChanged?.call(_buildPayload());

  @override
  Widget build(BuildContext context) {
    final pt = widget.productType;
    final payload = _buildPayload();
    final unit = widget.usesVariants
        ? 'pcs'
        : (pt == 'meter' ? 'm' : _unitFor(pt));

    Widget fields;
    if (widget.usesVariants) {
      fields = _buildVariantFields(payload, unit);
    } else {
      switch (pt) {
        case 'carpet':
          if (widget.pieces.isNotEmpty) {
            final selectedTotal = payload.total.toDouble();
            fields = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Select carpet pieces to remove',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        for (var i = 0; i < _selected.length; i++) {
                          _selected[i] = true;
                        }
                        setState(() {});
                        _emit();
                      },
                      child: const Text('Select all'),
                    ),
                  ],
                ),
                ...List.generate(widget.pieces.length, (i) {
                  final p = widget.pieces[i];
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _selected[i],
                    onChanged: (v) {
                      setState(() => _selected[i] = v ?? false);
                      _emit();
                    },
                    secondary: _pieceThumb(p),
                    title: Text('${_fmtNum(p.width)}m x ${_fmtNum(p.height)}m'),
                    subtitle: Text(
                      '${_fmtNum(p.area)} sqft${p.color.isNotEmpty ? ' · ${p.color}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }),
                if (selectedTotal > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Selected: ${_fmtNum(selectedTotal)} sqft',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            );
          } else {
            fields = TextField(
              controller: _genericQtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Quantity (sqft)',
                prefixIcon: Icon(Icons.indeterminate_check_box_outlined),
              ),
            );
          }
          break;
        case 'qaleen':
          if (widget.sizes.isNotEmpty) {
            fields = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quantity to remove per size',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ...List.generate(widget.sizes.length, (i) {
                  final s = widget.sizes[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_fmtNum(s.height)}m x ${_fmtNum(s.width)}m',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Available: ${s.pieces} pcs',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _sizeCtrls[i],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Remove',
                              prefixIcon: Icon(
                                Icons.remove_circle_outline,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (payload.total > 0)
                  Text(
                    'Selected: ${_fmtNum(payload.total.toDouble())} $unit',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
              ],
            );
          } else {
            fields = TextField(
              controller: _genericQtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity (pieces)',
                prefixIcon: Icon(Icons.indeterminate_check_box_outlined),
              ),
            );
          }
          break;
        case 'meter':
          fields = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Length to remove',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _lengthCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Length (m)',
                  prefixIcon: Icon(Icons.straighten),
                  helperText: 'Available: ${_fmtNum(widget.meterLength)}m',
                ),
              ),
              if (payload.total > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Selected: ${_fmtNum(payload.total.toDouble())} $unit',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          );
          break;
        default:
          fields = TextField(
            controller: _genericQtyCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              prefixIcon: Icon(Icons.indeterminate_check_box_outlined),
            ),
          );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [fields],
    );
  }

  Widget _buildVariantFields(_MovementPayload payload, String unit) {
    if (widget.variants.isEmpty) {
      return const Text(
        'This product has no colour/size stock rows yet. Stock it in first.',
        style: TextStyle(fontSize: 12, color: AppColors.danger),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantity per colour and size',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ...List.generate(widget.variants.length, (i) {
          final v = widget.variants[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Available: ${v.quantity} $unit',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _variantCtrls[i],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Remove',
                      isDense: true,
                      prefixIcon: Icon(Icons.remove_circle_outline, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        if (payload.total > 0)
          Text(
            'Selected: ${_fmtNum(payload.total.toDouble())} $unit',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              fontSize: 14,
            ),
          ),
      ],
    );
  }
}

class StockInScreen extends ConsumerStatefulWidget {
  const StockInScreen({super.key, this.productId, this.products});

  final String? productId;
  final List<Product>? products;

  @override
  ConsumerState<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends ConsumerState<StockInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();
  final _supplierSearchController = TextEditingController();
  String? _productId;
  Product? _selectedProduct;
  _MovementPayload _payload = const _MovementPayload();

  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  String? _selectedSupplierId;
  String _supplierSearch = '';
  bool _showSupplierSearch = false;

  List<Product> _warehouseProducts = const [];
  bool _warehouseLoading = true;
  String? _warehouseName;

  @override
  void initState() {
    super.initState();
    _productId = widget.productId;
    _loadSuppliers();
    _loadWarehouseProducts();
  }

  Future<void> _loadWarehouseProducts() async {
    try {
      final shops = await ref.read(inventoryRepositoryProvider).transferShops();
      Map<String, dynamic>? warehouse;
      for (final s in shops) {
        final t = s['shopType']?.toString() ?? '';
        final n = s['name']?.toString() ?? '';
        if (t == 'warehouse' ||
            RegExp(r'warehouse', caseSensitive: false).hasMatch(n)) {
          warehouse = s;
          break;
        }
      }
      if (warehouse != null) {
        final raw = await ref
            .read(inventoryRepositoryProvider)
            .shopProducts(warehouse['id'].toString());
        if (!mounted) return;
        setState(() {
          _warehouseProducts = raw.map(Product.fromJson).toList();
          _warehouseLoading = false;
          _warehouseName = warehouse?['name']?.toString() ?? 'Warehouse';
          if (_productId != null) {
            final matches = _warehouseProducts
                .where((p) => p.id == _productId)
                .toList();
            _selectedProduct = matches.isNotEmpty ? matches.first : null;
          } else if (_warehouseProducts.isNotEmpty) {
            _productId = _warehouseProducts.first.id;
            _selectedProduct = _warehouseProducts.first;
          }
        });
        return;
      }
      if (mounted) setState(() => _warehouseLoading = false);
    } catch (_) {
      if (mounted) setState(() => _warehouseLoading = false);
    }
  }

  Future<void> _loadSuppliers() async {
    try {
      final supplierPage = await ref
          .read(supplierRepositoryProvider)
          .getSuppliers(limit: 200);
      if (!mounted) return;
      setState(() => _suppliers = supplierPage.suppliers);
    } catch (_) {}
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _supplierSearchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(
      stockMutationControllerProvider.select((s) => s.loading),
    );
    final fallbackProducts =
        widget.products ??
        ref.watch(productListControllerProvider).data.value?.products ??
        const <Product>[];
    final products =
        (_warehouseProducts.isNotEmpty
                ? _warehouseProducts
                : (widget.products ?? fallbackProducts))
            .cast<Product>();

    return Scaffold(
      appBar: AppBar(title: const Text('Stock In → Warehouse')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warehouse_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _warehouseLoading
                            ? 'Loading warehouse stock…'
                            : 'Incoming stock lands at ${_warehouseName ?? 'the Warehouse'}. Use Stock Transfer to push it to branches.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _productId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Product',
                  prefixIcon: Icon(Icons.carpenter_outlined),
                ),
                items: products
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          '${p.name} (${_fmtNum(p.quantity.toDouble())} ${_unitFor(p.productType, variantCarpet: p.usesVariants)})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _productId = v;
                  final matches = products.where((p) => p.id == v).toList();
                  _selectedProduct = matches.isNotEmpty ? matches.first : null;
                  _payload = const _MovementPayload();
                }),
                validator: (v) => v == null ? 'Select a product' : null,
              ),
              if (_selectedProduct != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Current stock: ${_fmtNum(_selectedProduct!.quantity.toDouble())} ${_unitFor(_selectedProduct!.productType, variantCarpet: _selectedProduct!.usesVariants)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _StockInFields(
                  key: ValueKey(
                    'in-${_selectedProduct?.id ?? 'none'}-${_selectedProduct?.productType ?? ''}',
                  ),
                  productType: _selectedProduct?.productType ?? 'qaleen',
                  existingPieces:
                      _selectedProduct?.carpetPiecesData ?? const [],
                  hasLegacyRoll:
                      (_selectedProduct?.carpetWidth ?? 0) > 0 &&
                      (_selectedProduct?.carpetHeight ?? 0) > 0,
                  existingSizes: _selectedProduct?.qaleenSizes ?? const [],
                  usesVariants: _selectedProduct?.usesVariants ?? false,
                  onChanged: (p) => setState(() => _payload = p),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedSupplierId,
                      decoration: const InputDecoration(
                        labelText: 'Supplier',
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text(
                            'Select Supplier',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        ..._suppliers
                            .where(
                              (s) =>
                                  _supplierSearch.isEmpty ||
                                  s.name.toLowerCase().contains(
                                    _supplierSearch.toLowerCase(),
                                  ),
                            )
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(
                                  s.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        const DropdownMenuItem(
                          value: '___add_new___',
                          child: Row(
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                size: 20,
                                color: Colors.green,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Add New Supplier',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const DropdownMenuItem(
                          value: '___other___',
                          child: Text(
                            'Other (type manually)',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                      onChanged: (v) async {
                        if (v == '___add_new___') {
                          final added = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => const SupplierFormScreen(),
                            ),
                          );
                          if (added == true && mounted) {
                            await _loadSuppliers();
                            if (_suppliers.isNotEmpty) {
                              final latest = _suppliers.last;
                              setState(() {
                                _selectedSupplierId = latest.id;
                                _selectedSupplier = latest;
                              });
                            }
                          }
                          return;
                        }
                        setState(() {
                          _showSupplierSearch = false;
                          _supplierSearch = '';
                          _supplierSearchController.clear();
                          if (v == null || v.isEmpty) {
                            _selectedSupplierId = null;
                            _selectedSupplier = null;
                          } else if (v == '___other___') {
                            _selectedSupplierId = '___other___';
                            _selectedSupplier = null;
                          } else {
                            _selectedSupplierId = v;
                            _selectedSupplier = _suppliers.firstWhere(
                              (s) => s.id == v,
                            );
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showSupplierSearch = !_showSupplierSearch;
                        if (!_showSupplierSearch) {
                          _supplierSearch = '';
                          _supplierSearchController.clear();
                        }
                      });
                    },
                    icon: Icon(
                      _showSupplierSearch ? Icons.search_off : Icons.search,
                      color: _showSupplierSearch ? AppColors.primary : null,
                    ),
                    tooltip: 'Search suppliers',
                  ),
                ],
              ),
              if (_showSupplierSearch)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextFormField(
                    controller: _supplierSearchController,
                    decoration: const InputDecoration(
                      hintText: 'Type to filter suppliers…',
                      prefixIcon: Icon(Icons.filter_list),
                    ),
                    onChanged: (v) => setState(() => _supplierSearch = v),
                  ),
                ),
              if (_selectedSupplierId == '___other___')
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextFormField(
                    controller: _supplierController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier name',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              _MovementSummary(label: 'Total stock to add', payload: _payload),
              const SizedBox(height: 12),
              LoadingButton(
                loading: loading,
                label: 'Add Stock',
                icon: Icons.arrow_downward,
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (_selectedProduct == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Select a product first')),
                    );
                    return;
                  }
                  if (_payload.total <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Add a piece/size or enter a valid quantity',
                        ),
                      ),
                    );
                    return;
                  }
                  String supplierName = '';
                  if (_selectedSupplierId == '___other___') {
                    supplierName = _supplierController.text.trim();
                  } else if (_selectedSupplier != null) {
                    supplierName = _selectedSupplier!.name;
                  }
                  final ok = await ref
                      .read(stockMutationControllerProvider.notifier)
                      .stockIn(
                        productId: _productId!,
                        quantity: _payload.total.round(),
                        supplier: supplierName,
                        notes: _notesController.text.trim(),
                        carpetPieces: _payload.carpetPieces,
                        qaleenSizes: _payload.qaleenSizes,
                        variants: _payload.variants,
                        length: _payload.length,
                      );
                  if (!context.mounted) return;
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stock added successfully')),
                    );
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ref.read(stockMutationControllerProvider).error ??
                              'Stock in failed',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementSummary extends StatelessWidget {
  const _MovementSummary({required this.label, required this.payload});

  final String label;
  final _MovementPayload payload;

  @override
  Widget build(BuildContext context) {
    String detail = '';
    if (payload.carpetPieces.isNotEmpty) {
      final dims = payload.carpetPieces
          .map(
            (p) =>
                '${_fmtNum((p['width'] as num).toDouble())}x${_fmtNum((p['height'] as num).toDouble())}',
          )
          .join(', ');
      detail =
          '${payload.carpetPieces.length} piece${payload.carpetPieces.length == 1 ? '' : 's'} ($dims)';
    } else if (payload.qaleenSizes.isNotEmpty) {
      detail = payload.qaleenSizes
          .map(
            (s) =>
                '${_fmtNum((s['width'] as num).toDouble())}x${_fmtNum((s['height'] as num).toDouble())} (${s['pieces']} pcs)',
          )
          .join(', ');
    } else if (payload.total > 0) {
      detail = 'gross quantity';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label\n$detail',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
          Text(
            _fmtNum(payload.total.toDouble()),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class StockOutScreen extends ConsumerStatefulWidget {
  const StockOutScreen({super.key, this.products});

  final List<dynamic>? products;

  @override
  ConsumerState<StockOutScreen> createState() => _StockOutScreenState();
}

class _StockOutScreenState extends ConsumerState<StockOutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  String? _productId;
  Product? _selectedProduct;
  _MovementPayload _payload = const _MovementPayload();

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<CarpetPieceData> get _pieces {
    final p = _selectedProduct;
    if (p == null) return const [];
    if (p.carpetPiecesData.isNotEmpty) return p.carpetPiecesData;
    if (p.carpetWidth > 0 && p.carpetHeight > 0) {
      return [
        CarpetPieceData(
          width: p.carpetWidth,
          height: p.carpetHeight,
          area: p.carpetWidth * p.carpetHeight,
        ),
      ];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(
      stockMutationControllerProvider.select((s) => s.loading),
    );
    final products =
        (widget.products ??
                ref.watch(productListControllerProvider).data.value?.products ??
                const <Product>[])
            .cast<Product>();

    return Scaffold(
      appBar: AppBar(title: const Text('Stock Out')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _productId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Product',
                  prefixIcon: Icon(Icons.carpenter_outlined),
                ),
                items: products
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          '${p.name} (${_fmtNum(p.quantity.toDouble())} ${_unitFor(p.productType, variantCarpet: p.usesVariants)})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _productId = v;
                  final matches = products.where((p) => p.id == v).toList();
                  _selectedProduct = matches.isNotEmpty ? matches.first : null;
                  _payload = const _MovementPayload();
                }),
                validator: (v) => v == null ? 'Select a product' : null,
              ),
              if (_selectedProduct != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Current stock: ${_fmtNum(_selectedProduct!.quantity.toDouble())} ${_unitFor(_selectedProduct!.productType, variantCarpet: _selectedProduct!.usesVariants)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _StockOutFields(
                  key: ValueKey(
                    'out-${_selectedProduct?.id ?? 'none'}-${_selectedProduct?.productType ?? ''}',
                  ),
                  productType: _selectedProduct?.productType ?? 'qaleen',
                  pieces: _pieces,
                  sizes: _selectedProduct?.qaleenSizes ?? const [],
                  meterLength: _selectedProduct?.meterLength ?? 0,
                  variants: _selectedProduct?.variants ?? const [],
                  usesVariants: _selectedProduct?.usesVariants ?? false,
                  onChanged: (p) => setState(() => _payload = p),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (e.g. damaged, sample)',
                  prefixIcon: Icon(Icons.info_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              _MovementSummary(
                label: 'Total stock to remove',
                payload: _payload,
              ),
              const SizedBox(height: 12),
              LoadingButton(
                loading: loading,
                label: 'Remove Stock',
                icon: Icons.arrow_upward,
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (_selectedProduct == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Select a product first')),
                    );
                    return;
                  }
                  if (_payload.total <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Select pieces/sizes or enter a valid quantity',
                        ),
                      ),
                    );
                    return;
                  }
                  final ok = await ref
                      .read(stockMutationControllerProvider.notifier)
                      .stockOut(
                        productId: _productId!,
                        quantity: _payload.total.round(),
                        reason: _reasonController.text.trim(),
                        notes: _notesController.text.trim(),
                        carpetPieces: _payload.carpetPieces,
                        qaleenSizes: _payload.qaleenSizes,
                        variants: _payload.variants,
                        length: _payload.length,
                      );
                  if (!context.mounted) return;
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Stock removed successfully'),
                      ),
                    );
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ref.read(stockMutationControllerProvider).error ??
                              'Stock out failed',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LowStockScreen extends ConsumerWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productListControllerProvider.select((s) => s));
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Low Stock Alerts')),
      body: state.data.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString()),
        data: (page) {
          final low = page.products.where((p) => p.isLowStock).toList();
          if (low.isEmpty) {
            return const Center(child: Text('All products are well stocked'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: low.length,
            itemBuilder: (context, i) {
              final p = low[i];
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.warning_amber,
                    color: AppColors.danger,
                  ),
                  title: Text(p.name),
                  subtitle: Text(
                    'Only ${_fmtNum(p.quantity.toDouble())} ${_unitFor(p.productType)} left (threshold ${p.lowStockThreshold})',
                  ),
                  trailing: isAdmin
                      ? null
                      : TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StockInScreen(productId: p.id),
                            ),
                          ),
                          child: const Text('Restock'),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class StockTransferScreen extends ConsumerStatefulWidget {
  const StockTransferScreen({super.key});

  @override
  ConsumerState<StockTransferScreen> createState() =>
      _StockTransferScreenState();
}

class _StockTransferScreenState extends ConsumerState<StockTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  String? _fromShopId;
  String? _toShopId;
  String? _productId;
  _TransferProduct? _selectedProduct;
  _MovementPayload _payload = const _MovementPayload();
  List<TransferShopMeta> _shops = const [];
  List<_TransferProduct> _products = const [];
  bool _shopsLoading = true;
  bool _productsLoading = false;
  String? _shopsError;
  String? _productsError;

  @override
  void initState() {
    super.initState();
    _fromShopId = ref.read(currentUserProvider)?.assignedShopId;
    _loadShops();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  List<TransferShopMeta> _allowedDestinations(String? fromId) {
    TransferShopMeta? from;
    for (final s in _shops) {
      if (s.id == fromId) {
        from = s;
        break;
      }
    }
    if (from == null) return const [];
    final fromMeta = from;
    return _shops
        .where((s) => s.id != fromId && s.isWarehouse != fromMeta.isWarehouse)
        .toList();
  }

  Future<void> _loadShops() async {
    setState(() {
      _shopsLoading = true;
      _shopsError = null;
    });
    try {
      final raw = await ref.read(inventoryRepositoryProvider).transferShops();
      final shops = raw.map(TransferShopMeta.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _shops = shops;
        _shopsLoading = false;
        TransferShopMeta? warehouse;
        for (final s in shops) {
          if (s.isWarehouse) {
            warehouse = s;
            break;
          }
        }
        if (warehouse != null &&
            ref.read(currentUserProvider)?.isWarehouseManager != true) {
          _fromShopId = warehouse.id;
        } else if (_fromShopId == null && shops.isNotEmpty) {
          _fromShopId = shops.first.id;
        }
      });
      await _loadProducts();
    } catch (e) {
      if (mounted) {
        setState(() {
          _shopsLoading = false;
          _shopsError = e.toString();
        });
      }
    }
  }

  Future<void> _loadProducts() async {
    final shopId = _fromShopId;
    if (shopId == null) {
      setState(() {
        _products = const [];
        _productsLoading = false;
        _productId = null;
        _selectedProduct = null;
      });
      return;
    }
    setState(() {
      _productsLoading = true;
      _productsError = null;
      _products = const [];
      _productId = null;
      _selectedProduct = null;
    });
    try {
      final user = ref.read(currentUserProvider);
      // Managers can only fetch their own shop through /products, so when the
      // source is a different branch (pull stock into my shop) fall back to the
      // shop-products endpoint that scopes by the requested shop. Everyone else
      // (admin on any shop, manager on their own shop) gets the full product
      // list so the dimension selectors work exactly like Stock In / Stock Out.
      final fromOtherMine =
          !(user?.isAdmin ?? false) && shopId != user?.assignedShopId;
      final List<_TransferProduct> parsed;
      if (fromOtherMine) {
        final raw = await ref
            .read(inventoryRepositoryProvider)
            .shopProducts(shopId);
        parsed = raw
            .where((p) => ((p['quantity'] as num?)?.toInt() ?? 0) > 0)
            .map(_parseTransferProduct)
            .toList();
      } else {
        final page = await ref
            .read(productRepositoryProvider)
            .getProducts(shopId: shopId, limit: 500);
        parsed = page.products
            .where((p) => p.quantity > 0)
            .map(_transferFromProduct)
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _products = parsed;
        _productsLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _productsLoading = false;
          _productsError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(
      stockMutationControllerProvider.select((s) => s.loading),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Stock Transfer')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_shopsLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_shopsError != null)
                ErrorView(
                  message: _shopsError!,
                  onRetry: _loadShops,
                  compact: true,
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _fromShopId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Transfer From',
                    prefixIcon: Icon(Icons.outbox_outlined),
                  ),
                  items: _shops
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: _ShopBadgeLabel(shop: s),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    setState(() {
                      _fromShopId = v;
                      final allowed = _allowedDestinations(v);
                      _toShopId = allowed.isEmpty ? null : allowed.first.id;
                      _productId = null;
                      _selectedProduct = null;
                      _payload = const _MovementPayload();
                    });
                    await _loadProducts();
                  },
                  validator: (v) => v == null ? 'Select a source shop' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _toShopId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Transfer To',
                    prefixIcon: Icon(Icons.inbox_outlined),
                  ),
                  items: _allowedDestinations(_fromShopId)
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: _ShopBadgeLabel(shop: s),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _toShopId = v),
                  validator: (v) =>
                      v == null ? 'Select a destination shop' : null,
                ),
                const SizedBox(height: 14),
                if (_productsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_productsError != null)
                  ErrorView(
                    message: _productsError!,
                    onRetry: _loadProducts,
                    compact: true,
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _productId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Product',
                      prefixIcon: Icon(Icons.carpenter_outlined),
                    ),
                    items: _products
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              '${p.name} (${_fmtNum(p.quantity.toDouble())} ${_unitFor(p.productType, variantCarpet: p.usesVariants)})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _productId = v;
                      final matches = _products
                          .where((p) => p.id == v)
                          .toList();
                      _selectedProduct = matches.isNotEmpty
                          ? matches.first
                          : null;
                      _payload = const _MovementPayload();
                    }),
                    validator: (v) =>
                        v == null ? 'Select a product to transfer' : null,
                  ),
              ],
              if (_selectedProduct != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _StockOutFields(
                    key: ValueKey(
                      'xf-${_selectedProduct!.id}-${_selectedProduct!.productType}',
                    ),
                    productType: _selectedProduct!.productType,
                    pieces: _selectedProduct!.pieces,
                    sizes: _selectedProduct!.sizes,
                    meterLength: _selectedProduct!.meterLength,
                    variants: _selectedProduct!.variants,
                    usesVariants: _selectedProduct!.usesVariants,
                    onChanged: (p) => setState(() => _payload = p),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              _MovementSummary(
                label: 'Total stock to transfer',
                payload: _payload,
              ),
              const SizedBox(height: 12),
              LoadingButton(
                loading: loading,
                label: 'Transfer Stock',
                icon: Icons.swap_horiz_rounded,
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (_selectedProduct == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Select a product to transfer'),
                      ),
                    );
                    return;
                  }
                  if (_payload.total <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Select pieces/sizes or enter a valid quantity',
                        ),
                      ),
                    );
                    return;
                  }
                  final ok = await ref
                      .read(stockMutationControllerProvider.notifier)
                      .transfer(
                        fromShopId: _fromShopId!,
                        toShopId: _toShopId!,
                        productId: _selectedProduct!.id,
                        quantity: _payload.total.round(),
                        notes: _notesController.text.trim(),
                        carpetPieces: _payload.carpetPieces,
                        qaleenSizes: _payload.qaleenSizes,
                        variants: _payload.variants,
                        length: _payload.length,
                      );
                  if (!context.mounted) return;
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Stock transferred successfully'),
                      ),
                    );
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ref.read(stockMutationControllerProvider).error ??
                              'Stock transfer failed',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
