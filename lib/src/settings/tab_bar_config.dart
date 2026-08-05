import 'dart:convert';

/// What a single tab on the tab bar represents.
///
/// - [builtin] — one of the app's own tabs (Tasks/Notes/Calendar/Routines/
///   Settings/Finance/Goals) identified by [builtinIndex] 0..6.
/// - [shortcut] — direct navigation target chosen by the user (a list,
///   folder, smart list, or note folder) identified by [shortcutTarget] +
///   [shortcutId].
enum TabKind { builtin, shortcut }

/// Where a shortcut tab takes the user when tapped.
enum ShortcutTarget {
  list,
  folder,
  smartInbox,
  smartToday,
  smartTomorrow,
  smartUpcoming,
  smartAllTasks,
  smartCompleted,
  smartTrash,
  noteFolder,
}

/// One item in the tab bar.
class TabItem {
  TabItem.builtin(this.builtinIndex, {this.enabled = true})
      : kind = TabKind.builtin,
        shortcutTarget = null,
        shortcutId = null,
        customLabel = null;

  TabItem.shortcut({
    required this.shortcutTarget,
    this.shortcutId,
    this.customLabel,
    this.enabled = true,
  })  : kind = TabKind.shortcut,
        builtinIndex = null;

  final TabKind kind;
  final int? builtinIndex; // 0..6 when kind == builtin
  final ShortcutTarget? shortcutTarget; // non-null when kind == shortcut
  final String? shortcutId; // list/folder/note-folder id; null for smart lists
  final String? customLabel;

  /// Whether this tab is shown in the live tab bar. Disabled tabs stay in the
  /// config (so the user can re-enable them) but are filtered out of the
  /// rendered bar / sidebar via [TabBarConfig.active].
  final bool enabled;

  /// Returns a copy with [enabled] overridden.
  TabItem copyWithEnabled(bool value) {
    if (kind == TabKind.builtin) {
      return TabItem.builtin(builtinIndex!, enabled: value);
    }
    return TabItem.shortcut(
      shortcutTarget: shortcutTarget!,
      shortcutId: shortcutId,
      customLabel: customLabel,
      enabled: value,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        if (builtinIndex != null) 'builtinIndex': builtinIndex,
        if (shortcutTarget != null) 'shortcutTarget': shortcutTarget!.name,
        if (shortcutId != null) 'shortcutId': shortcutId,
        if (customLabel != null) 'customLabel': customLabel,
        // Only persist when disabled — keeps existing layouts byte-compatible.
        if (!enabled) 'enabled': false,
      };

  static TabItem? fromJson(Map<String, dynamic> map) {
    final kindStr = map['kind'] as String?;
    final enabled = map['enabled'] != false; // default true
    if (kindStr == 'builtin') {
      final idx = map['builtinIndex'] as int?;
      if (idx == null || idx < 0 || idx > 6) return null;
      return TabItem.builtin(idx, enabled: enabled);
    }
    if (kindStr == 'shortcut') {
      final targetStr = map['shortcutTarget'] as String?;
      final target = ShortcutTarget.values
          .firstWhere((t) => t.name == targetStr, orElse: () => ShortcutTarget.list);
      return TabItem.shortcut(
        shortcutTarget: target,
        shortcutId: map['shortcutId'] as String?,
        customLabel: map['customLabel'] as String?,
        enabled: enabled,
      );
    }
    return null;
  }
}

/// Ordered, paged tab bar layout. Each inner list is one swipeable page;
/// pages contain at most [maxItemsPerPage] tabs.
class TabBarConfig {
  TabBarConfig({required this.pages});

  static const int maxItemsPerPage = 7;

  /// Default config = single page holding every built-in tab.
  factory TabBarConfig.defaultLayout() => TabBarConfig(pages: [
        [
          TabItem.builtin(0),
          TabItem.builtin(1),
          TabItem.builtin(2),
          TabItem.builtin(3),
          TabItem.builtin(5),
          TabItem.builtin(6),
          TabItem.builtin(4),
        ],
      ]);

  /// Every built-in tab the app ships today, in the order they should appear.
  /// Settings (4) is last by convention even though newer tabs have higher
  /// indices — indices are never renumbered because they are persisted.
  static const List<int> allBuiltins = [0, 1, 2, 3, 5, 6, 4];

  /// The built-ins that existed before [allBuiltins] started growing. Used to
  /// seed the "already offered to this user" set the first time a layout saved
  /// by an older build is opened, so tabs the user deliberately removed stay
  /// removed while genuinely new ones get surfaced once.
  static const List<int> legacyBuiltins = [0, 1, 2, 3, 4];

  /// Returns this config with [index] added to the first page, in front of the
  /// Settings tab when it's there. Used to surface a newly-shipped built-in
  /// tab in a layout the user saved before it existed. A no-op when the tab is
  /// already somewhere in the config or every page is full.
  TabBarConfig withBuiltinSurfaced(int index) {
    if (flattened.any(
        (it) => it.kind == TabKind.builtin && it.builtinIndex == index)) {
      return this;
    }
    for (var page = 0; page < pages.length; page++) {
      if (pages[page].length >= maxItemsPerPage) continue;
      final items = [...pages[page]];
      final settingsAt = items.indexWhere(
          (it) => it.kind == TabKind.builtin && it.builtinIndex == 4);
      items.insert(
          settingsAt >= 0 ? settingsAt : items.length, TabItem.builtin(index));
      return setPage(page, items);
    }
    // Every page is full — give the new tab a page of its own rather than
    // dropping it silently.
    return addPage().let((cfg) =>
        cfg.setPage(cfg.pages.length - 1, [TabItem.builtin(index)]));
  }

