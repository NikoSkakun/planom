import 'package:flutter/cupertino.dart';

/// What kind of items the current selection holds. Drives which batch
/// actions are offered and how "Select All" behaves.
enum SelectionItemKind { task, note, folder, list, contact, mixed }

/// Lightweight `ChangeNotifier` that tracks a multi-select state for a
/// view. Each view that supports batch operations owns one of these
/// (created when the user picks "Select" from the ⋯ menu, cleared when
/// they tap Cancel).
class SelectionController extends ChangeNotifier {
  /// Selected item IDs.
  final Set<String> _selected = {};

  /// Selected items' kind. Locked to the first selected item's kind so
  /// mixing kinds is impossible — keeps batch actions tractable.
  SelectionItemKind? _kind;

  /// True when the view is in selection mode (header replaced with
  /// Cancel/Done, rows show checkboxes, actions in toolbar).
  bool _active = false;
  bool get active => _active;

  Set<String> get selectedIds => Set.unmodifiable(_selected);
  int get count => _selected.length;
  SelectionItemKind? get kind => _kind;
  bool isSelected(String id) => _selected.contains(id);
  bool get isEmpty => _selected.isEmpty;

  void start() {
    if (_active) return;
    _active = true;
    notifyListeners();
  }

  void cancel() {
    if (!_active && _selected.isEmpty) return;
    _active = false;
    _selected.clear();
    _kind = null;
    notifyListeners();
  }

  /// Toggles selection of [id]. The first call locks the selection
  /// to [kind]; subsequent toggles of different kinds are silently
  /// ignored (the row won't appear selectable in the UI).
  void toggle(String id, SelectionItemKind kind) {
    if (_kind == null) {
      _kind = kind;
    } else if (_kind != kind) {
      return;
    }
    if (_selected.contains(id)) {
      _selected.remove(id);
      // Releasing the last item un-locks the kind so the user can
      // start a new selection with a different kind without cancelling.
      if (_selected.isEmpty) _kind = null;
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  /// Replaces the entire selection with [ids] of [kind] — used by
  /// "Select All" buttons.
  void replaceAll(Iterable<String> ids, SelectionItemKind kind) {
    _selected
      ..clear()
      ..addAll(ids);
    _kind = _selected.isEmpty ? null : kind;
    notifyListeners();
  }
}
