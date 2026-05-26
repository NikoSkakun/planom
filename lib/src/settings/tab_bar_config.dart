import 'dart:convert';

/// What a single tab on the tab bar represents.
///
/// - [builtin] — one of the 5 historical tabs (Tasks/Notes/Calendar/Routines/
///   Settings) identified by [builtinIndex] 0..4.
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
  TabItem.builtin(this.builtinIndex)
      : kind = TabKind.builtin,
        shortcutTarget = null,
        shortcutId = null,
        customLabel = null;

  TabItem.shortcut({
    required this.shortcutTarget,
    this.shortcutId,
    this.customLabel,
  })  : kind = TabKind.shortcut,
        builtinIndex = null;

  final TabKind kind;
  final int? builtinIndex; // 0..4 when kind == builtin
  final ShortcutTarget? shortcutTarget; // non-null when kind == shortcut
  final String? shortcutId; // list/folder/note-folder id; null for smart lists
  final String? customLabel;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        if (builtinIndex != null) 'builtinIndex': builtinIndex,
        if (shortcutTarget != null) 'shortcutTarget': shortcutTarget!.name,
        if (shortcutId != null) 'shortcutId': shortcutId,
        if (customLabel != null) 'customLabel': customLabel,
      };

  static TabItem? fromJson(Map<String, dynamic> map) {
    final kindStr = map['kind'] as String?;
    if (kindStr == 'builtin') {
      final idx = map['builtinIndex'] as int?;
      if (idx == null || idx < 0 || idx > 4) return null;
      return TabItem.builtin(idx);
    }
    if (kindStr == 'shortcut') {
      final targetStr = map['shortcutTarget'] as String?;
      final target = ShortcutTarget.values
          .firstWhere((t) => t.name == targetStr, orElse: () => ShortcutTarget.list);
      return TabItem.shortcut(
        shortcutTarget: target,
        shortcutId: map['shortcutId'] as String?,
        customLabel: map['customLabel'] as String?,
      );
    }
    return null;
  }
}

/// Ordered, paged tab bar layout. Each inner list is one swipeable page;
/// pages contain at most [maxItemsPerPage] tabs.
class TabBarConfig {
  TabBarConfig({required this.pages});

  static const int maxItemsPerPage = 5;

  /// Default config = single page mirroring the historical 5 built-in tabs.
  factory TabBarConfig.defaultLayout() => TabBarConfig(pages: [
        [
          TabItem.builtin(0),
          TabItem.builtin(1),
          TabItem.builtin(2),
          TabItem.builtin(3),
          TabItem.builtin(4),
        ],
      ]);

  /// Migration helper: builds a single-page config from the legacy
  /// `tabVisibility` + `tabOrder` settings.
  factory TabBarConfig.fromLegacy({
    required Map<int, bool> tabVisibility,
    required List<int> tabOrder,
  }) {
    final visible = tabOrder.where((i) => tabVisibility[i] ?? true).toList();
    if (visible.isEmpty) return TabBarConfig.defaultLayout();
    return TabBarConfig(pages: [
      [for (final i in visible) TabItem.builtin(i)],
    ]);
  }

  final List<List<TabItem>> pages;

  /// All tabs flattened in display order (used for sidebar layout where
  /// pages are not meaningful).
  List<TabItem> get flattened => [for (final p in pages) ...p];

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

  TabBarConfig removeItem(int pageIndex, int itemIndex) {
    if (pageIndex < 0 || pageIndex >= pages.length) return this;
    final page = [...pages[pageIndex]];
    if (itemIndex < 0 || itemIndex >= page.length) return this;
    page.removeAt(itemIndex);
    return setPage(pageIndex, page);
  }
}
