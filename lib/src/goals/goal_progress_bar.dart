import 'package:flutter/cupertino.dart';

/// The goal progress bar: a rounded track whose fill runs through a
/// red → amber → green gradient, so a barely-started goal reads red and a
/// finished one reads green.
///
/// The gradient is sampled across the *whole* bar width and then clipped to
/// the current fraction — that way the leading edge's colour tracks progress
/// (25 % ends in orange-red, 90 % ends in near-green) instead of every bar
/// ending on the same hue.
class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({
    super.key,
    required this.fraction,
    this.height = 10,
    this.animate = true,
  });

  /// 0.0 … 1.0.
  final double fraction;
  final double height;
  final bool animate;

  static const _stops = <Color>[
    Color(0xFFFF3B30), // red — nothing done
    Color(0xFFFF9500), // orange
    Color(0xFFFFCC00), // amber — halfway
    Color(0xFF8CD00B), // yellow-green
    Color(0xFF34C759), // green — complete
  ];

  @override
  Widget build(BuildContext context) {
    final value = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    final track = CupertinoColors.tertiarySystemFill.resolveFrom(context);

    Widget bar(double v) => ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: track)),
                // LayoutBuilder + a full-width gradient clipped by width keeps
                // the colour ramp anchored to the bar, not to the fill.
                LayoutBuilder(
                  builder: (context, constraints) => SizedBox(
                    width: constraints.maxWidth * v,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        maxWidth: constraints.maxWidth,
                        child: Container(
                          width: constraints.maxWidth,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: _stops),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    if (!animate) return bar(value);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => bar(v),
    );
  }
}
