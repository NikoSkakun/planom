import 'dart:convert';

import 'package:uuid/uuid.dart';

/// How a [GoalSource] picks the tasks it contributes to a goal.
enum GoalSourceKind {
  /// A fixed set of hand-picked task ids.
  manual,

  /// A live rule: every task inside a scope, optionally narrowed by tag /
  /// priority / due-date filters. Tasks created later that satisfy the rule
  /// join the goal automatically.
  rule,
}

/// Where a rule looks for candidate tasks.
enum GoalScopeType {
  /// Every task in the space (Inbox + every list).
  all,

  /// Tasks in any list inside the chosen folders (recursively).
  folders,

  /// Tasks in the chosen lists.
  lists,

  /// Tasks in the chosen list sections.
  sections,
}

/// Due-date predicate applied by a rule.
enum GoalDateFilter { any, noDate, overdue, today, tomorrow, thisWeek, thisMonth, range }

String _encodeKind(GoalSourceKind k) => k.name;
GoalSourceKind _decodeKind(String? raw) => GoalSourceKind.values.firstWhere(
      (k) => k.name == raw,
      orElse: () => GoalSourceKind.rule,
    );

String _encodeScope(GoalScopeType s) => s.name;
GoalScopeType _decodeScope(String? raw) => GoalScopeType.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => GoalScopeType.all,
    );

String _encodeDateFilter(GoalDateFilter f) => f.name;
GoalDateFilter _decodeDateFilter(String? raw) =>
    GoalDateFilter.values.firstWhere(
      (f) => f.name == raw,
      orElse: () => GoalDateFilter.any,
    );

/// One contributor to a goal's task set.
///
/// A goal holds a list of these and tracks the **union** of what they resolve
/// to, so a user can combine "these three tasks I picked" with "everything in
/// the Work folder" and "anything tagged #launch due this month".
class GoalSource {
  GoalSource({
    String? id,
    this.kind = GoalSourceKind.rule,
    List<String>? taskIds,
    this.scopeType = GoalScopeType.all,
    List<String>? scopeIds,
    List<String>? tagIds,
    List<int>? priorities,
    this.dateFilter = GoalDateFilter.any,
    this.from,
    this.to,
  })  : id = id ?? const Uuid().v4(),
        taskIds = List.unmodifiable(taskIds ?? const []),
        scopeIds = List.unmodifiable(scopeIds ?? const []),
        tagIds = List.unmodifiable(tagIds ?? const []),
        priorities = List.unmodifiable(priorities ?? const []);

  /// Stable id so the editor can address a row without positional indexes.
  final String id;
  final GoalSourceKind kind;

  /// [GoalSourceKind.manual] only: the hand-picked tasks.
  final List<String> taskIds;

  /// [GoalSourceKind.rule] only: where to look …
  final GoalScopeType scopeType;

  /// … and which folders / lists / sections when the scope isn't `all`.
  final List<String> scopeIds;

  /// Optional narrowing. Empty means "don't filter on this".
  final List<String> tagIds;

  /// Task priorities to keep (0 none … 3 high). Empty = any.
  final List<int> priorities;

  final GoalDateFilter dateFilter;

  /// [GoalDateFilter.range] bounds, day granularity, both inclusive.
  final DateTime? from;
  final DateTime? to;

  /// True when a rule has no narrowing at all — it tracks everything in its
  /// scope, including tasks created later.
  bool get isUnfiltered =>
      kind == GoalSourceKind.rule &&
      tagIds.isEmpty &&
      priorities.isEmpty &&
      dateFilter == GoalDateFilter.any;

