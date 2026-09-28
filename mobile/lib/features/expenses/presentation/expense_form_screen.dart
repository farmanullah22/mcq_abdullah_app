import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../providers/expense_providers.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  String? _category = 'other';
  DateTime? _expenseDate;
  String? _shopId;

  @override
  void initState() {
    super.initState();
    _expenseDate = DateTime.now();
    _dateController.text = Formatters.date(_expenseDate!);
    _shopId = ref.read(dashboardControllerProvider).selectedShopId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _expenseDate = picked;
        _dateController.text = Formatters.date(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(expenseMutationControllerProvider.select((s) => s.loading));
    final dashboard = ref.watch(dashboardControllerProvider);
    final canSelectShop = (ref.watch(currentUserProvider)?.isAdmin ?? false) && dashboard.shops.length > 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                items: AppConstants.expenseCategories
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(AppConstants.expenseCategoryLabels[c] ?? Formatters.title(c)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final e = Validators.positiveNumber(v);
                  if (e != null) return e;
                  if (num.tryParse(v!.trim()) == 0) return 'Amount must be greater than 0';
                  return null;
                },
                decoration: const InputDecoration(labelText: 'Amount (Rs.)', prefixIcon: Icon(Icons.payments_outlined)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: _pickDate,
                decoration: const InputDecoration(
                  labelText: 'Expense Date',
                  prefixIcon: Icon(Icons.event_outlined),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
              ),
              if (canSelectShop) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _shopId,
                  decoration: const InputDecoration(labelText: 'Shop', prefixIcon: Icon(Icons.storefront_outlined)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All shops / main')),
                    ...dashboard.shops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                  ],
                  onChanged: (v) => setState(() => _shopId = v),
                ),
              ],
              const SizedBox(height: 24),
              LoadingButton(
                loading: loading,
                label: 'Save Expense',
                icon: Icons.check,
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final ok = await ref.read(expenseMutationControllerProvider.notifier).create(
                        category: _category!,
                        amount: double.parse(_amountController.text.trim()),
                        expenseDate: _expenseDate,
                        description: _descriptionController.text.trim(),
                        shopId: _shopId,
                      );
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ref.read(expenseMutationControllerProvider).error ?? 'Failed to save expense')),
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
