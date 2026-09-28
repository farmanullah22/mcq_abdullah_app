import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/formatters.dart';
import 'carpet_pattern.dart';

const luxGold = Color(0xFFD4AF37);
const luxGoldLight = Color(0xFFF7D488);
const luxGoldDark = Color(0xFFB8860B);
const luxBg = Color(0xFF0B0B0F);

/// Full premium backdrop used by the admin dashboard and branch screens:
/// the showroom image, dark gradient overlay, gold glows and carpet motif.
class ShowroomBackground extends StatelessWidget {
  const ShowroomBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'lib/images/admin_dashboard.jfif',
          fit: BoxFit.cover,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x50050505),
                Color(0x99050505),
                Color(0xB8050505),
              ],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -90,
          child: _LuxGlow(size: 280, color: luxGold.withValues(alpha: 0.10)),
        ),
        Positioned(
          top: 430,
          left: -120,
          child: _LuxGlow(size: 320, color: luxGoldDark.withValues(alpha: 0.09)),
        ),
        Positioned(
          bottom: 60,
          right: -120,
          child: _LuxGlow(
            size: 300,
            color: const Color(0xFF3A2E10).withValues(alpha: 0.28),
          ),
        ),
        const CarpetPattern(opacity: 0.05),
      ],
    );
  }
}

class _LuxGlow extends StatelessWidget {
  const _LuxGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Transparent frosted-glass card with a gold border — the signature look
/// of the admin dashboard, reused on every branch screen.
class LuxGlassCard extends StatelessWidget {
  const LuxGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: luxGold.withValues(alpha: glow ? 0.22 : 0.10),
            blurRadius: glow ? 34 : 24,
            spreadRadius: glow ? -4 : -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: luxGold.withValues(alpha: glow ? 0.5 : 0.34),
                width: glow ? 1.2 : 1,
              ),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class LuxSectionTitle extends StatelessWidget {
  const LuxSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.action,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null && actionLabel != null)
          TextButton(
            onPressed: action,
            style: TextButton.styleFrom(
              foregroundColor: luxGoldLight,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              actionLabel!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class LuxGoldGradientText extends StatelessWidget {
  const LuxGoldGradientText({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [luxGoldLight, luxGold, luxGoldDark],
      ).createShader(rect),
      blendMode: BlendMode.srcIn,
      child: child,
    );
  }
}

class LuxAnimatedNumber extends StatelessWidget {
  const LuxAnimatedNumber({
    super.key,
    required this.value,
    required this.style,
    this.currency = true,
  });

  final num value;
  final TextStyle style;
  final bool currency;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        currency ? Formatters.currency(v) : Formatters.number(v),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class LuxGoldDivider extends StatelessWidget {
  const LuxGoldDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(double.infinity, 14),
      painter: _LuxGoldDividerPainter(),
    );
  }
}

class _LuxGoldDividerPainter extends CustomPainter {
  const _LuxGoldDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final line = Paint()
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        colors: [
          luxGold.withValues(alpha: 0),
          luxGold.withValues(alpha: 0.75),
          luxGold.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawLine(Offset(0, midY), Offset(size.width * 0.42, midY), line);
    canvas.drawLine(
        Offset(size.width * 0.58, midY), Offset(size.width, midY), line);

    final diamond = Paint()..color = luxGoldLight;
    final center = Offset(size.width / 2, midY);
    final s = 5.0;
    final path = Path()
      ..moveTo(center.dx, center.dy - s)
      ..lineTo(center.dx + s * 0.7, center.dy)
      ..lineTo(center.dx, center.dy + s)
      ..lineTo(center.dx - s * 0.7, center.dy)
      ..close();
    canvas.drawPath(path, diamond);
  }

  @override
  bool shouldRepaint(_LuxGoldDividerPainter oldDelegate) => false;
}

class LuxEmptyNote extends StatelessWidget {
  const LuxEmptyNote(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class LuxLoadingView extends StatelessWidget {
  const LuxLoadingView({super.key, this.message = 'Loading...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              color: luxGold,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class LuxErrorView extends StatelessWidget {
  const LuxErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: luxGold, size: 42),
            const SizedBox(height: 14),
            Text(
              'Something went wrong',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: luxGoldLight,
                side: const BorderSide(color: luxGold),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              ),
              icon: const Icon(Icons.refresh, size: 17),
              label: Text(
                'Retry',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
