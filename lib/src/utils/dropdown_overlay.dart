import 'package:flutter/cupertino.dart';

/// Mixin for [State] classes that show transient dropdown menus via
/// [OverlayEntry].
///
/// Without this, an entry inserted via `Overlay.of(context).insert(entry)` is
/// only removed by an explicit user dismiss callback — if the route hosting
/// the State is popped (e.g. via back-gesture, or after a destructive action
/// pops the route programmatically), the overlay leaks: it remains visible
/// and absorbs taps until the app restarts.
///
/// Usage:
/// ```dart
/// class _MyViewState extends State<MyView> with DropdownOverlayMixin {
///   void _showMenu(BuildContext context) {
///     showDropdown(context, (dismiss) => _MyMenu(onDismiss: dismiss));
///   }
/// }
/// ```
mixin DropdownOverlayMixin<T extends StatefulWidget> on State<T> {
  OverlayEntry? _dropdownEntry;

  /// Inserts [builder]'s widget into the [Overlay] above [context].
  ///
  /// The builder receives a `dismiss` callback that removes the entry. The
  /// entry is also removed automatically when this State is disposed.
  void showDropdown(
    BuildContext context,
    Widget Function(VoidCallback dismiss) builder,
  ) {
    dismissDropdown();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => builder(() {
        if (_dropdownEntry == entry) _dropdownEntry = null;
        entry.remove();
      }),
    );
    _dropdownEntry = entry;
    overlay.insert(entry);
  }

  void dismissDropdown() {
    _dropdownEntry?.remove();
    _dropdownEntry = null;
  }

  @override
  void dispose() {
    dismissDropdown();
    super.dispose();
  }
}
