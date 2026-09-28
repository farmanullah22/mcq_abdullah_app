import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'logo_watermark.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
    this.trend,
    this.trendUp,
    this.onTap,
    this.valueType = StatValueType.currency,
  });

  final String title;
  final num value;
  final IconData icon;

  /// Accent color for the icon chip and decorative gradient.
  final Color? color;

  final String? subtitle;

  /// Optional trend indicator text, e.g. "+12%" or "-3%".
  final String? trend;

  /// Whether the trend is positive (green) or negative (red).
  final bool? trendUp;

  final VoidCallback? onTap;
  final StatValueType valueType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = color ?? AppColors.gold;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: isDark ? 0.35 : 0.28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  LogoWatermark(
                    size: 130,
                    opacity: 0.08,
                    alignment: Alignment.bottomRight,
                    padding: const EdgeInsets.only(right: 4, bottom: 4),
                  ),
                  Positioned(
                    right: -24,
                    top: -28,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(icon, size: 19, color: AppColors.deepBlack),
                          ),
                          if (trend != null && trendUp != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: (trendUp! ? AppColors.success : AppColors.danger)
                                    .withValues(alpha: isDark ? 0.22 : 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    trendUp! ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                    size: 11,
                                    color: trendUp! ? AppColors.success : AppColors.danger,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    trend!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: trendUp! ? AppColors.success : AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _AnimatedStatValue(
                        value: value,
                        type: valueType,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated counting value, formatted per tick.
class _AnimatedStatValue extends StatelessWidget {
  const _AnimatedStatValue({required this.value, required this.type, required this.isDark});

  final num value;
  final StatValueType type;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final text = switch (type) {
          StatValueType.currency => Formatters.currency(v),
          StatValueType.number => Formatters.number(v),
          StatValueType.plain => '${v.round()}',
        };
        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        );
      },
    );
  }
}

enum StatValueType { currency, number, plain }
