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

  /// Full height of the revealed bar (including outer padding).
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
  // True once a latched bar has started collapsing under an upward swipe.
  // Lets the fling's ballistic follow-through keep collapsing the bar and
  // tells ScrollEnd to settle the dismissal instead of re-latching.
  bool _dismissing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _onNotification(ScrollNotification n) {
    if (_opening) return false;
    if (n.metrics.axis != Axis.vertical) return false;

    // dragDetails is non-null only for finger-driven scrolls; ballistic
    // simulations leave it null. That distinction is what lets a real
    // upward swipe collapse the latched bar while the bounce-back after a
    // pull-release does not.
    if (n is ScrollStartNotification) {
      _dismissing = false;
    } else if (n is OverscrollNotification) {
      // ClampingScrollPhysics: scrolling past the boundary emits an
      // OverscrollNotification with negative overscroll at the top.
      if (n.overscroll < 0) {
        _accumulated += -n.overscroll;
        _ctrl.value = (_accumulated / _revealDistance).clamp(0.0, 1.0);
      }
    } else if (n is ScrollUpdateNotification) {
      // BouncingScrollPhysics (iOS default): the position glides past the
      // top boundary instead of overscrolling — pixels < minScrollExtent.
      // Track that as the pull amount, otherwise the reveal animation
      // never makes progress on iOS.
      final pixels = n.metrics.pixels;
      final minExtent = n.metrics.minScrollExtent;
      if (pixels < minExtent) {
        _accumulated = minExtent - pixels;
        final next = (_accumulated / _revealDistance).clamp(0.0, 1.0);
        if (!_locked && n.dragDetails != null) {
          // Finger-driven pull: track it in both directions, so easing
          // the pull back shrinks the bar exactly the way it grew.
          _ctrl.value = next;
        } else if (next > _ctrl.value) {
          // Ballistic bounce-back after release: only grow — never let it
          // collapse the bar the user already revealed.
          _ctrl.value = next;
        }
      } else if (pixels > minExtent && _ctrl.value > 0) {
        // The bar is visible and the list has scrolled past the top.
        final delta = n.scrollDelta ?? 0;
        if (_locked && delta > 0 && (n.dragDetails != null || _dismissing)) {
          // Upward swipe on a latched bar: collapse it in step with the
          // scroll — the reverse of the pull that revealed it. Once the
          // dismissal has begun, the fling's ballistic follow-through
          // keeps collapsing it too.
          _dismissing = true;
          _ctrl.value =
              (_ctrl.value - delta / _revealDistance).clamp(0.0, 1.0);
          if (_ctrl.value == 0) {
            _accumulated = 0;
            _locked = false;
            _dismissing = false;
          }
        } else if (!_locked) {
          // Unlatched in-progress reveal: dismiss on any forward scroll.
          _accumulated = 0;
          _ctrl.reverse();
        }
      }
    } else if (n is ScrollEndNotification) {
      if (_dismissing) {
        // Finger lifted mid-dismissal: settle the bar the same way a drag
        // on the bar itself does — mostly collapsed snaps shut, otherwise
        // it springs back open.
        _dismissing = false;
        if (_ctrl.value < 0.5) {
          _accumulated = 0;
          _locked = false;
          _ctrl.reverse();
        } else {
          _ctrl.forward();
        }
      } else if (_ctrl.value >= 0.3) {
        // Pull-and-release: latch the bar fully open once the user has
        // committed to revealing it (≥ 30 % of the threshold). Matches the
        // Mail / Notes / TickTick pattern where the search bar stays put
        // after a pull and waits for an explicit upward swipe (or a tap on
        // the bar) to disappear. Anything less is treated as an accidental
        // tug and snaps back.
        _locked = true;
        _ctrl.forward();
      } else if (_ctrl.value > 0 && !_locked) {
        _accumulated = 0;
        _ctrl.reverse();
      } else if (!_locked) {
        _accumulated = 0;
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final reveal = _ctrl.value;
        // The icon + placeholder only fade in once the bar is tall enough
        // to show them fully; until then the empty pill slides into view.
        final contentOpacity = ((reveal - _contentFadeStart) /
                (1.0 - _contentFadeStart))
            .clamp(0.0, 1.0);
        return Column(
          children: [
            // The pill stretches vertically with the pull (and squashes
            // back on dismissal); only the icon + placeholder wait for
            // enough space before fading in.
            ClipRect(
              child: SizedBox(
                height: _barHeight * reveal,
                child: Opacity(
                  opacity: reveal,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _openSearch,
                      onVerticalDragUpdate: _onBarDragUpdate,
                      onVerticalDragEnd: _onBarDragEnd,
                      child: Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.tertiarySystemFill
                              .resolveFrom(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        child: Opacity(
                          opacity: contentOpacity,
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.search,
                                size: 16,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                s.searchPlaceholder,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
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
