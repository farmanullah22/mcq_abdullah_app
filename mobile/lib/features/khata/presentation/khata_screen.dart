import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_views.dart';
import '../models/khata_entry.dart';
import '../providers/khata_providers.dart';

const List<String> kMethods = ['cash', 'bank', 'cheque', 'online', 'easypaisa', 'jazzcard'];

const Map<String, String> kMethodLabels = {
  'cash': 'Cash',
  'bank': 'Bank',
  'cheque': 'Cheque',
  'online': 'Online',
  'easypaisa': 'Easypaisa',
  'jazzcard': 'JazzCard',
};

class KhataScreen extends ConsumerStatefulWidget {
  const KhataScreen({super.key});

  @override
  ConsumerState<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends ConsumerState<KhataScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    ref
        .read(khataListControllerProvider.notifier)
        .setFilters(customer: _searchController.text.trim());
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searching = false);
    ref.read(khataListControllerProvider.notifier).setFilters(customer: null);
  }

  Future<void> _confirmDelete(KhataEntry entry) async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remove the ${entry.isGiven ? 'given' : 'received'} entry of '
              '${Formatters.currency(entry.amount)} for ${entry.customerName}?',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final success = await ref
          .read(khataMutationControllerProvider.notifier)
          .delete(entry.id, reason: reasonController.text.trim());
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(khataMutationControllerProvider).error ?? 'Delete failed')),
        );
      }
    }
    reasonController.dispose();
  }

  void _openForm({KhataEntry? entry}) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => KhataFormScreen(entry: entry)))
        .then((_) {
      if (mounted) ref.read(khataListControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(khataListControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Khata'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filters',
            onSelected: (v) {
              if (v == 'clear') {
                ref.read(khataListControllerProvider.notifier).setFilters(method: null, direction: null);
                return;
              }
              if (v.startsWith('m:')) {
                ref
                    .read(khataListControllerProvider.notifier)
                    .setFilters(method: v.substring(2));
                return;
              }
              ref
                  .read(khataListControllerProvider.notifier)
                  .setFilters(direction: v.substring(2));
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'clear', child: Text('Clear filters')),
              const PopupMenuDivider(),
              for (final m in kMethods)
                PopupMenuItem(
                  value: 'm:$m',
                  child: Text('Method: ${kMethodLabels[m]}'),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'd:in', child: Text('Received only')),
              const PopupMenuItem(value: 'd:out', child: Text('Given only')),
            ],
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(khataListControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addKhata',
        backgroundColor: AppColors.gold,
        foregroundColor: const Color(0xFF17151C),
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Entry'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onChanged: (v) {
                if (v.trim().isEmpty && _searching) _clearSearch();
              },
              decoration: InputDecoration(
                hintText: 'Search by customer name or number...',
                hintStyle: const TextStyle(fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: _clearSearch,
                      ),
                    IconButton(
                      tooltip: 'Search',
                      icon: const Icon(Icons.arrow_forward, size: 20),
                      onPressed: _search,
                    ),
                  ],
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.28)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.28)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.gold, width: 1.4),
                ),
              ),
            ),
          ),
          if (state.method != null || state.direction != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (state.method != null)
                      Chip(
                        label: Text('Method: ${kMethodLabels[state.method]}'),
                        onDeleted: () => ref
                            .read(khataListControllerProvider.notifier)
                            .setFilters(method: null),
                      ),
                    if (state.direction != null)
                      Chip(
                        label: Text(state.direction == 'in' ? 'Received only' : 'Given only'),
                        onDeleted: () => ref
                            .read(khataListControllerProvider.notifier)
                            .setFilters(direction: null),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: state.data.when(
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.read(khataListControllerProvider.notifier).refresh(),
              ),
              data: (page) {
                if (page.total == 0) {
                  return EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: _searching ? 'No matches found' : 'Your khata is empty',
                    subtitle: _searching
                        ? 'No entries match "$_searchController.text".'
                        : 'Tap Add Entry to record money you gave or received.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(khataListControllerProvider.notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    children: [
                      _TotalsCard(totals: page.totals),
                      if (page.balances.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const _SubHeading('Who owes you'),
                        const SizedBox(height: 8),
                        for (final b in page.balances)
                          _BalanceTile(
                            balance: b,
                            onOpenCustomer: () {
                              final target = b.customerNumber.isNotEmpty
                                  ? b.customerNumber
                                  : b.customerName;
                              _searchController.text = target;
                              setState(() => _searching = true);
                              ref
                                  .read(khataListControllerProvider.notifier)
                                  .setFilters(customer: target);
                            },
                          ),
                      ],
                      const SizedBox(height: 18),
                      _SubHeading(
                        _searching || page.total > page.entries.length
                            ? 'Entries'
                            : 'All entries',
                        trailing: page.total > page.entries.length
                            ? '${page.entries.length} of ${page.total}'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      for (final e in page.entries)
                        _EntryTile(
                          entry: e,
                          onEdit: () => _openForm(entry: e),
                          onDelete: () => _confirmDelete(e),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SubHeading extends StatelessWidget {
  const _SubHeading(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        if (trailing != null)
          Text(trailing!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals});

  final KhataTotals totals;

  @override
  Widget build(BuildContext context) {
    final outstanding = totals.outstanding;
    final owed = outstanding > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Outstanding',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  Formatters.currency(outstanding.abs()),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: owed ? AppColors.danger : AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  owed ? 'you are out of pocket' : 'in your favour',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Total given',
                    value: Formatters.currency(totals.given),
                    color: AppColors.danger,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Total received',
                    value: Formatters.currency(totals.received),
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color),
        ),
      ],
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.balance, required this.onOpenCustomer});

  final KhataBalance balance;
  final VoidCallback onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    final o = balance.outstanding;
    final owes = o > 0.009;
    final settled = o.abs() <= 0.009;
    final color = settled ? AppColors.success : (owes ? AppColors.danger : AppColors.info);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Text(
            balance.customerName.isEmpty
                ? '?'
                : balance.customerName.characters.first.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          balance.customerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            if (balance.customerNumber.isNotEmpty) balance.customerNumber,
            '${balance.entryCount} ${balance.entryCount == 1 ? 'entry' : 'entries'}',
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              settled ? 'Settled' : Formatters.currency(o.abs()),
              style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14),
            ),
            if (!settled)
              Text(
                owes ? 'owes you' : 'you owe',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
          ],
        ),
        onTap: onOpenCustomer,
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onEdit, required this.onDelete});

  final KhataEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final given = entry.isGiven;
    final color = given ? AppColors.danger : AppColors.success;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(given ? Icons.north_east_rounded : Icons.south_west_rounded, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                      Text(
                        '${given ? '-' : '+'}${Formatters.currency(entry.amount)}',
                        style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      given ? 'Given' : 'Received',
                      kMethodLabels[entry.method] ?? entry.method,
                      if (entry.customerNumber.isNotEmpty) entry.customerNumber,
                      if (entry.notes.isNotEmpty) entry.notes,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.dateTime(entry.entryDate),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- form ----

class KhataFormScreen extends ConsumerStatefulWidget {
  const KhataFormScreen({super.key, this.entry});

  final KhataEntry? entry;

  @override
  ConsumerState<KhataFormScreen> createState() => _KhataFormScreenState();
}

class _KhataFormScreenState extends ConsumerState<KhataFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late final TextEditingController _dateController;
  late String _direction;
  late String _method;
  late DateTime _entryDate;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _nameController = TextEditingController(text: e?.customerName ?? '');
    _numberController = TextEditingController(text: e?.customerNumber ?? '');
    _amountController = TextEditingController(
      text: e == null ? '' : e.amount.toStringAsFixed(0),
    );
    _notesController = TextEditingController(text: e?.notes ?? '');
    _direction = e?.direction ?? 'out';
    _method = e?.method ?? 'cash';
    _entryDate = e?.entryDate ?? DateTime.now();
    _dateController = TextEditingController(text: Formatters.date(_entryDate));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _entryDate = picked;
        _dateController.text = Formatters.date(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(khataMutationControllerProvider.select((s) => s.loading));
    final given = _direction == 'out';

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Entry' : 'Add Khata Entry')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'out',
                    label: Text('Money Given'),
                    icon: Icon(Icons.north_east, size: 18),
                  ),
                  ButtonSegment(
                    value: 'in',
                    label: Text('Money Received'),
                    icon: Icon(Icons.south_west, size: 18),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (s) => setState(() => _direction = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                given
                    ? 'You handed this money over — it increases what they owe you.'
                    : 'You took this money back — it reduces what they owe you.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                validator: (v) => Validators.required(v, 'Customer name is required'),
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _numberController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Number (optional)',
                  prefixIcon: Icon(Icons.call_outlined),
                ),
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
                decoration: const InputDecoration(
                  labelText: 'Amount (Rs.)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(
                  labelText: 'Cash / Bank',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                items: kMethods
                    .map((m) => DropdownMenuItem(value: m, child: Text(kMethodLabels[m]!)))
                    .toList(),
                onChanged: (v) => setState(() => _method = v ?? 'cash'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: _pickDate,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.event_outlined),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              LoadingButton(
                loading: loading,
                label: _isEditing ? 'Save Changes' : 'Add Entry',
                icon: Icons.check,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(khataMutationControllerProvider.notifier);
    final amount = double.parse(_amountController.text.trim());

    final ok = _isEditing
        ? await notifier.update(
            widget.entry!.id,
            customerName: _nameController.text.trim(),
            customerNumber: _numberController.text.trim(),
            direction: _direction,
            amount: amount,
            method: _method,
            entryDate: _entryDate,
            notes: _notesController.text.trim(),
          )
        : await notifier.create(
            customerName: _nameController.text.trim(),
            customerNumber: _numberController.text.trim(),
            direction: _direction,
            amount: amount,
            method: _method,
            entryDate: _entryDate,
            notes: _notesController.text.trim(),
          );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(khataMutationControllerProvider).error ?? 'Could not save entry'),
        ),
      );
    }
  }
}