import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_views.dart';
import '../models/supplier.dart';
import '../providers/supplier_providers.dart';
import 'supplier_form_screen.dart';

class SupplierDetailScreen extends ConsumerStatefulWidget {
  const SupplierDetailScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  ConsumerState<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends ConsumerState<SupplierDetailScreen> {
  Supplier? _supplier;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supplier = await ref.read(supplierRepositoryProvider).getSupplier(widget.supplierId);
      if (mounted) setState(() => _supplier = supplier);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SupplierFormScreen(supplier: _supplier)),
    );
    if (edited == true) _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.business_outlined, color: AppColors.danger, size: 32),
        title: const Text('Delete supplier?'),
        content: Text('Remove "${_supplier!.name}" from your suppliers.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref.read(supplierMutationControllerProvider.notifier).delete(widget.supplierId);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(supplierMutationControllerProvider).error ?? 'Delete failed')),
      );
    }
  }

  Future<void> _adjustBalance(String type) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'payment' ? 'Make Payment' : 'Add Due Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'Rs. ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: const Color(0xFF17151C)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(type == 'payment' ? 'Make Payment' : 'Add Due'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    final success = await ref.read(supplierMutationControllerProvider.notifier).adjustBalance(
          widget.supplierId,
          amount: amount,
          type: type,
          note: noteController.text.trim(),
        );
    if (!mounted) return;
    if (success) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(supplierMutationControllerProvider).error ?? 'Action failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Details'),
        actions: [
          if (_supplier != null)
            IconButton(
              tooltip: 'Edit',
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
          if (_supplier != null)
            IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error.toString(), onRetry: _load)
              : _buildContent(context, _supplier!),
    );
  }

  Widget _buildContent(BuildContext context, Supplier s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    size: 32,
                    color: AppColors.goldDark,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  s.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                if (s.phone.isNotEmpty)
                  Text(s.phone, style: TextStyle(fontSize: 13, color: secondary)),
                if (s.shopName != null && s.shopName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      s.shopName!,
                      style: TextStyle(fontSize: 12, color: AppColors.goldDark, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _DueCard(supplier: s, onPayment: () => _adjustBalance('payment'), onAddDue: () => _adjustBalance('charge')),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Contact & Address',
            icon: Icons.contact_page_outlined,
            children: [
              _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: s.phone.isEmpty ? '—' : s.phone),
              _InfoRow(icon: Icons.email_outlined, label: 'Email', value: s.email.isEmpty ? '—' : s.email),
              _InfoRow(icon: Icons.location_on_outlined, label: 'Address', value: s.address.isEmpty ? '—' : s.address),
              _InfoRow(icon: Icons.location_city_outlined, label: 'City', value: s.city.isEmpty ? '—' : s.city),
              _InfoRow(icon: Icons.notes_outlined, label: 'Notes', value: s.notes.isEmpty ? '—' : s.notes),
              _InfoRow(icon: Icons.calendar_today_outlined, label: 'Added On', value: Formatters.date(s.createdAt)),
            ],
          ),
          if (s.transactions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Due History',
              icon: Icons.account_balance_wallet_outlined,
              children: [
                for (final t in s.transactions.reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: (t.isPayment ? AppColors.success : AppColors.danger).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            t.isPayment ? Icons.south_west : Icons.north_east,
                            size: 18,
                            color: t.isPayment ? AppColors.success : AppColors.danger,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.note.isEmpty ? (t.isPayment ? 'Payment made' : 'Due added') : t.note,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                Formatters.dateTime(t.date),
                                style: TextStyle(fontSize: 11.5, color: secondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${t.isPayment ? '-' : '+'}${Formatters.currency(t.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: t.isPayment ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DueCard extends StatelessWidget {
  const _DueCard({required this.supplier, required this.onPayment, required this.onAddDue});

  final Supplier supplier;
  final VoidCallback onPayment;
  final VoidCallback onAddDue;

  @override
  Widget build(BuildContext context) {
    final hasDue = supplier.hasDue;
    final color = hasDue ? AppColors.danger : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                'Outstanding Balance',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.currency(supplier.balance),
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPayment,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: BorderSide(color: AppColors.success.withValues(alpha: 0.6)),
                  ),
                  icon: const Icon(Icons.south_west, size: 16),
                  label: const Text('Make Payment'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddDue,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.6)),
                  ),
                  icon: const Icon(Icons.north_east, size: 16),
                  label: const Text('Add Due'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.goldDark),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.goldDark),
          const SizedBox(width: 10),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
