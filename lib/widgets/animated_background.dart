import 'dart:math' as math;
import 'package:flutter/material.dart';

class MinimalAnimatedBackground extends StatefulWidget {
  const MinimalAnimatedBackground({super.key});

  @override
  State<MinimalAnimatedBackground> createState() => _MinimalAnimatedBackgroundState();
}

class _MinimalAnimatedBackgroundState extends State<MinimalAnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(15, (index) => Particle());
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        for (var p in _particles) {
          p.update();
        }
        return CustomPaint(
          painter: ParticlePainter(
            particles: _particles,
            isDark: isDark,
          ),
          child: Container(),
        );
      },
    );
  }
}

class Particle {
  double x = math.Random().nextDouble();
  double y = math.Random().nextDouble();
  double speedX = (math.Random().nextDouble() - 0.5) * 0.0006;
  double speedY = (math.Random().nextDouble() - 0.5) * 0.0006;
  double radius = math.Random().nextDouble() * 30 + 15;

  void update() {
    x += speedX;
    y += speedY;

    if (x < 0 || x > 1) speedX = -speedX;
    if (y < 0 || y > 1) speedY = -speedY;
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final bool isDark;

  ParticlePainter({required this.particles, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    for (var p in particles) {
      paint.color = isDark
          ? Colors.white.withValues(alpha: 0.02)
          : Colors.black.withValues(alpha: 0.015);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
