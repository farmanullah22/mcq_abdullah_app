import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/status_views.dart';
import '../models/supplier.dart';
import '../providers/supplier_providers.dart';

class SupplierFormScreen extends ConsumerStatefulWidget {
  const SupplierFormScreen({super.key, this.supplier});

  final Supplier? supplier;

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _notes;
  late final TextEditingController _balance;

  bool get _isEdit => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _name = TextEditingController(text: s?.name ?? '');
    _phone = TextEditingController(text: s?.phone ?? '');
    _email = TextEditingController(text: s?.email ?? '');
    _address = TextEditingController(text: s?.address ?? '');
    _city = TextEditingController(text: s?.city ?? '');
    _notes = TextEditingController(text: s?.notes ?? '');
    _balance = TextEditingController(text: _isEdit ? '' : '0');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _city.dispose();
    _notes.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (ref.read(supplierMutationControllerProvider).loading) return;

    final s = widget.supplier;
    final ok = s == null
        ? await ref.read(supplierMutationControllerProvider.notifier).create(
              name: _name.text.trim(),
              phone: _phone.text.trim(),
              email: _email.text.trim(),
              address: _address.text.trim(),
              city: _city.text.trim(),
              notes: _notes.text.trim(),
              balance: double.tryParse(_balance.text.trim()) ?? 0,
            )
        : await ref.read(supplierMutationControllerProvider.notifier).update(s.id, {
              'name': _name.text.trim(),
              'phone': _phone.text.trim(),
              'email': _email.text.trim(),
              'address': _address.text.trim(),
              'city': _city.text.trim(),
              'notes': _notes.text.trim(),
            });
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s == null ? 'Supplier added successfully' : 'Supplier updated')),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(supplierMutationControllerProvider).error ?? 'Something went wrong')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(supplierMutationControllerProvider.select((s) => s.loading));
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Supplier' : 'Add Supplier')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                validator: (v) => Validators.required(v, 'Supplier name is required'),
                decoration: const InputDecoration(
                  labelText: 'Supplier Name *',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(
                  labelText: 'City',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _balance,
                  keyboardType: TextInputType.number,
                  validator: (v) => Validators.positiveNumber(v),
                  decoration: const InputDecoration(
                    labelText: 'Opening Due Amount',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              LoadingButton(
                loading: loading,
                label: _isEdit ? 'Save Changes' : 'Add Supplier',
                icon: _isEdit ? Icons.save_outlined : Icons.add_business_outlined,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
