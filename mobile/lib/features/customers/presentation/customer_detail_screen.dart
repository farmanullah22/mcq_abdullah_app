import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_views.dart';
import '../models/customer.dart';
import '../providers/customer_providers.dart';
import 'customer_form_screen.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  Customer? _customer;
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
      final customer = await ref.read(customerRepositoryProvider).getCustomer(widget.customerId);
      if (mounted) setState(() => _customer = customer);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CustomerFormScreen(customer: _customer)),
    );
    if (edited == true) _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.person_off_outlined, color: AppColors.danger, size: 32),
        title: const Text('Delete customer?'),
        content: Text('Remove "${_customer!.name}" from your customers.'),
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
    final ok = await ref.read(customerMutationControllerProvider.notifier).delete(widget.customerId);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(customerMutationControllerProvider).error ?? 'Delete failed')),
      );
    }
  }

  Future<void> _adjustBalance(String type) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'payment' ? 'Record Payment' : 'Add Due Amount'),
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
            child: Text(type == 'payment' ? 'Receive Payment' : 'Add Due'),
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
    final success = await ref.read(customerMutationControllerProvider.notifier).adjustBalance(
          widget.customerId,
          amount: amount,
          type: type,
          note: noteController.text.trim(),
        );
    if (!mounted) return;
    if (success) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(customerMutationControllerProvider).error ?? 'Action failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        actions: [
          if (_customer != null)
            IconButton(
              tooltip: 'Edit',
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
          if (_customer != null)
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
              : _buildContent(context, _customer!),
    );
  }

  Widget _buildContent(BuildContext context, Customer c) {
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
                  child: Text(
                    (c.name.isNotEmpty ? c.name[0] : '?').toUpperCase(),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.goldDark,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  c.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                if (c.phone.isNotEmpty)
                  Text(
                    c.phone,
                    style: TextStyle(fontSize: 13, color: secondary),
                  ),
                if (c.shopName != null && c.shopName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      c.shopName!,
                      style: TextStyle(fontSize: 12, color: AppColors.goldDark, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _DueCard(customer: c, onPayment: () => _adjustBalance('payment'), onAddDue: () => _adjustBalance('charge')),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Purchases',
                  value: '${c.purchaseCount}',
                  color: AppColors.goldDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  icon: Icons.payments_outlined,
                  label: 'Total Spent',
                  value: Formatters.currency(c.totalSpent),
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  icon: Icons.history,
                  label: 'Last Purchase',
                  value: Formatters.date(c.lastPurchaseAt),
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Contact & Address',
            icon: Icons.contact_page_outlined,
            children: [
              _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: c.phone.isEmpty ? '—' : c.phone),
              _InfoRow(icon: Icons.email_outlined, label: 'Email', value: c.email.isEmpty ? '—' : c.email),
              _InfoRow(icon: Icons.location_on_outlined, label: 'Address', value: c.address.isEmpty ? '—' : c.address),
              _InfoRow(icon: Icons.location_city_outlined, label: 'City', value: c.city.isEmpty ? '—' : c.city),
              _InfoRow(icon: Icons.notes_outlined, label: 'Notes', value: c.notes.isEmpty ? '—' : c.notes),
              _InfoRow(icon: Icons.calendar_today_outlined, label: 'Added On', value: Formatters.date(c.createdAt)),
            ],
          ),
          if (c.transactions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Due History',
              icon: Icons.account_balance_wallet_outlined,
              children: [
                for (final t in c.transactions.reversed)
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
                                t.note.isEmpty ? (t.isPayment ? 'Payment received' : 'Due added') : t.note,
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
          if (c.recentSales.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Recent Purchases',
              icon: Icons.receipt_long_outlined,
              children: [
                for (final s in c.recentSales)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.invoiceNo, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                              Text(
                                '${Formatters.title(s.paymentMethod)} · ${Formatters.date(s.createdAt)}',
                                style: TextStyle(fontSize: 11.5, color: secondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          Formatters.currency(s.totalAmount),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
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
  const _DueCard({required this.customer, required this.onPayment, required this.onAddDue});

  final Customer customer;
  final VoidCallback onPayment;
  final VoidCallback onAddDue;

  @override
  Widget build(BuildContext context) {
    final hasDue = customer.hasDue;
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
                'Outstanding Due',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.currency(customer.balance),
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
                  label: const Text('Record Payment'),
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

class _StatBox extends StatelessWidget {
  const _StatBox({required this.icon, required this.label, required this.value, required this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: Theme.of(context).textTheme.bodySmall?.color),
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
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
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
