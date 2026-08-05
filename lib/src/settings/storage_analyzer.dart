import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import '../database/database_service.dart';

/// Scans every space's database + the shared filesystem caches and
/// produces per-category size breakdowns. Heavy I/O lives here so the
/// settings view can stay synchronous-ish.
class StorageAnalyzer {
  /// Approximates bytes for a list of exported rows by JSON-encoding them
  /// and measuring the result. Tracks how much "logical" data a category
  /// holds; not exact on-disk usage but a stable proxy that's easy to
  /// compute through DatabaseService's existing public API.
  static int _estimateRowsBytes(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return 0;
    try {
      return utf8.encode(jsonEncode(rows)).length;
    } catch (_) {
      // Fallback: 256 bytes per row.
      return rows.length * 256;
    }
  }

  /// Per-space DB analysis. Uses DatabaseService's exportXxx helpers so
  /// we don't have to reach into the underlying sqflite Database.
  static Future<List<DbBuckets>> analyzeSpaceDbBuckets(
      DatabaseService svc) async {
    Future<DbBuckets> bucketSingle(String id, String name,
        Future<List<Map<String, dynamic>>> Function() loader) async {
      try {
        final rows = await loader();
        return DbBuckets(id, _estimateRowsBytes(rows), rows.length);
      } catch (_) {
        return DbBuckets(id, 0, 0);
      }
    }

    final tasks = await bucketSingle('tasks', 'tasks', svc.exportTasks);
    final contacts =
        await bucketSingle('contacts', 'contacts', svc.exportContacts);
    final notes = await bucketSingle('notes', 'notes', svc.exportNotes);
    final events = await bucketSingle('events', 'events', svc.exportEvents);
    // Routines + routine_entries together.
    final routines = await svc.exportRoutines();
    final entries = await svc.exportRoutineEntries();
    final routineBucket = DbBuckets(
      'routines',
      _estimateRowsBytes(routines) + _estimateRowsBytes(entries),
      routines.length,
    );
    final tags = await bucketSingle('tags', 'tags', svc.exportTags);
    // Finance: entries + their categories and budgets in one bucket. The count
    // reports entries only — categories/budgets are configuration, not data
    // the user thinks of as "stored items".
    final financeEntries = await svc.exportFinanceTransactions();
    final financeCategories = await svc.exportFinanceCategories();
    final financeBudgets = await svc.exportFinanceBudgets();
    final financeAccounts = await svc.exportFinanceAccounts();
    final financeBucket = DbBuckets(
      'finance',
      _estimateRowsBytes(financeEntries) +
          _estimateRowsBytes(financeCategories) +
          _estimateRowsBytes(financeBudgets) +
          _estimateRowsBytes(financeAccounts),
      financeEntries.length,
    );
    final goals = await bucketSingle('goals', 'goals', svc.exportGoals);
    // Folders + lists + note folders + sections together.
    final folders = await svc.exportFolders();
    final lists = await svc.exportLists();
    final noteFolders = await svc.exportNoteFolders();
    final sections = await svc.exportListSections();
    final containerBucket = DbBuckets(
      'containers',
      _estimateRowsBytes(folders) +
          _estimateRowsBytes(lists) +
          _estimateRowsBytes(noteFolders) +
          _estimateRowsBytes(sections),
      folders.length + lists.length + noteFolders.length + sections.length,
    );

    return [
      tasks,
      contacts,
      notes,
      events,
      routineBucket,
      financeBucket,
      goals,
      tags,
      containerBucket,
    ];
  }

  /// Reads the entire SQLite file size for a space's database — gives an
  /// "actual on-disk" total that includes indexes, free pages, etc.
  static Future<int> spaceDbFileBytes(String dbName) async {
    try {
      final path = await getDatabasesPath();
      final f = File(p.join(path, dbName));
      if (!await f.exists()) return 0;
      return await f.length();
    } catch (_) {
      return 0;
    }
  }

