import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../../dashboard/models/dashboard_data.dart';
import '../providers/analytics_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsControllerProvider);
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(analyticsControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.data.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(analyticsControllerProvider.notifier).refresh(),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.read(analyticsControllerProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              ChartCard(
                title: 'Daily Sales',
                subtitle: 'Last 14 days',
                height: 220,
                child: LineSalesChart(points: data.daily),
              ),
              ChartCard(
                title: 'Weekly Sales',
                subtitle: 'Last 12 weeks',
                height: 200,
                child: BarChartWidget(data: data.weekly, color: AppColors.primary),
              ),
              ChartCard(
                title: 'Monthly Sales',
                subtitle: 'Last 12 months',
                height: 220,
                child: LineSalesChart(points: data.monthly),
              ),
              ChartCard(
                title: 'Yearly Sales',
                subtitle: 'Last 5 years',
                height: 200,
                child: BarChartWidget(data: data.yearly, color: AppColors.accent),
              ),
              ChartCard(
                title: 'Expense Breakdown',
                subtitle: 'All time',
                height: 260,
                child: PieChartWidget(
                  sections: data.expenseBreakdown.map((e) => (label: e.category, value: e.total)).toList(),
                ),
              ),
              if (isAdmin && data.comparison.length > 1) ...[
                ChartCard(
                  title: 'Shop Comparison',
                  subtitle: 'Revenue, expenses & profit per shop',
                  height: 240,
                  child: _ComparisonTable(comparison: data.comparison),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.comparison});

  final List<ShopComparison> comparison;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: comparison
          .map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.shopName ?? 'Shop',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            label: 'Sales',
                            value: c.sales,
                            color: AppColors.primary,
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: 'Expenses',
                            value: c.expenses,
                            color: AppColors.danger,
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: 'Profit',
                            value: c.profit,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          value >= 1000000
              ? '${(value / 1000000).toStringAsFixed(1)}M'
              : value >= 1000
                  ? '${(value / 1000).toStringAsFixed(0)}k'
                  : '${value.round()}',
          style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13),
        ),
      ],
    );
  }
}
