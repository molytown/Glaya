import 'package:flutter/material.dart';

/// Replicates the React auth slide-out `waterFlow` animation:
/// a 135deg pink/purple gradient sized at 500% that pans
/// horizontally (background-position 0% -> 100% -> 0%) over 9s,
/// ease-in-out, infinite.
class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 9),
      vsync: this,
    );
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOut)
        .drive(Tween(begin: 0.0, end: 1.0));
    _controller.repeat(reverse: true);
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
        AnimatedBuilder(
          animation: _t,
          builder: (context, child) {
            return CustomPaint(
              painter: _GradientPanPainter(t: _t.value),
              size: Size.infinite,
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class _GradientPanPainter extends CustomPainter {
  final double t;

  _GradientPanPainter({required this.t});

  static const _colors = [
    Color(0xFFE91E8C),
    Color(0xFFC2185B),
    Color(0xFF7209B7),
    Color(0xFFB5179E),
    Color(0xFFFF006E),
    Color(0xFF9C27B0),
  ];

  static const _stops = [0.0, 0.15, 0.4, 0.6, 0.8, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    // CSS: background-size 500% 500%; background-position 0% 50% -> 100% 50%.
    // For an oversized image, percentage offset = (container - image) * pct,
    // so x pans 0 -> -4W and y stays fixed at -2H.
    final tileW = size.width * 5;
    final tileH = size.height * 5;
    final dx = -4 * size.width * t;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(dx, -2 * size.height);

    final rect = Rect.fromLTWH(0, 0, tileW, tileH);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _colors,
        stops: _stops,
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_GradientPanPainter oldDelegate) => oldDelegate.t != t;
}
