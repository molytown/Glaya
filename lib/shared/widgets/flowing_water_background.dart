import 'dart:math' as math;
import 'package:flutter/material.dart';

class FlowingWaterBackground extends StatefulWidget {
  final Widget child;

  const FlowingWaterBackground({
    super.key,
    required this.child,
  });

  @override
  State<FlowingWaterBackground> createState() => _FlowingWaterBackgroundState();
}

class _FlowingWaterBackgroundState extends State<FlowingWaterBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated water background
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: FlowingWaterPainter(
                animation: _controller.value,
              ),
              size: Size.infinite,
            );
          },
        ),
        // Content
        widget.child,
      ],
    );
  }
}

class FlowingWaterPainter extends CustomPainter {
  final double animation;

  FlowingWaterPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Base gradient - deep blue to teal
    final baseGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF0D47A1), // Deep blue
        const Color(0xFF1976D2), // Blue
        const Color(0xFF00897B), // Teal
        const Color(0xFF00695C), // Dark teal
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );

    final baseRect = Rect.fromLTWH(0, 0, size.width, size.height);
    paint.shader = baseGradient.createShader(baseRect);
    canvas.drawRect(baseRect, paint);

    // Draw multiple layers of flowing waves
    _drawWaveLayer(
      canvas,
      size,
      animation * 2 * math.pi,
      0.3, // opacity
      20.0, // amplitude
      40.0, // frequency
      const Color(0xFF4FC3F7), // Light blue
    );

    _drawWaveLayer(
      canvas,
      size,
      animation * 3 * math.pi + 1.5,
      0.25, // opacity
      15.0, // amplitude
      30.0, // frequency
      const Color(0xFF81D4FA), // Lighter blue
    );

    _drawWaveLayer(
      canvas,
      size,
      animation * 1.5 * math.pi + 3.0,
      0.2, // opacity
      25.0, // amplitude
      50.0, // frequency
      const Color(0xFFB3E5FC), // Very light blue
    );

    // Draw subtle bubbles/particles
    _drawParticles(canvas, size, animation);
  }

  void _drawWaveLayer(
    Canvas canvas,
    Size size,
    double phase,
    double opacity,
    double amplitude,
    double frequency,
    Color color,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    // Create wavy path
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.5 +
          math.sin((x * frequency / size.width) * 2 * math.pi + phase) * amplitude;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawParticles(Canvas canvas, Size size, double animation) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // Draw floating particles
    for (int i = 0; i < 20; i++) {
      final seed = i * 137.5;
      final x = (seed * 7.13 + animation * 50) % size.width;
      final y = (seed * 3.71 + animation * 30) % size.height;
      final radius = 2.0 + (seed % 3.0);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(FlowingWaterPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
