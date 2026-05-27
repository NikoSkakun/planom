import 'package:flutter/cupertino.dart';

/// Drop-in replacement for `ListView.builder` over a list of items keyed by
/// stable string ids. Diffs the previous and next id sequences on each
/// rebuild and drives the matching insert / remove animations on the
/// underlying [AnimatedList] so tasks that change position (e.g. one
/// getting checked off and rolling to the bottom of a smart list) slide
/// out of their old slot and slide in at the new one — the surrounding
/// rows shift smoothly to close the gap instead of jumping.
///
/// The diff is LCS-based: items that remain in the same relative order
/// stay in place and only the actual movers run an exit/enter animation.
class AnimatedItemList<T> extends StatefulWidget {
  const AnimatedItemList({
    super.key,
    required this.items,
    required this.idOf,
    required this.itemBuilder,
    this.padding,
    this.duration = const Duration(milliseconds: 220),
    this.shrinkWrap = false,
    this.physics,
  });

  final List<T> items;

  /// Stable id used to match items across rebuilds.
  final String Function(T item) idOf;

  /// Build a row for [item] at its current position.
  final Widget Function(BuildContext context, T item) itemBuilder;

  final EdgeInsetsGeometry? padding;
  final Duration duration;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  State<AnimatedItemList<T>> createState() => _AnimatedItemListState<T>();
}

class _AnimatedItemListState<T> extends State<AnimatedItemList<T>> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<T> _items;

  @override
  void initState() {
    super.initState();
    _items = List<T>.of(widget.items);
  }

  @override
  void didUpdateWidget(covariant AnimatedItemList<T> old) {
    super.didUpdateWidget(old);
    _diff(widget.items);
  }

  void _diff(List<T> next) {
    final state = _listKey.currentState;
    if (state == null) {
      _items = List<T>.of(next);
      return;
    }
    final oldIds = _items.map(widget.idOf).toList(growable: false);
    final newIds = next.map(widget.idOf).toList(growable: false);
    final newIdSet = newIds.toSet();

    // Items that survive — same id, same relative position — are picked
    // out via LCS so only the real movers run an animation.
    final lcsOldIdx = _lcsIndices(oldIds, newIds);
    final keepIds = <String>{
      for (final i in lcsOldIdx) oldIds[i],
    };

    // Pass 1: remove every item that isn't part of the LCS, back to
    // front so earlier indices stay valid. Items that are leaving the
    // list entirely (e.g. swipe-to-delete just fired) skip the exit
    // animation — Dismissible already played one and a second collapse
    // would briefly snap the row back to full height before shrinking.
    for (int i = _items.length - 1; i >= 0; i--) {
      final id = widget.idOf(_items[i]);
      if (!keepIds.contains(id)) {
        final removed = _items.removeAt(i);
        final stillInList = newIdSet.contains(id);
        if (stillInList) {
          state.removeItem(
            i,
            (ctx, anim) => _buildRemoved(ctx, removed, anim),
            duration: widget.duration,
          );
        } else {
          state.removeItem(
            i,
            (_, __) => const SizedBox.shrink(),
            duration: Duration.zero,
          );
        }
      }
    }

    // Pass 2: walk forward and insert anything missing at its new
    // position. Items already in the LCS get an in-place data refresh.
    for (int i = 0; i < next.length; i++) {
      final nextItem = next[i];
      final id = widget.idOf(nextItem);
      final currentIdx = _items.indexWhere((it) => widget.idOf(it) == id);
      if (currentIdx == -1) {
        _items.insert(i, nextItem);
        state.insertItem(i, duration: widget.duration);
      } else {
        _items[i] = nextItem;
      }
    }
  }

  /// Returns the indices into [a] that form one of the longest common
  /// subsequences with [b]. Items at the returned indices stay in place
  /// during the diff; everything else gets a remove/insert pair.
  static List<int> _lcsIndices(List<String> a, List<String> b) {
    final m = a.length;
    final n = b.length;
    if (m == 0 || n == 0) return const [];
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] >= dp[i][j - 1]
              ? dp[i - 1][j]
              : dp[i][j - 1];
        }
      }
    }
    final out = <int>[];
    int i = m, j = n;
    while (i > 0 && j > 0) {
      if (a[i - 1] == b[j - 1]) {
        out.add(i - 1);
        i--;
        j--;
      } else if (dp[i - 1][j] >= dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }
    return out.reversed.toList(growable: false);
  }

  Widget _buildRemoved(BuildContext context, T item, Animation<double> anim) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: anim,
        child: widget.itemBuilder(context, item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      initialItemCount: _items.length,
      itemBuilder: (context, index, animation) {
        if (index >= _items.length) return const SizedBox.shrink();
        return SizeTransition(
          sizeFactor:
              CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          axisAlignment: -1.0,
          child: FadeTransition(
            opacity: animation,
            child: widget.itemBuilder(context, _items[index]),
          ),
        );
      },
    );
  }
}
