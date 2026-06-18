import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

/// A circular progress ring with an optional [center] child. [fraction] is
/// 0..1 and animates when it changes.
class GoalProgressRing extends StatelessWidget {
  const GoalProgressRing({
    super.key,
    required this.fraction,
    required this.color,
    this.size = 56,
    this.stroke = 8,
    this.center,
  });

  final double fraction;
  final Color color;
  final double size;
  final double stroke;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final track = CupertinoColors.systemGrey5.resolveFrom(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: fraction.isNaN ? 0 : fraction.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
                fraction: value, color: color, track: track, stroke: stroke),
            child: center == null ? null : Center(child: center),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double fraction;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (fraction <= 0) return;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}
