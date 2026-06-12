import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../calendar/event_controller.dart';
import '../database/database_service.dart';
import '../folders/folder_controller.dart';
import '../localization/strings.dart';
import '../models/event.dart';
import '../models/note.dart';
import '../models/task.dart';
import '../notes/note_controller.dart';
import '../notes/note_detail_view.dart';
import '../tasks/task_controller.dart';
import '../tasks/task_detail_view.dart';
import '../theme/app_theme.dart';
import '../utils/fast_route.dart';

/// Global FTS5-backed search across tasks, notes, and events. Queries are
/// debounced 200ms so we don't hammer the DB on every keystroke.
class SearchView extends StatefulWidget {
  const SearchView({
    super.key,
    required this.db,
    required this.taskController,
    required this.folderController,
    required this.noteController,
    required this.eventController,
  });

  final DatabaseService db;
  final TaskController taskController;
  final FolderController folderController;
  final NoteController noteController;
  final EventController eventController;

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  SearchResults _results = const SearchResults({}, {}, {});

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _run);
  }

  Future<void> _run() async {
    final q = _ctrl.text;
    final results = await widget.db.searchAll(q);
    if (!mounted) return;
    setState(() {
      _query = q;
      _results = results;
    });
  }

  void _openTask(Task t) {
    Navigator.of(context).push(FastRoute<void>(
      settings: const RouteSettings(name: TaskDetailView.routeName),
      builder: (_) => TaskDetailView(
        task: t,
        controller: widget.taskController,
        folderController: widget.folderController,
      ),
    ));
  }

  void _openNote(Note n) {
    Navigator.of(context).push(FastRoute<void>(
      builder: (_) => NoteDetailView(
        note: n,
        controller: widget.noteController,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    final tasks = _results.taskIds
        .map(widget.taskController.taskById)
        .whereType<Task>()
        .toList();
    final notes = _results.noteIds
        .map(widget.noteController.noteById)
        .whereType<Note>()
        .toList();
    final events = _results.eventIds
        .map(widget.eventController.eventById)
        .whereType<Event>()
        .toList();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.search),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: CupertinoSearchTextField(
                controller: _ctrl,
                placeholder: s.search,
                autofocus: true,
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty
                  ? _EmptyState(label: s.searchEmptyHint)
                  : _results.isEmpty
                      ? _EmptyState(label: s.searchNoResults)
                      : ListView(
                          children: [
                            if (tasks.isNotEmpty)
                              _SectionHeader(
                                  label: s.tabTasks, count: tasks.length),
                            for (final t in tasks)
                              _ResultRow(
                                icon: CupertinoIcons.check_mark_circled,
                                title: t.title,
                                subtitle: t.note,
                                onTap: () => _openTask(t),
                              ),
                            if (notes.isNotEmpty)
                              _SectionHeader(
                                  label: s.tabNotes, count: notes.length),
                            for (final n in notes)
                              _ResultRow(
                                icon: CupertinoIcons.doc_text,
                                title: n.title.isEmpty ? s.untitled : n.title,
                                subtitle: n.content,
                                onTap: () => _openNote(n),
                              ),
                            if (events.isNotEmpty)
                              _SectionHeader(
                                  label: s.tabCalendar, count: events.length),
                            for (final e in events)
                              _ResultRow(
                                icon: CupertinoIcons.calendar,
                                title: e.title,
                                subtitle: e.note,
                                onTap: null,
                              ),
                            const SizedBox(height: 32),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        '${label.toUpperCase()}  $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = subtitle?.trim();
    return Semantics(
      label: title,
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (s != null && s.isNotEmpty)
                      Text(
                        s,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
