import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

/// Slides one Space off the screen and the next one on, and lets a drag carry
/// that movement directly.
///
/// Switching Space rebuilds the whole app: `main.dart` re-keys `MyApp` on the
/// active space id, every per-space controller is torn down and rebuilt, and
/// the outgoing widget tree is disposed. There is therefore no moment when both
/// spaces exist to animate between — the old one is gone before the new one can
/// draw.
///
/// So the outgoing space is kept as a picture. The frame is rasterised straight
/// off its repaint boundary at the moment the switch begins
/// ([RenderRepaintBoundary.toImageSync] — no async gap, no dropped frame), and
/// that snapshot is what slides away while the freshly built space slides in
/// beside it. The two move as one joined surface, so the gesture reads as
/// pushing a pane aside rather than watching a cut.
class SpaceSwitchTransition extends StatefulWidget {
  const SpaceSwitchTransition({super.key, required this.child});

  final Widget child;

  /// The nearest transition, or null outside one — a bare shell in a test, for
  /// instance. Callers treat null as "switch without animating".
  static SpaceSwitchTransitionState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<SpaceSwitchTransitionState>();

  @override
  State<SpaceSwitchTransition> createState() => SpaceSwitchTransitionState();
}

enum _Phase {
  /// Nothing going on — the child is rendered untouched.
  idle,

  /// A finger is moving the space, with resistance: there is nothing behind to
  /// reveal yet, so it gives a little rather than tracking one-to-one.
  dragging,

  /// The drag was let go short of the threshold; sliding back to rest.
  springingBack,

  /// Committed: the snapshot leaves while the new space arrives.
  switching,
}

class SpaceSwitchTransitionState extends State<SpaceSwitchTransition>
    with SingleTickerProviderStateMixin {
  /// How much of the drag distance the space actually moves while the gesture
  /// is still undecided. Full tracking would open a gap to nothing.
  static const double _dragResistance = 0.3;

  final GlobalKey _boundaryKey = GlobalKey();

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  _Phase _phase = _Phase.idle;

  /// The space being left, frozen at the moment the switch began.
  ui.Image? _outgoing;

  /// +1 when moving to the next space (content travels left), -1 for previous.
  int _direction = 1;

  /// Horizontal offset the content sits at right now, in logical pixels. During
  /// a drag this is the finger; afterwards the controller interpolates from it.
  double _offset = 0;

  /// Offset the animation started from, so it can continue the drag's movement
  /// instead of snapping to a fresh origin.
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
  }

  @override
  void dispose() {
    _controller.dispose();
    _outgoing?.dispose();
    super.dispose();
  }

  void _onTick() => setState(() {});

  double get _width =>
      mounted ? MediaQuery.sizeOf(context).width : 0;

  /// Rasterises the current frame. False when there is nothing paintable to
  /// capture — before the first frame, or in a test — so the caller can fall
  /// back to switching outright rather than dropping the switch.
  bool _captureOutgoing() {
    final object = _boundaryKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return false;
    if (object.debugNeedsPaint) return false;
    _outgoing?.dispose();
    _outgoing = object.toImageSync(
      pixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0,
    );
    return true;
  }

  /// Moves the space with the finger. [fraction] is signed and measured in
  /// screen widths: positive drags towards the next space (content goes left).
  void dragTo(double fraction) {
    if (_phase == _Phase.switching) return;
    final clamped = fraction.clamp(-1.0, 1.0);
    setState(() {
      _phase = _Phase.dragging;
      _offset = -clamped * _width * _dragResistance;
    });
  }

  /// Lets go without committing: slide back to rest.
  void cancelDrag() {
    if (_phase != _Phase.dragging) return;
    if (_offset.abs() < 0.5) {
      setState(() {
        _phase = _Phase.idle;
        _offset = 0;
      });
      return;
    }
    _from = _offset;
    setState(() => _phase = _Phase.springingBack);
    _controller
      ..value = 0
      ..animateTo(1.0,
              duration: const Duration(milliseconds: 180), curve: Curves.easeOut)
          .whenComplete(() {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.idle;
          _offset = 0;
        });
      });
  }

  /// Commits the switch: freezes this space, hands [switchSpace] the job of
  /// building the next, and slides the two past each other. Runs the animation
  /// whether or not the capture worked, so callers never have to check.
  Future<void> run({
    required int direction,
    required Future<void> Function() switchSpace,
  }) async {
    _direction = direction;
    _from = _offset;
    final captured = _captureOutgoing();
    if (captured) {
      setState(() => _phase = _Phase.switching);
      _controller
        ..value = 0
        ..animateTo(1.0, curve: Curves.easeOutCubic).whenComplete(() {
          if (!mounted) return;
          setState(() {
            _phase = _Phase.idle;
            _offset = 0;
            _outgoing?.dispose();
            _outgoing = null;
          });
        });
    } else {
      setState(() {
        _phase = _Phase.idle;
        _offset = 0;
      });
    }
    await switchSpace();
  }

  @override
  Widget build(BuildContext context) {
    final content = RepaintBoundary(key: _boundaryKey, child: widget.child);
    if (_phase == _Phase.idle) return content;

    final width = _width;
    final t = _controller.value;
    final double contentDx;
    final double outgoingDx;

    switch (_phase) {
      case _Phase.dragging:
        contentDx = _offset;
        outgoingDx = 0;
      case _Phase.springingBack:
        contentDx = _from * (1 - t);
        outgoingDx = 0;
      case _Phase.switching:
        // The snapshot carries on from where the drag left it and exits; the
        // new space rides one screen behind it, arriving as it goes.
        outgoingDx = _from + (-_direction * width - _from) * t;
        contentDx = outgoingDx + _direction * width;
      case _Phase.idle:
        contentDx = 0;
        outgoingDx = 0;
    }

    return Stack(
      // This sits above CupertinoApp — the app is what *provides*
      // Directionality, so nothing here may ask for it. Stack's default
      // alignment is AlignmentDirectional.topStart, which does.
      alignment: Alignment.topLeft,
      fit: StackFit.expand,
      children: [
        // Backdrop for the sliver of screen neither space covers mid-slide.
        ColoredBox(
          color: CupertinoColors.systemBackground.resolveFrom(context),
        ),
        Transform.translate(offset: Offset(contentDx, 0), child: content),
        if (_outgoing != null)
          Transform.translate(
            offset: Offset(outgoingDx, 0),
            // The frozen space must not answer taps aimed at the live one.
            child: IgnorePointer(
              child: RawImage(
                image: _outgoing,
                width: width,
                height: MediaQuery.sizeOf(context).height,
                fit: BoxFit.fill,
              ),
            ),
          ),
      ],
    );
  }

  /// Test hooks: the current offset, and whether a frozen space is on screen.
  @visibleForTesting
  double get debugOffset => _phase == _Phase.idle
      ? 0
      : (_phase == _Phase.switching
          ? _from + (-_direction * _width - _from) * _controller.value
          : _offset * (_phase == _Phase.springingBack ? 0 : 1));

  @visibleForTesting
  bool get debugIsMoving => _phase != _Phase.idle;

  @visibleForTesting
  bool get debugHasSnapshot => _outgoing != null;
}
