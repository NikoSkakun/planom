import 'package:flutter/cupertino.dart';

import '../calendar/event_controller.dart';
import '../database/database_service.dart';
import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../notes/note_controller.dart';
import '../tasks/task_controller.dart';
import '../utils/fast_route.dart';
import 'search_view.dart';

/// Wraps a scrollable view so that pulling it down at the top exposes a
/// search bar; once the bar is fully revealed the full search screen is
/// pushed. Matches the TickTick / Things 3 pull-to-search gesture.
class SearchPullScope extends StatefulWidget {
  const SearchPullScope({
    super.key,
    required this.child,
    required this.db,
    required this.taskController,
    required this.folderController,
    required this.noteController,
    required this.eventController,
  });

  final Widget child;
  final DatabaseService db;
  final TaskController taskController;
  final FolderController folderController;
  final NoteController noteController;
  final EventController eventController;

  @override
  State<SearchPullScope> createState() => _SearchPullScopeState();
}

class _SearchPullScopeState extends State<SearchPullScope>
    with SingleTickerProviderStateMixin {
  /// Pixels of overscroll required to fully reveal the bar.
  static const double _revealDistance = 56.0;

  /// Full height of the revealed bar (vertical margins + the 36 px
  /// intrinsic height of a stock [CupertinoSearchTextField]).
  static const double _barHeight = 48.0;

  /// Reveal fraction below which the icon + placeholder stay invisible.
  /// They fade in only over the last stretch of the reveal, once the bar
  /// is tall enough to show them without clipping — and fade out first
  /// on the way back.
  static const double _contentFadeStart = 0.6;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  double _accumulated = 0;
  bool _opening = false;
  // Latched true once the user releases a finger after a pull. Stays true
  // until they dismiss the bar by swiping the list up or by opening the
  // search screen.
  bool _locked = false;
  // True while a finger-driven pull is revealing the bar. Lets the first
  // ballistic frame after the release settle the bar immediately instead
  // of waiting for the bounce-back to finish.
  bool _pulling = false;
  // True once a latched bar has started collapsing under an upward swipe.
  bool _dismissing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// The live scroll position of the scrollable that emitted [n], used to
  /// compensate the scroll while the bar absorbs a dismissal swipe.
  ScrollPosition? _positionOf(ScrollNotification n) {
    final ctx = n.context;
    if (ctx == null) return null;
    return ctx.findAncestorStateOfType<ScrollableState>()?.position;
  }

  /// Finger released after a pull: latch the bar fully open once the user
  /// has committed to revealing it (≥ 30 % of the threshold). Matches the
  /// Mail / Notes / TickTick pattern where the search bar stays put after
  /// a pull and waits for an explicit upward swipe (or a tap on the bar)
  /// to disappear. Anything less is treated as an accidental tug and
  /// snaps back. Runs on the first ballistic frame after the release, so
  /// the animation continues without a pause.
  void _settleReveal() {
    _pulling = false;
    if (_ctrl.value >= 0.3) {
      _locked = true;
      _ctrl.forward();
    } else {
      _accumulated = 0;
      _ctrl.reverse();
    }
  }

  /// Finger released mid-dismissal. A fling that keeps scrolling upward
  /// always finishes the collapse; otherwise a mostly-collapsed bar snaps
  /// shut and anything else springs back open — the same rule as a drag
  /// on the bar itself.
  void _settleDismiss({required bool continuingUp}) {
    _dismissing = false;
    if (continuingUp || _ctrl.value < 0.5) {
      _accumulated = 0;
      _locked = false;
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
  }

  bool _onNotification(ScrollNotification n) {
    if (_opening) return false;
    if (n.metrics.axis != Axis.vertical) return false;

    if (n is ScrollStartNotification) {
      _dismissing = false;
      if (!_locked && _ctrl.value == 0) _accumulated = 0;
    } else if (n is OverscrollNotification) {
      // ClampingScrollPhysics: scrolling past the boundary emits an
      // OverscrollNotification with negative overscroll at the top.
      if (n.overscroll < 0 && !_locked) {
        _pulling = true;
        _accumulated += -n.overscroll;
        _ctrl.value = (_accumulated / _revealDistance).clamp(0.0, 1.0);
      }
    } else if (n is ScrollUpdateNotification) {
      // BouncingScrollPhysics (iOS default): the position glides past the
      // top boundary instead of overscrolling — pixels < minScrollExtent.
      // dragDetails is non-null only for finger-driven updates; ballistic
      // simulations leave it null.
      final pixels = n.metrics.pixels;
      final minExtent = n.metrics.minScrollExtent;
      final finger = n.dragDetails != null;
      final delta = n.scrollDelta ?? 0;

      if (_locked && finger && delta != 0) {
        // Latched bar + finger scroll: the bar absorbs the swipe. An
        // upward swipe collapses it in step with the finger, a downward
        // one grows it back; the consumed scroll is compensated away so
        // the list stays pinned at the top until the bar is gone (no
        // rows sliding underneath it).
        final prev = _ctrl.value;
        final next = (prev - delta / _revealDistance).clamp(0.0, 1.0);
        if (next != prev) {
          _dismissing = next < 1;
          _ctrl.value = next;
          final consumed = (prev - next) * _revealDistance;
          _positionOf(n)?.correctBy(-consumed);
          if (next == 0) {
            _accumulated = 0;
            _locked = false;
            _dismissing = false;
          }
        }
      } else if (pixels < minExtent) {
        if (finger && !_locked) {
          // Finger-driven pull: track it in both directions, so easing
          // the pull back shrinks the bar exactly the way it grew.
          _pulling = true;
          _accumulated = minExtent - pixels;
          _ctrl.value = (_accumulated / _revealDistance).clamp(0.0, 1.0);
        } else if (_pulling && !finger) {
          // First ballistic frame after the release: settle right away —
          // waiting for ScrollEnd would freeze the bar until the
          // bounce-back finishes.
          _settleReveal();
        }
      } else if (_ctrl.value > 0) {
        if (_dismissing && !finger) {
          // Fling released mid-dismissal: finish the collapse while the
          // momentum carries the list.
          _settleDismiss(continuingUp: delta > 0);
        } else if (!_locked && !_pulling && !_ctrl.isAnimating) {
          // Unlatched leftover reveal with the list past the top:
          // dismiss on any forward scroll.
          _accumulated = 0;
          _ctrl.reverse();
        }
      }
    } else if (n is ScrollEndNotification) {
      if (_dismissing) {
        _settleDismiss(continuingUp: false);
      } else if (_pulling) {
        _settleReveal();
      } else if (!_locked && _ctrl.value > 0 && !_ctrl.isAnimating) {
        _accumulated = 0;
        _ctrl.reverse();
      }
    }
    return false;
  }

  Future<void> _openSearch() async {
    _opening = true;
    await Navigator.of(context, rootNavigator: true).push(
      FastRoute<void>(
        builder: (_) => SearchView(
          db: widget.db,
          taskController: widget.taskController,
          folderController: widget.folderController,
          noteController: widget.noteController,
          eventController: widget.eventController,
        ),
      ),
    );
    if (!mounted) return;
    _accumulated = 0;
    _ctrl.value = 0;
    _locked = false;
    _opening = false;
  }

  /// Tracks vertical drag *on the search bar itself*. When the user swipes
  /// up directly on the bar (not on the list below), the scroll listener
  /// never fires, so we collapse the bar here as well.
  void _onBarDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy < 0 && _ctrl.value > 0) {
      // Move the reveal toward 0 proportionally to the upward drag.
      _ctrl.value =
          (_ctrl.value + details.delta.dy / _revealDistance).clamp(0.0, 1.0);
    }
  }

  void _onBarDragEnd(DragEndDetails details) {
    if (_ctrl.value < 0.5) {
      _accumulated = 0;
      _locked = false;
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Mirror the stock CupertinoSearchTextField shown by SearchView
    // (radius 9, tertiarySystemFill, 20 px secondaryLabel icon, themed
    // 17 pt text in systemGrey) so the preview matches the opened screen.
    final placeholderStyle = CupertinoTheme.of(context)
        .textTheme
        .textStyle
        .merge(TextStyle(color: CupertinoColors.systemGrey.resolveFrom(context)));
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final reveal = _ctrl.value;
        // The icon + placeholder only fade in once the bar is tall enough
        // to show them fully; until then the empty pill stretches into view.
        final contentOpacity = ((reveal - _contentFadeStart) /
                (1.0 - _contentFadeStart))
            .clamp(0.0, 1.0);
        return Column(
          children: [
            // The pill stretches vertically with the pull (and squashes
            // back on dismissal).
            ClipRect(
              child: SizedBox(
                height: _barHeight * reveal,
                child: Opacity(
                  opacity: reveal,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _openSearch,
                      onVerticalDragUpdate: _onBarDragUpdate,
                      onVerticalDragEnd: _onBarDragEnd,
                      child: Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.tertiarySystemFill
                              .resolveFrom(context),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: contentOpacity,
                          child: Row(
                            children: [
                              Padding(
                                // The real field's prefixInsets carry a 3 px
                                // bottom offset that compensates for the
                                // editable text's metrics; a plain Text has
                                // none, so the icon centers without it.
                                padding: const EdgeInsetsDirectional.only(
                                    start: 6),
                                child: Icon(
                                  CupertinoIcons.search,
                                  size: 20,
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                              ),
                              const SizedBox(width: 5.5),
                              Expanded(
                                child: Text(
                                  s.searchPlaceholder,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: placeholderStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onNotification,
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}