  /// Migration helper: builds a single-page config from the legacy
  /// `tabVisibility` + `tabOrder` settings. Tabs added after that scheme was
  /// retired (Finance, Goals) are appended when the legacy order predates
  /// them, so upgrading users see the new tabs instead of having to add them
  /// by hand.
  factory TabBarConfig.fromLegacy({
    required Map<int, bool> tabVisibility,
    required List<int> tabOrder,
  }) {
    final order = [...tabOrder];
    for (final added in const [5, 6]) {
      if (order.contains(added)) continue;
      // Settings conventionally sits last, so slot new tabs in front of it.
      final settingsIdx = order.indexOf(4);
      if (settingsIdx >= 0) {
        order.insert(settingsIdx, added);
      } else {
        order.add(added);
      }
    }
    final visible = order.where((i) => tabVisibility[i] ?? true).toList();
    if (visible.isEmpty) return TabBarConfig.defaultLayout();
    return TabBarConfig(pages: [
      [for (final i in visible) TabItem.builtin(i)],
    ]);
  }

  final List<List<TabItem>> pages;

  /// All tabs flattened in display order (used for sidebar layout where
  /// pages are not meaningful).
  List<TabItem> get flattened => [for (final p in pages) ...p];

  /// The layout actually rendered in the tab bar: disabled items removed from
  /// every page (pages may become empty — the shell skips empty pages).
  TabBarConfig get active => TabBarConfig(
        pages: [
          for (final p in pages) [for (final it in p) if (it.enabled) it],
        ],
      );

  String toJsonString() => jsonEncode(
        pages
            .map((p) => p.map((it) => it.toJson()).toList())
            .toList(),
      );

  static TabBarConfig? tryParse(String raw) {
    try {
      final outer = jsonDecode(raw) as List<dynamic>;
      final pages = <List<TabItem>>[];
      for (final p in outer) {
        final inner = <TabItem>[];
        for (final raw in (p as List<dynamic>)) {
          final item = TabItem.fromJson(raw as Map<String, dynamic>);
          if (item != null) inner.add(item);
        }
        if (inner.length > maxItemsPerPage) {
          inner.removeRange(maxItemsPerPage, inner.length);
        }
        if (inner.isNotEmpty) pages.add(inner);
      }
      if (pages.isEmpty) return null;
      return TabBarConfig(pages: pages);
    } catch (_) {
      return null;
    }
  }

  TabBarConfig addPage() => TabBarConfig(
        pages: [...pages, <TabItem>[]],
      );

  TabBarConfig removePage(int index) {
    if (pages.length <= 1) return this; // never empty
    final next = [...pages]..removeAt(index);
    return TabBarConfig(pages: next);
  }

  TabBarConfig setPage(int index, List<TabItem> items) {
    if (index < 0 || index >= pages.length) return this;
    final clamped = items.length > maxItemsPerPage
        ? items.sublist(0, maxItemsPerPage)
        : items;
    final next = [...pages];
    next[index] = clamped;
    return TabBarConfig(pages: next);
  }

  TabBarConfig addItemToPage(int pageIndex, TabItem item) {
    if (pageIndex < 0 || pageIndex >= pages.length) return this;
    final page = pages[pageIndex];
    if (page.length >= maxItemsPerPage) return this;
    return setPage(pageIndex, [...page, item]);
  }

  /// Toggles the [enabled] flag of the item at [itemIndex] on [pageIndex].
  TabBarConfig setItemEnabled(int pageIndex, int itemIndex, bool enabled) {
    if (pageIndex < 0 || pageIndex >= pages.length) return this;
    final page = [...pages[pageIndex]];
    if (itemIndex < 0 || itemIndex >= page.length) return this;
    page[itemIndex] = page[itemIndex].copyWithEnabled(enabled);
    return setPage(pageIndex, page);
  }

  TabBarConfig removeItem(int pageIndex, int itemIndex) {
    if (pageIndex < 0 || pageIndex >= pages.length) return this;
    final page = [...pages[pageIndex]];
    if (itemIndex < 0 || itemIndex >= page.length) return this;
    page.removeAt(itemIndex);
    return setPage(pageIndex, page);
  }

  /// Moves the item at [oldIndex] to [newIndex] within [pageIndex]. [newIndex]
  /// is expected to already be adjusted for the removal (i.e. the standard
  /// `ReorderableListView` convention where the caller decrements it when
  /// moving an item further down the list).
  TabBarConfig reorderItem(int pageIndex, int oldIndex, int newIndex) {
    if (pageIndex < 0 || pageIndex >= pages.length) return this;
    final page = [...pages[pageIndex]];
    if (oldIndex < 0 || oldIndex >= page.length) return this;
    final item = page.removeAt(oldIndex);
    final insertAt = newIndex.clamp(0, page.length);
    page.insert(insertAt, item);
    return setPage(pageIndex, page);
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) fn) => fn(this);
}
