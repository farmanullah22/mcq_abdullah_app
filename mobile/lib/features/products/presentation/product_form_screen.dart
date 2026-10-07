import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/status_views.dart';
import '../../inventory/presentation/stock_screens.dart';
import '../../products/models/product.dart';
import '../providers/product_providers.dart';

/// Every product type shows only the fields that matter for it, so the manager
/// is never asked for something that does not apply to the chosen type.
class _TypeSpec {
  const _TypeSpec({
    required this.value,
    required this.label,
    required this.icon,
    required this.codeLabel,
    required this.codeIcon,
    required this.showName,
    required this.showFoamType,
    required this.showPicture,
    required this.colorRows,
    required this.blurb,
  });

  final String value;
  final String label;
  final IconData icon;

  /// Design Number / Design Code / Code are the same stored field, only the
  /// wording changes per type.
  final String codeLabel;
  final IconData codeIcon;

  /// Carpets are named by the manager, every other type is named after itself.
  final bool showName;
  final bool showFoamType;
  final bool showPicture;

  /// True when stock is split over one row per colour, false when the product
  /// carries a single plain quantity.
  final bool colorRows;

  final String blurb;
}

const _typeSpecs = <String, _TypeSpec>{
  'foam': _TypeSpec(
    value: 'foam',
    label: 'Foam',
    icon: Icons.weekend_outlined,
    codeLabel: 'Code',
    codeIcon: Icons.tag,
    showName: false,
    showFoamType: true,
    showPicture: true,
    colorRows: false,
    blurb: 'Foam is stocked as one quantity. Name it with the code you use in the factory.',
  ),
  'foam_cover': _TypeSpec(
    value: 'foam_cover',
    label: 'Foam Cover',
    icon: Icons.bedroom_parent_outlined,
    codeLabel: 'Design Number',
    codeIcon: Icons.tag,
    showName: false,
    showFoamType: false,
    showPicture: true,
    colorRows: true,
    blurb: 'Add a row per colour you keep in stock. The quantities add up to the total stock.',
  ),
  'pillow_cover': _TypeSpec(
    value: 'pillow_cover',
    label: 'Pillow Cover',
    icon: Icons.king_bed_outlined,
    codeLabel: 'Design Code',
    codeIcon: Icons.tag,
    showName: false,
    showFoamType: false,
    showPicture: true,
    colorRows: true,
    blurb: 'Add a row per colour you keep in stock. The quantities add up to the total stock.',
  ),
  'carpet': _TypeSpec(
    value: 'carpet',
    label: 'Carpet',
    icon: Icons.grid_on,
    codeLabel: 'Code',
    codeIcon: Icons.tag,
    showName: true,
    showFoamType: false,
    showPicture: true,
    colorRows: true,
    blurb: 'Add a row per colour you keep in stock. The quantities add up to the total stock.',
  ),
};

// Older catalog entries keep their own type so editing them never silently
// converts them into one of the four new products. They keep the original
// colour x size grid because that is how their stock was recorded.
const _legacyTypeLabels = <String, ({String label, IconData icon})>{
  'qaleen': (label: 'Qaleen', icon: Icons.inventory_2_outlined),
  'meter': (label: 'Meter', icon: Icons.straighten),
  'pillow': (label: 'Pillow', icon: Icons.king_bed_outlined),
};

class _VariantDraft {
  _VariantDraft({String color = '', String size = '', int quantity = 0}) {
    colorCtrl = TextEditingController(text: color);
    sizeCtrl = TextEditingController(text: size);
    qtyCtrl = TextEditingController(text: quantity > 0 ? '$quantity' : '');
  }

  late final TextEditingController colorCtrl;
  late final TextEditingController sizeCtrl;
  late final TextEditingController qtyCtrl;

  String get color => colorCtrl.text.trim();
  String get size => sizeCtrl.text.trim();
  int get quantity => int.tryParse(qtyCtrl.text.trim()) ?? 0;

  String get key => '${color.toLowerCase()}|${size.toLowerCase()}';

