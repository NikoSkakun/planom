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
  // True while a user-initiated drag is in flight. We use this to tell a
  // genuine upward swipe (which should dismiss the bar) apart from the
  // ballistic bounce-back that runs after a pull release.
  bool _userDragging = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _onNotification(ScrollNotification n) {
    if (_opening) return false;
    if (n.metrics.axis != Axis.vertical) return false;

    if (n is ScrollStartNotification) {
      // dragDetails is non-null only for finger-driven scrolls; ballistic
      // simulations leave it null. That distinction is exactly what lets a
      // real upward swipe dismiss the latched bar while the bounce-back
      // after a pull-release does not.
      _userDragging = n.dragDetails != null;
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
        // Only grow the reveal during a pull — never let an in-flight bounce
        // back collapse the bar that the user already revealed.
        final next = (_accumulated / _revealDistance).clamp(0.0, 1.0);
        if (next > _ctrl.value) _ctrl.value = next;
      } else if (pixels > minExtent && _ctrl.value > 0) {
        // The bar is visible and the list has scrolled past the top. If
        // this is an unlatched in-progress reveal, dismiss it on any
        // forward scroll. If the bar is latched, only dismiss when the
        // scroll is finger-driven (a real upward swipe) — the ballistic
        // bounce after release is not.
        if (!_locked || _userDragging) {
          _accumulated = 0;
          _locked = false;
          _ctrl.reverse();
        }
      }
    } else if (n is ScrollEndNotification) {
      _userDragging = false;
      // Pull-and-release: latch the bar fully open once the user has
      // committed to revealing it (≥ 30 % of the threshold). Matches the
      // Mail / Notes / TickTick pattern where the search bar stays put
      // after a pull and waits for an explicit upward swipe (or a tap on
      // the bar) to disappear. Anything less is treated as an accidental
      // tug and snaps back.
      if (_ctrl.value >= 0.3) {
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
        return Column(
          children: [
            ClipRect(
              child: SizedBox(
                height: 48 * reveal,
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
