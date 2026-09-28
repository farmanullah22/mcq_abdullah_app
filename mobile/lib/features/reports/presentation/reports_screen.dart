import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bar_brand.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/report_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  Future<void> _shareBytes(List<int> bytes, String name) async {
    if (bytes.isEmpty) return;
    final dir = await getTemporaryDirectory();
    final file = await File('${dir.path}/$name').writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: name));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportControllerProvider);
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppBarBrand(showText: false),
            const SizedBox(width: 10),
            Text('Reports'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(reportControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: AppConstants.reportPeriods
                .map((p) => ButtonSegment(value: p, label: Text(Formatters.title(p))))
                .toList(),
            selected: {state.period},
            onSelectionChanged: (s) => ref.read(reportControllerProvider.notifier).setPeriod(s.first),
          ),
          const SizedBox(height: 16),
          _buildSummary(context, state),
          SectionHeader(title: 'Sales Report', subtitle: 'For the selected period'),
          _buildSales(state),
          SectionHeader(title: 'Expense Report', subtitle: 'For the selected period'),
          _buildExpenses(state),
          SectionHeader(title: 'Inventory Report', subtitle: 'Current stock valuation'),
          _buildInventory(state),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: state.exporting
                    ? null
                    : () async {
                        final bytes = await ref.read(reportControllerProvider.notifier).exportCsv(type: 'sales');
                        await _shareBytes( bytes ?? [], 'sales_report_${state.period}.csv');
                      },
                icon: const Icon(Icons.download),
                label: Text(state.exporting ? 'Exporting...' : 'Export Sales'),
              ),
              FilledButton.icon(
                onPressed: state.exporting
                    ? null
                    : () async {
                        final bytes = await ref.read(reportControllerProvider.notifier).exportCsv(type: 'expenses');
                        await _shareBytes( bytes ?? [], 'expense_report_${state.period}.csv');
                      },
                icon: const Icon(Icons.download),
                label: Text(state.exporting ? 'Exporting...' : 'Export Expenses'),
              ),
              FilledButton.icon(
                onPressed: state.exporting
                    ? null
                    : () async {
                        final bytes = await ref.read(reportControllerProvider.notifier).exportCsv(type: 'inventory');
                        await _shareBytes( bytes ?? [], 'inventory_report.csv');
                      },
                icon: const Icon(Icons.download),
                label: Text(state.exporting ? 'Exporting...' : 'Export Inventory'),
              ),
              if (isAdmin)
                FilledButton.icon(
                  onPressed: state.exporting
                      ? null
                      : () async {
                          final bytes = await ref.read(reportControllerProvider.notifier).exportAuditCsv();
                          await _shareBytes( bytes ?? [], 'audit_logs.csv');
                        },
                  icon: const Icon(Icons.download),
                  label: Text(state.exporting ? 'Exporting...' : 'Export Audit Logs'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, ReportState state) {
    return state.summary.when(
      loading: () => const Card(child: Padding(padding: EdgeInsets.all(24), child: LoadingView())),
      error: (e, st) => ErrorView(message: e.toString(), compact: true),
      data: (r) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${Formatters.title(r.period)} Summary',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 12),
              _SummaryGrid(r: r),
              const SizedBox(height: 12),
              Text(
                'Generated ${Formatters.dateTime(r.generatedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSales(ReportState state) {
    return state.sales.when(
      loading: () => const Card(child: Padding(padding: EdgeInsets.all(24), child: LoadingView())),
      error: (e, st) => ErrorView(message: e.toString(), compact: true),
      data: (r) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total: ${Formatters.currency(r.total)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                  Text('${r.count} sales'),
                ],
              ),
              const SizedBox(height: 6),
              Text('Profit: ${Formatters.currency(r.profit)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.success)),
              const SizedBox(height: 12),
              ...r.paymentSummary.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(AppConstants.paymentMethodLabels[e.key] ?? Formatters.title(e.key)),
                      ),
                      Text('${e.value['count']} sales · ${Formatters.currency(e.value['total'])}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenses(ReportState state) {
    return state.expenses.when(
      loading: () => const Card(child: Padding(padding: EdgeInsets.all(24), child: LoadingView())),
      error: (e, st) => ErrorView(message: e.toString(), compact: true),
      data: (r) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total: ${Formatters.currency(r.total)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger)),
                  Text('${r.count} expenses'),
                ],
              ),
              const SizedBox(height: 12),
              if (r.breakdown.isEmpty)
                const Text('No expenses in this period')
              else
                ...r.breakdown.map((b) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(AppConstants.expenseCategoryLabels[b['_id']?.toString() ?? 'other'] ?? 'Other'),
                          ),
                          Text(Formatters.currency((b['total'] as num?)?.toDouble() ?? 0),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventory(ReportState state) {
    return state.inventory.when(
      loading: () => const Card(child: Padding(padding: EdgeInsets.all(24), child: LoadingView())),
      error: (e, st) => ErrorView(message: e.toString(), compact: true),
      data: (r) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Stock Value: ${Formatters.currency(r.totalStockValue)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                  Text('${r.totalProducts} products'),
                ],
              ),
              const SizedBox(height: 6),
              Text('Low stock: ${r.lowStockCount} · Potential revenue: ${Formatters.currency(r.potentialRevenue)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.r});

  final dynamic r;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value, Color color})>[
      (label: 'Sales', value: Formatters.currency(r.sales), color: AppColors.primary),
      (label: 'Expenses', value: Formatters.currency(r.expenses), color: AppColors.danger),
      (label: 'Profit', value: Formatters.currency(r.profit), color: AppColors.success),
      (label: 'Products', value: '${r.totalProducts}', color: AppColors.secondary),
      (label: 'Stock Value', value: Formatters.currency(r.stockValue), color: AppColors.info),
      (label: 'Transactions', value: '${r.salesCount} sales · ${r.expenseCount} expenses', color: AppColors.textSecondary),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: rows
              .map((e) => SizedBox(
                    width: width,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: e.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value,
                              style: TextStyle(fontWeight: FontWeight.w800, color: e.color, fontSize: 15)),
                          const SizedBox(height: 3),
                          Text(e.label, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}
