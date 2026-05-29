import 'package:flutter/widgets.dart';

/// Returns the character offset within [text] that a tap at [tapPosition]
/// would land on when the text is laid out with [style] inside a box of
/// width [maxWidth]. Used by tap-to-position-cursor in the note and task
/// body fields: the preview widget intercepts the tap, computes the
/// offset, then switches into edit mode and seeds the text controller's
/// selection at that offset.
///
/// [tapPosition] must be in the local coordinates of the text painter
/// (i.e. with any surrounding padding already subtracted). Negative
/// coordinates clamp to the start; coordinates past the text clamp to
/// its end.
int tapOffsetInText({
  required String text,
  required TextStyle style,
  required double maxWidth,
  required Offset tapPosition,
  TextDirection textDirection = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  if (text.isEmpty) return 0;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
  )..layout(maxWidth: maxWidth);
  final clamped = Offset(
    tapPosition.dx.clamp(0.0, painter.width),
    tapPosition.dy.clamp(0.0, painter.height),
  );
  final pos = painter.getPositionForOffset(clamped);
  painter.dispose();
  return pos.offset.clamp(0, text.length);
}
