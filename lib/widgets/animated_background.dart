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
    final random = math.Random();
    
    // Curated premium vibrant palette: neon blue, indigo, magenta/pink, cyan
    final colors = [
      const Color(0xFF00D2FF), // Cyan
      const Color(0xFF0066FF), // Neon Blue
      const Color(0xFF9D00FF), // Violet/Indigo
      const Color(0xFFFF007F), // Vibrant Pink/Magenta
    ];

    _particles = List.generate(15, (index) {
      return Particle(
        color: colors[random.nextInt(colors.length)],
        radius: random.nextDouble() * 150 + 100, // Large glowing blobs
        speedX: (random.nextDouble() - 0.5) * 0.002, // Increased speed for visibility
        speedY: (random.nextDouble() - 0.5) * 0.002,
      );
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
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
          painter: BokehPainter(
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

    // Bounce off walls smoothly
    if (x < -0.2 || x > 1.2) x = x < 0 ? -0.2 : 1.2;
    if (y < -0.2 || y > 1.2) y = y < 0 ? -0.2 : 1.2;
    
    // Gently wrap around or drift back
    if (x <= -0.2 || x >= 1.2) x = math.Random().nextDouble();
    if (y <= -0.2 || y >= 1.2) y = math.Random().nextDouble();
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
      
      // Radial gradient for smooth glow / bokeh effect
      final rect = Rect.fromCircle(center: center, radius: p.radius);
      
      // Increased opacity values so they are clearly visible
      final gradient = RadialGradient(
        colors: [
          p.color.withValues(alpha: isDark ? 0.20 : 0.12),
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