  Map<String, dynamic> toJson() => {'color': color, 'size': size, 'quantity': quantity};

  void dispose() {
    colorCtrl.dispose();
    sizeCtrl.dispose();
    qtyCtrl.dispose();
  }
}

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _costPrice;
  late final TextEditingController _quantity;
  late final TextEditingController _foamType;
  final List<_VariantDraft> _variants = [];

  late String _productType;
  Uint8List? _productImageBytes;
  bool _imageRemoved = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _isEdit = p != null;
    final existingType = p?.productType ?? '';
    _productType = existingType.isEmpty ? 'foam' : existingType;

    _name = TextEditingController(text: p?.name ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _costPrice = TextEditingController(text: p != null && p.costPrice > 0 ? _fmt(p.costPrice) : '');
    _quantity = TextEditingController(text: p != null && p.quantity > 0 ? '${p.quantity}' : '');
    _foamType = TextEditingController(text: p?.foamType ?? '');

    for (final v in p?.variants ?? const <ProductVariant>[]) {
      _variants.add(_VariantDraft(color: v.color, size: v.size, quantity: v.quantity));
    }

    final existingImage = (p?.images.isNotEmpty ?? false) ? p!.images.first : '';
    if (existingImage.startsWith('data:image')) {
      try {
        _productImageBytes = base64.decode(existingImage.split(',').last);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _costPrice.dispose();
    _quantity.dispose();
    _foamType.dispose();
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  double _toDouble(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  int get _variantTotal => _variants.fold(0, (sum, v) => sum + v.quantity);

  /// Null while an old catalog entry is open for editing, which keeps the old
  /// colour x size layout instead of one of the four new field sets.
  _TypeSpec? get _spec => _typeSpecs[_productType];

  bool get _usesColorRows => _spec?.colorRows ?? true;

  List<({String value, String label, IconData icon})> get _availableTypes {
    final options = _typeSpecs.values
        .map((s) => (value: s.value, label: s.label, icon: s.icon))
        .toList();
    final legacy = _legacyTypeLabels[_productType];
    if (legacy != null) {
      options.add((value: _productType, label: '${legacy.label} (old)', icon: legacy.icon));
    }
    return options;
  }

  /// Only Foam, Foam Cover, Pillow Cover and Carpet can be created here. Older
  /// catalog entries are still editable but cannot be added from this screen.
  bool get _canCreate => _typeSpecs.containsKey(_productType);

  /// Foam, Foam Cover and Pillow Cover are named after their type plus the code,
  /// because the manager does not type a separate product name. Carpets keep the
  /// name the manager types, and old catalog entries keep the name they have.
  String _resolveName() {
    final spec = _spec;
    if (spec == null || spec.showName) return _name.text.trim();
    final code = _sku.text.trim();
    return code.isEmpty ? spec.label : '${spec.label} / $code';
  }

  String _buildImageDataUrl(Uint8List bytes) {
    final ext = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50 ? 'png' : 'jpeg';
    return 'data:image/$ext;base64,${base64.encode(bytes)}';
  }

  Future<void> _pickProductImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await _imagePicker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _productImageBytes = bytes;
      _imageRemoved = false;
    });
  }

  void _addVariant() {
    final draft = _VariantDraft();
    draft.colorCtrl.addListener(_refresh);
    draft.sizeCtrl.addListener(_refresh);
    draft.qtyCtrl.addListener(_refresh);
    setState(() => _variants.add(draft));
  }

  void _removeVariant(int index) {
    final draft = _variants.removeAt(index);
    draft.dispose();
    setState(() {});
  }

  void _refresh() => setState(() {});

  String? _validateVariants() {
    if (_variants.isEmpty) return 'Add at least one colour row with its quantity';
    final seen = <String>{};
    for (final v in _variants) {
      if (_usesColorRows && v.color.isEmpty) return 'Every row needs a colour';
      if (!_usesColorRows && v.color.isEmpty && v.size.isEmpty) return 'Every row needs a colour or a size';
      if (v.quantity <= 0) return 'Enter a quantity for every row';
      if (!seen.add(v.key)) return 'The colour "${v.color}" is listed twice';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isEdit && !_canCreate) {
      await _submitLegacy();
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final spec = _spec!;

    if (spec.colorRows) {
      final variantError = _validateVariants();
      if (variantError != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(variantError)));
        return;
      }
    }

    final notifier = ref.read(productMutationControllerProvider.notifier);
    final data = <String, dynamic>{
      'name': _resolveName(),
      'sku': _sku.text.trim(),
      'productType': _productType,
      'costPrice': _toDouble(_costPrice),
      'variants': <Map<String, dynamic>>[],
    };

    if (spec.showFoamType) {
      data['foamType'] = _foamType.text.trim();
      data['quantity'] = int.tryParse(_quantity.text.trim()) ?? 0;
    }
    if (spec.colorRows) {
      data['variants'] = _variants.map((v) => v.toJson()).toList();
    }
    if (_productType == 'carpet') {
      data['costPerSqft'] = data['costPrice'];
    }

    if (spec.showPicture) {
      if (_productImageBytes != null) {
        data['images'] = [_buildImageDataUrl(_productImageBytes!)];
      } else if (_imageRemoved) {
        data['images'] = <String>[];
      } else if (_isEdit && widget.product!.images.isNotEmpty) {
        data['images'] = widget.product!.images;
      }
    }

    await _save(notifier, data);
  }

  Future<void> _submitLegacy() async {
    if (!_formKey.currentState!.validate()) return;
    final variantError = _validateVariants();
    if (variantError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(variantError)));
      return;
    }

    final notifier = ref.read(productMutationControllerProvider.notifier);
    final data = <String, dynamic>{
      'name': _name.text.trim(),
      'sku': _sku.text.trim(),
      'productType': _productType,
      'costPrice': _toDouble(_costPrice),
      'variants': _variants.map((v) => v.toJson()).toList(),
    };

    if (_productImageBytes != null) {
      data['images'] = [_buildImageDataUrl(_productImageBytes!)];
    } else if (_imageRemoved) {
      data['images'] = <String>[];
    } else if (widget.product!.images.isNotEmpty) {
      data['images'] = widget.product!.images;
    }

    await _save(notifier, data);
  }

  Future<void> _save(ProductMutationController notifier, Map<String, dynamic> data) async {
    final ok = _isEdit
        ? await notifier.update(widget.product!.id, data)
        : await notifier.create(data);

    if (!mounted) return;
    if (ok) {
      if (_isEdit) {
        Navigator.of(context).pop();
      } else {
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        final newId = ref.read(productMutationControllerProvider).product?.id;
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Product saved at the Warehouse'),
            action: newId == null
                ? null
                : SnackBarAction(
                    label: 'Stock In →',
                    onPressed: () => navigator.push(
                      MaterialPageRoute(builder: (_) => StockInScreen(productId: newId)),
                    ),
                  ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(productMutationControllerProvider).error ?? 'Failed to save product')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(productMutationControllerProvider.select((s) => s.loading));
    final spec = _spec;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Product' : 'Add Product')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_isEdit)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warehouse_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'New products are created at the Warehouse. Add more quantity via Stock In, then transfer to a branch.',
                          style: const TextStyle(fontSize: 12, color: AppColors.primary, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),

              DropdownButtonFormField<String>(
                initialValue: _productType,
                decoration: const InputDecoration(
                  labelText: 'Product Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _availableTypes
                    .map((o) => DropdownMenuItem(
                          value: o.value,
                          child: Row(
                            children: [
                              Icon(o.icon, size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Text(o.label),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _productType = v);
                },
              ),
              const SizedBox(height: 14),

              if (spec == null) ...[
                TextFormField(
                  controller: _name,
                  validator: (v) => Validators.required(v),
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    prefixIcon: Icon(Icons.carpenter_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _sku,
                  decoration: const InputDecoration(
                    labelText: 'Product Code / SKU (optional)',
                    prefixIcon: Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: 14),
                _buildProductImagePicker(),
                const SizedBox(height: 14),
              ] else ...[
                if (spec.showName) ...[
                  TextFormField(
                    controller: _name,
                    validator: (v) => Validators.required(v),
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.carpenter_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (spec.showFoamType) ...[
                  TextFormField(
                    controller: _foamType,
                    validator: (v) => Validators.required(v),
                    decoration: const InputDecoration(
                      labelText: 'Foam Type',
                      prefixIcon: Icon(Icons.texture_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _sku,
                  decoration: InputDecoration(
                    labelText: '${spec.codeLabel} (optional)',
                    prefixIcon: Icon(spec.codeIcon),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    spec.blurb,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.35),
                  ),
                ),
                const SizedBox(height: 14),
                if (spec.showPicture) ...[
                  _buildProductImagePicker(),
                  const SizedBox(height: 14),
                ],
                if (spec.colorRows)
                  _buildColorSection()
                else
                  _buildPlainQuantitySection(),
                const SizedBox(height: 14),
              ],

              _SectionCard(
                title: 'Cost Price',
                subtitle: _productType == 'carpet'
                    ? 'One cost per sqft. Selling price is typed when the sale is recorded.'
                    : 'One cost per piece. Selling price is typed when the sale is recorded.',
                children: [
                  _NumField(
                    controller: _costPrice,
                    label: _productType == 'carpet' ? 'Cost / sqft (Rs.)' : 'Cost / piece (Rs.)',
                    icon: Icons.attach_money,
                    prefix: 'Rs. ',
                    validatorText: 'Enter the cost price',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              LoadingButton(
                loading: loading,
                label: _isEdit ? 'Update Product' : 'Add Product',
                icon: _isEdit ? Icons.save_outlined : Icons.add,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlainQuantitySection() {
    return _SectionCard(
      title: 'Quantity',
      subtitle: 'How many pieces are in stock at the warehouse',
      children: [
        TextFormField(
          controller: _quantity,
          keyboardType: TextInputType.number,
          validator: (v) {
            final value = int.tryParse((v ?? '').trim());
            if (value == null || value <= 0) return 'Enter the quantity in stock';
            return null;
          },
          decoration: const InputDecoration(
            labelText: 'Quantity',
            prefixIcon: Icon(Icons.inventory_2_outlined),
            suffixText: 'pcs',
          ),
        ),
      ],
    );
  }

  Widget _buildColorSection() {
    return _SectionCard(
      title: 'Colours & Quantity',
      subtitle: 'One row per colour you keep in stock',
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(child: Text('Colour', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
              SizedBox(width: 8),
              SizedBox(width: 72, child: Text('Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
              SizedBox(width: 36),
            ],
          ),
        ),
        if (_variants.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'No rows yet. Add every colour, then type how many pieces you have.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          )
        else
          ...List.generate(_variants.length, (i) {
            final v = _variants[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: v.colorCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. Red', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: v.qtyCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(hintText: '0', isDense: true),
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
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                'Total in stock: $_variantTotal pcs',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
            TextButton.icon(
              onPressed: _addVariant,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Colour'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductImagePicker() {
    return Row(
      children: [
        GestureDetector(
          onTap: _pickProductImage,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: _productImageBytes != null
                ? Image.memory(_productImageBytes!, fit: BoxFit.cover, width: 84, height: 84)
                : const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 30),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Picture', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Shown on the dashboard product card',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              if (_productImageBytes != null)
                TextButton(
                  onPressed: () => setState(() {
                    _productImageBytes = null;
                    _imageRemoved = true;
                  }),
                  child: const Text('Remove image'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({
    required this.controller,
    required this.label,
    required this.icon,
    this.prefix,
    this.validatorText,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? prefix;
  final String? validatorText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: validatorText == null
          ? null
          : (v) {
              final value = double.tryParse((v ?? '').trim());
              if (value == null || value <= 0) return validatorText;
              return null;
            },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        prefixText: prefix,
        border: const OutlineInputBorder(),
      ),
    );
  }
}