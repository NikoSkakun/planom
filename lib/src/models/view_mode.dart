/// How a list or folder renders its contents.
enum ItemViewMode {
  list,
  kanban;

  String get value => name;

  static ItemViewMode fromString(String? v) {
    switch (v) {
      case 'kanban':
        return ItemViewMode.kanban;
      case 'list':
      default:
        return ItemViewMode.list;
    }
  }
}

/// How the Kanban board scrolls horizontally.
///
/// * [snap] — each horizontal swipe snaps to the next/previous column
///   (paged). This is the default.
/// * [free] — continuous free horizontal scrolling.
enum KanbanScrollMode {
  snap,
  free;

  String get value => name;

  static KanbanScrollMode fromString(String? v) {
    switch (v) {
      case 'free':
        return KanbanScrollMode.free;
      case 'snap':
      default:
        return KanbanScrollMode.snap;
    }
  }
}
