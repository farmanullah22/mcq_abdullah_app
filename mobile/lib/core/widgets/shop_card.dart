import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'carpet_pattern.dart';
import 'logo_watermark.dart';

class ShopCard extends StatelessWidget {
  const ShopCard({
    super.key,
    required this.name,
    this.manager,
    this.revenue = 0,
    this.profit = 0,
    this.saleCount = 0,
    this.open = true,
    this.gradient,
    this.onOpen,
    this.onTap,
  });

  final String name;
  final String? manager;
  final double revenue;
  final double profit;
  final int saleCount;
  final bool open;
  final LinearGradient? gradient;
  final VoidCallback? onOpen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = gradient?.colors ?? AppColors.emeraldGradient.colors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: colors.first.withValues(alpha: 0.30), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -36,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), shape: BoxShape.circle),
                ),
              ),
              Positioned(
                left: -24,
                bottom: -30,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.10), shape: BoxShape.circle),
                ),
              ),
              Positioned.fill(
                child: CarpetPattern(opacity: 0.06, color: Colors.white),
              ),
              LogoWatermark(
                size: 150,
                opacity: 0.09,
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.only(right: 6, bottom: 6),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (manager != null)
                                Text(
                                  manager!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: (open ? AppColors.success : AppColors.danger).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                open ? Icons.brightness_1 : Icons.cancel_rounded,
                                size: 9,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                open ? 'Open' : 'Closed',
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _Metric(label: 'Revenue', value: Formatters.compact(revenue)),
                        _Metric(label: 'Profit', value: Formatters.compact(profit)),
                        _Metric(label: 'Sales', value: '$saleCount'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onOpen,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Open Shop',
                                  style: TextStyle(
                                    color: AppColors.deepBlack,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.deepBlack),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
