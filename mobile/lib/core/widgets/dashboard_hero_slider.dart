import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'logo_watermark.dart';

class HeroSlide {
  final String title;
  final String value;
  final String? caption;
  final String buttonLabel;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onPressed;

  const HeroSlide({
    required this.title,
    required this.value,
    required this.buttonLabel,
    required this.icon,
    required this.gradient,
    required this.onPressed,
    this.caption,
  });
}

/// Auto-playing premium hero slider with page indicators and gradient slides.
class DashboardHeroSlider extends StatefulWidget {
  const DashboardHeroSlider({super.key, required this.slides, this.height = 200});

  final List<HeroSlide> slides;
  final double height;

  @override
  State<DashboardHeroSlider> createState() => _DashboardHeroSliderState();
}

class _DashboardHeroSliderState extends State<DashboardHeroSlider> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
    _startTimer();
  }

  void _startTimer() {
    if (widget.slides.length < 2) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % widget.slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              final slide = widget.slides[index];
              return AnimatedPadding(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  right: index == widget.slides.length - 1 ? 0 : 12,
                ),
                child: _SlideCard(slide: slide),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.slides.length, (i) {
            final selected = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: selected ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                gradient: selected ? AppGradients.primary : AppGradients.dot,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.slide});

  final HeroSlide slide;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: slide.gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: slide.gradient.colors.first.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -32,
            child: _GlowCircle(radius: 90, color: Colors.white.withValues(alpha: 0.10)),
          ),
          Positioned(
            right: 36,
            bottom: -40,
            child: _GlowCircle(radius: 72, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Positioned(
            left: -20,
            bottom: -26,
            child: _GlowCircle(radius: 64, color: Colors.black.withValues(alpha: 0.10)),
          ),
          LogoWatermark(
            size: 170,
            opacity: 0.09,
            alignment: Alignment.bottomRight,
            padding: const EdgeInsets.only(right: 8, bottom: 4),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: _MiniSparkline(color: Colors.white, width: 86, height: 40),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(slide.icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        slide.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    slide.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                if (slide.caption != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          slide.caption!,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: slide.onPressed,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              slide.buttonLabel,
                              style: TextStyle(
                                color: slide.gradient.colors.first,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 16, color: slide.gradient.colors.first),
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
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Animated decorative line chart used inside premium hero slides.
class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({required this.color, required this.width, required this.height});

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        size: Size(width, height),
        painter: _SparklinePainter(color: color, progress: t),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  static const _values = [0.38, 0.55, 0.46, 0.68, 0.58, 0.82, 0.72, 0.94, 0.85, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final stroke = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
      ).createShader(Offset.zero & size);

    final step = size.width / (_values.length - 1);
    final count = math.max(2, (progress * _values.length).round());

    final path = Path();
    for (var i = 0; i < count; i++) {
      final dx = i * step;
      final dy = size.height * (1 - _values[i] * 0.72 - 0.06);
      i == 0 ? path.moveTo(dx, dy) : path.lineTo(dx, dy);
    }

    final area = Path.from(path)
      ..lineTo((count - 1) * step, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Shared gradients + reusable pieces for the premium dashboard.
class AppGradients {
  AppGradients._();

  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFFD4AF37), Color(0xFFE9CE7A)],
  );
  static const LinearGradient dot = LinearGradient(
    colors: [Color(0xFFD8CEB8), Color(0xFFD8CEB8)],
  );
  static const LinearGradient bg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF1ECE1), Color(0xFFF8F6F1)],
  );
  static const LinearGradient bgDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1815), Color(0xFF121212)],
  );
}
