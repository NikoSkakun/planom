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
  // until they dismiss the bar by scrolling the list down or by opening
  // the search screen.
  bool _locked = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _onNotification(ScrollNotification n) {
    if (_opening) return false;
    if (n.metrics.axis != Axis.vertical) return false;

    if (n is OverscrollNotification) {
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
      } else if (pixels > minExtent && _ctrl.value > 0 && !_locked) {
        // User scrolled the list down past the top → dismiss the unlatched
        // reveal in progress. The latched (post-release) state is locked
        // so a small bounce doesn't tear it away.
        _accumulated = 0;
        _ctrl.reverse();
      }
    } else if (n is ScrollEndNotification) {
      // Pull-and-release: latch the bar fully open once the user has
      // committed to revealing it (≥ 30 % of the threshold). Matches the
      // Mail / Notes / TickTick pattern where the search bar stays put
      // after a pull and waits for an explicit tap (or a downward scroll,
      // handled above) to disappear. Anything less is treated as an
      // accidental tug and snaps back.
      if (_ctrl.value >= 0.3) {
        _locked = true;
        _ctrl.forward();
      } else {
        _accumulated = 0;
        _locked = false;
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