  /// Custom icon files saved under `<documents>/icons`.
  static Future<FileBuckets> analyzeCustomIcons() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/icons');
      if (!await dir.exists()) return FileBuckets(0, 0);
      int total = 0;
      int n = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          try {
            total += await entity.length();
            n++;
          } catch (_) {}
        }
      }
      return FileBuckets(total, n);
    } catch (_) {
      return FileBuckets(0, 0);
    }
  }

  /// Google Fonts cache lives under `<applicationSupport>/google_fonts`.
  static Future<FileBuckets> analyzeFontsCache() async {
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/google_fonts');
      if (!await dir.exists()) return FileBuckets(0, 0);
      int total = 0;
      int n = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try {
            total += await entity.length();
            n++;
          } catch (_) {}
        }
      }
      return FileBuckets(total, n);
    } catch (_) {
      return FileBuckets(0, 0);
    }
  }

  /// Temp directory — exports, share-sheet leftovers, etc.
  static Future<FileBuckets> analyzeTempCache() async {
    try {
      final tmp = await getTemporaryDirectory();
      int total = 0;
      int n = 0;
      await for (final entity in tmp.list(recursive: true)) {
        if (entity is File) {
          try {
            total += await entity.length();
            n++;
          } catch (_) {}
        }
      }
      return FileBuckets(total, n);
    } catch (_) {
      return FileBuckets(0, 0);
    }
  }

  /// Wipes the fonts cache directory. Returns the number of files removed.
  static Future<int> clearFontsCache() async {
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/google_fonts');
      if (!await dir.exists()) return 0;
      int n = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try {
            await entity.delete();
            n++;
          } catch (_) {}
        }
      }
      return n;
    } catch (_) {
      return 0;
    }
  }

  /// Wipes the OS temp directory. Returns the number of files removed.
  static Future<int> clearTempCache() async {
    try {
      final tmp = await getTemporaryDirectory();
      int n = 0;
      await for (final entity in tmp.list(recursive: true)) {
        if (entity is File) {
          try {
            await entity.delete();
            n++;
          } catch (_) {}
        }
      }
      return n;
    } catch (_) {
      return 0;
    }
  }

  /// Wipes orphaned custom icons — files in `<docs>/icons` not referenced
  /// by any folder/list iconId across [referenced]. Returns the count
  /// removed.
  static Future<int> clearOrphanIcons(Set<String> referenced) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/icons');
      if (!await dir.exists()) return 0;
      int n = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          final name = p.basename(entity.path);
          final rel = 'icons/$name';
          if (!referenced.contains(rel)) {
            try {
              await entity.delete();
              n++;
            } catch (_) {}
          }
        }
      }
      return n;
    } catch (_) {
      return 0;
    }
  }

  /// Convenience wrapper: runs every per-table query for [svc] and packs
  /// the result into a [SpaceStorageReport].
  static Future<SpaceStorageReport> analyzeSpace({
    required String spaceId,
    required String spaceName,
    required DatabaseService svc,
    required String dbName,
  }) async {
    final buckets = await analyzeSpaceDbBuckets(svc);
    DbBuckets pick(String id) =>
        buckets.firstWhere((b) => b.id == id,
            orElse: () => DbBuckets(id, 0, 0));
    return SpaceStorageReport(
      spaceId: spaceId,
      spaceName: spaceName,
      tasks: pick('tasks'),
      contacts: pick('contacts'),
      notes: pick('notes'),
      events: pick('events'),
      routines: pick('routines'),
      finance: pick('finance'),
      goals: pick('goals'),
      tags: pick('tags'),
      containers: pick('containers'),
      dbFileBytes: await spaceDbFileBytes(dbName),
    );
  }

  /// Returns every custom-icon path referenced by folders/lists/note
  /// folders in [svc]. Used to figure out which on-disk icons are
  /// orphans (not present in any space's DB).
  static Future<Set<String>> referencedIconsIn(DatabaseService svc) async {
    final out = <String>{};
    for (final f in await svc.getFolders()) {
      final id = f.iconId;
      if (id != null && id.startsWith('icons/')) out.add(id);
    }
    for (final l in await svc.getLists()) {
      final id = l.iconId;
      if (id != null && id.startsWith('icons/')) out.add(id);
    }
    for (final f in await svc.getNoteFolders()) {
      final id = f.iconId;
      if (id != null && id.startsWith('icons/')) out.add(id);
    }
    return out;
  }
}

class DbBuckets {
  DbBuckets(this.id, this.bytes, this.count);
  final String id;
  final int bytes;
  final int count;
}

class FileBuckets {
  FileBuckets(this.bytes, this.count);
  final int bytes;
  final int count;
}

/// Result returned to the UI for a single space.
class SpaceStorageReport {
  SpaceStorageReport({
    required this.spaceId,
    required this.spaceName,
    required this.tasks,
    required this.contacts,
    required this.notes,
    required this.events,
    required this.routines,
    required this.finance,
    required this.goals,
    required this.tags,
    required this.containers,
    required this.dbFileBytes,
  });

  final String spaceId;
  final String spaceName;
  final DbBuckets tasks;
  final DbBuckets contacts;
  final DbBuckets notes;
  final DbBuckets events;
  final DbBuckets routines;
  final DbBuckets finance;
  final DbBuckets goals;
  final DbBuckets tags;
  final DbBuckets containers;
  final int dbFileBytes;

  int get totalBytes =>
      tasks.bytes +
      contacts.bytes +
      notes.bytes +
      events.bytes +
      routines.bytes +
      finance.bytes +
      goals.bytes +
      tags.bytes +
      containers.bytes;

  int get totalItems =>
      tasks.count +
      contacts.count +
      notes.count +
      events.count +
      routines.count +
      finance.count +
      goals.count +
      tags.count +
      containers.count;

  List<DbBuckets> get categories =>
      [tasks, contacts, notes, events, routines, finance, goals, tags, containers];
}

/// Formats a byte count as a human-readable size like "1.2 MB".
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
