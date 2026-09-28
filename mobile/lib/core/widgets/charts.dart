import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../features/dashboard/models/dashboard_data.dart';
import '../theme/app_colors.dart';

class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    this.height = 220,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final double height;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: height, child: child),
          ],
        ),
      ),
    );
  }
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});

  final List<({Color color, String label})> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: items
          .map(
            (item) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 6),
                Text(item.label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          )
          .toList(),
    );
  }
}

Color labelColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark
    ? AppColors.darkTextSecondary
    : AppColors.textSecondary;

String _axisLabelText(double value) =>
    value >= 1000 ? '${(value / 1000).round()}k' : '${value.round()}';

Widget _axisLabel(BuildContext context, double value, TitleMeta meta) {
  return SideTitleWidget(
    meta: meta,
    space: 6,
    child: Text(
      _axisLabelText(value),
      style: TextStyle(fontSize: 10, color: labelColor(context)),
    ),
  );
}

class LineSalesChart extends StatelessWidget {
  const LineSalesChart({
    super.key,
    required this.points,
    this.showExpenses = true,
    this.lineColor,
    this.expenseColor,
  });

  final List<ChartPoint> points;
  final bool showExpenses;
  final Color? lineColor;
  final Color? expenseColor;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(child: Text('No data yet', style: TextStyle(color: labelColor(context))));
    }

    final salesSpots = points.indexed.map((e) => FlSpot(e.$1.toDouble(), e.$2.sales)).toList();
    final expenseSpots = points.indexed.map((e) => FlSpot(e.$1.toDouble(), e.$2.expenses)).toList();
    final maxY = points.fold<double>(0, (a, p) {
      final maxV = [p.sales, p.expenses].reduce((x, y) => x > y ? x : y);
      return a > maxV ? a : maxV;
    });

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).clamp(1, double.infinity),
          getDrawingHorizontalLine: (v) => FlLine(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkBorder
                : AppColors.border,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) => _axisLabel(context, v, meta),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: (points.length / 7).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (v, meta) {
                final idx = v.round();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    points[idx].label,
                    style: TextStyle(fontSize: 10, color: labelColor(context)),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurfaceHigh
                : AppColors.textPrimary,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${points[s.x.round()].label}\n${s.y.round()}',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    ))
                .toList(),
          ),
        ),
        minY: 0,
        maxY: maxY == 0 ? 100 : maxY * 1.15,
        lineBarsData: [
          LineChartBarData(
            spots: salesSpots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: lineColor ?? AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: (lineColor ?? AppColors.primary).withValues(alpha: 0.12),
            ),
          ),
          if (showExpenses)
            LineChartBarData(
              spots: expenseSpots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: expenseColor ?? AppColors.warning,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }
}

class BarChartWidget extends StatelessWidget {
  const BarChartWidget({
    super.key,
    required this.data,
    required this.color,
  });

  final List<ChartPoint> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text('No data yet', style: TextStyle(color: labelColor(context))));
    }
    final maxY = data.fold<double>(0, (a, p) => p.sales > a ? p.sales : a);

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkBorder
                : AppColors.border,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) => _axisLabel(context, v, meta),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: (data.length / 6).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (v, meta) {
                final idx = v.round();
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    data[idx].label,
                    style: TextStyle(fontSize: 10, color: labelColor(context)),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurfaceHigh
                : AppColors.textPrimary,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${data[group.x.round()].label}\n${rod.toY.round()}',
              const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
        maxY: maxY == 0 ? 100 : maxY * 1.15,
        barGroups: data.indexed
            .map((e) => BarChartGroupData(
                  x: e.$1,
                  barRods: [
                    BarChartRodData(
                      toY: e.$2.sales,
                      color: color,
                      width: 12,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class PieChartWidget extends StatelessWidget {
  const PieChartWidget({super.key, required this.sections, this.showLegend = true});

  final List<({String label, double value})> sections;
  final bool showLegend;

  static const _palette = [
    AppColors.primary,
    AppColors.accent,
    AppColors.secondary,
    AppColors.success,
    AppColors.danger,
    AppColors.warning,
    AppColors.info,
  ];

  @override
  Widget build(BuildContext context) {
    final total = sections.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) {
      return Center(child: Text('No data yet', style: TextStyle(color: labelColor(context))));
    }
    final chart = PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 34,
        sections: sections.indexed
            .map((e) => PieChartSectionData(
                  value: e.$2.value,
                  title: '${((e.$2.value / total) * 100).round()}%',
                  radius: 46,
                  color: _palette[e.$1 % _palette.length],
                  titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ))
            .toList(),
      ),
    );

    if (!showLegend) return chart;

    return Row(
      children: [
        Expanded(flex: 5, child: chart),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: ListView(
            shrinkWrap: true,
            children: sections.indexed
                .map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _palette[e.$1 % _palette.length],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              e.$2.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
