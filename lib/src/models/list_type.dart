/// The semantic kind of an [AppList]. Determines which task-creation flow and
/// detail view the list shows.
///
/// Persisted as the raw string value in `app_lists.listType`.
enum ListType {
  /// Standard task list (default).
  tasks('tasks'),

  /// Each "task" represents a contact with a recurring birthday; the creation
  /// sheet collects a name + birth date (year optional) and the row renders
  /// the upcoming celebration date.
  birthdays('birthdays'),

  /// A shopping list. Behaves like a task list but uses a dedicated label so
  /// callers can tweak UI copy/icons if needed.
  shopping('shopping');

  const ListType(this.value);

  /// The string stored in SQLite.
  final String value;

  static ListType fromString(String? raw) {
    switch (raw) {
      case 'birthdays':
        return ListType.birthdays;
      case 'shopping':
        return ListType.shopping;
      default:
        return ListType.tasks;
    }
  }
}
