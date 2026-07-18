import 'dart:math' as math;
import 'dart:ui';
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
    final random = math.Random();
    
    // Minimalist, premium titanium/slate colors
    final colors = [
      const Color(0xFF3F3F46), // Gunmetal Grey
      const Color(0xFF52525B), // Slate Grey
      const Color(0xFF27272A), // Dark Graphite
      const Color(0xFF475569), // Muted Slate Blue
    ];

    _particles = List.generate(8, (index) {
      return Particle(
        color: colors[random.nextInt(colors.length)],
        radius: random.nextDouble() * 200 + 150,
        speedX: (random.nextDouble() - 0.5) * 0.0006, // Elegant, slow drift
        speedY: (random.nextDouble() - 0.5) * 0.0006,
      );
    });

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        for (var p in _particles) {
          p.update();
        }
        return Stack(
          children: [
            // 1. Minimalist Space Grey / Titanium Gradient Background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF18181B), // Deep Carbon Black
                      Color(0xFF2E2E33), // Space Grey / Matte Titanium
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // 2. Slow floating shapes
            Positioned.fill(
              child: CustomPaint(
                painter: BokehPainter(
                  particles: _particles,
                  isDark: isDark,
                ),
              ),
            ),
            // 3. Frosted Glass Blur Overlay
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: isDark
                      ? const Color(0xFF000000).withValues(alpha: 0.15) // Deep contrast tint
                      : const Color(0xFFFFFFFF).withValues(alpha: 0.10), // Clean light frost
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class Particle {
  final Color color;
  final double radius;
  final double speedX;
  final double speedY;

  double x = math.Random().nextDouble();
  double y = math.Random().nextDouble();

  Particle({
    required this.color,
    required this.radius,
    required this.speedX,
    required this.speedY,
  });

  void update() {
    x += speedX;
    y += speedY;

    if (x < -0.3) x = 1.3;
    if (x > 1.3) x = -0.3;
    if (y < -0.3) y = 1.3;
    if (y > 1.3) y = -0.3;
  }
}

class BokehPainter extends CustomPainter {
  final List<Particle> particles;
  final bool isDark;

  BokehPainter({required this.particles, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final center = Offset(p.x * size.width, p.y * size.height);
      final rect = Rect.fromCircle(center: center, radius: p.radius);
      
      final gradient = RadialGradient(
        colors: [
          p.color.withValues(alpha: isDark ? 0.12 : 0.08),
          p.color.withValues(alpha: 0.0),
        ],
      );

      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