  GoalSource copyWith({
    GoalSourceKind? kind,
    List<String>? taskIds,
    GoalScopeType? scopeType,
    List<String>? scopeIds,
    List<String>? tagIds,
    List<int>? priorities,
    GoalDateFilter? dateFilter,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
  }) =>
      GoalSource(
        id: id,
        kind: kind ?? this.kind,
        taskIds: taskIds ?? this.taskIds,
        scopeType: scopeType ?? this.scopeType,
        scopeIds: scopeIds ?? this.scopeIds,
        tagIds: tagIds ?? this.tagIds,
        priorities: priorities ?? this.priorities,
        dateFilter: dateFilter ?? this.dateFilter,
        from: clearFrom ? null : (from ?? this.from),
        to: clearTo ? null : (to ?? this.to),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': _encodeKind(kind),
        if (taskIds.isNotEmpty) 'taskIds': taskIds,
        'scopeType': _encodeScope(scopeType),
        if (scopeIds.isNotEmpty) 'scopeIds': scopeIds,
        if (tagIds.isNotEmpty) 'tagIds': tagIds,
        if (priorities.isNotEmpty) 'priorities': priorities,
        'dateFilter': _encodeDateFilter(dateFilter),
        if (from != null) 'from': from!.millisecondsSinceEpoch,
        if (to != null) 'to': to!.millisecondsSinceEpoch,
      };

  static GoalSource fromJson(Map<String, dynamic> map) => GoalSource(
        id: map['id'] as String?,
        kind: _decodeKind(map['kind'] as String?),
        taskIds: _stringList(map['taskIds']),
        scopeType: _decodeScope(map['scopeType'] as String?),
        scopeIds: _stringList(map['scopeIds']),
        tagIds: _stringList(map['tagIds']),
        priorities: _intList(map['priorities']),
        dateFilter: _decodeDateFilter(map['dateFilter'] as String?),
        from: map['from'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['from'] as int),
        to: map['to'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['to'] as int),
      );

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<String>().toList();
  }

  static List<int> _intList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<int>().toList();
  }
}

/// A user-defined objective that tracks a collection of tasks and reports how
/// much of it is done.
///
/// The task set is never stored denormalised — it is resolved from [sources]
/// on demand, so rule-based sources keep picking up tasks created after the
/// goal was made.
class Goal {
  Goal({
    String? id,
    required this.name,
    this.description,
    this.iconId = 'flag',
    this.color = 0xFFFF4D00,
    List<GoalSource>? sources,
    this.sortOrder = 0,
    DateTime? creationDate,
  })  : id = id ?? const Uuid().v4(),
        sources = List.unmodifiable(sources ?? const []),
        creationDate = creationDate ?? DateTime.now();

  final String id;
  final String name;
  final String? description;

  /// Key into `kGoalIcons` (see `lib/src/goals/goal_icons.dart`).
  final String iconId;

  /// ARGB accent used for the goal's icon badge.
  final int color;
  final List<GoalSource> sources;
  final int sortOrder;
  final DateTime creationDate;

  Goal copyWith({
    String? name,
    String? description,
    bool clearDescription = false,
    String? iconId,
    int? color,
    List<GoalSource>? sources,
    int? sortOrder,
  }) =>
      Goal(
        id: id,
        name: name ?? this.name,
        description:
            clearDescription ? null : (description ?? this.description),
        iconId: iconId ?? this.iconId,
        color: color ?? this.color,
        sources: sources ?? this.sources,
        sortOrder: sortOrder ?? this.sortOrder,
        creationDate: creationDate,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'iconId': iconId,
        'color': color,
        'sources': jsonEncode(sources.map((s) => s.toJson()).toList()),
        'sortOrder': sortOrder,
        'creationDate': creationDate.millisecondsSinceEpoch,
      };

  factory Goal.fromMap(Map<String, dynamic> map) => Goal(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        iconId: map['iconId'] as String? ?? 'flag',
        color: map['color'] as int? ?? 0xFFFF4D00,
        sources: _parseSources(map['sources'] as String?),
        sortOrder: map['sortOrder'] as int? ?? 0,
        creationDate:
            DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
      );

  /// Tolerant parse — a malformed `sources` blob yields a goal with no
  /// sources (an empty goal) rather than breaking the whole Goals tab.
  static List<GoalSource> _parseSources(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(GoalSource.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
