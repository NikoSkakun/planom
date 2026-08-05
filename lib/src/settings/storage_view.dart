import 'package:flutter/cupertino.dart';

import '../database/database_service.dart';
import '../localization/strings.dart';
import '../spaces/space.dart';
import '../spaces/space_manager.dart';
import '../theme/app_theme.dart';
import '../utils/confirm_dialogs.dart';
import '../utils/selection_menu.dart';
import 'settings_widgets.dart';
import 'storage_analyzer.dart';

/// Settings → Data → Storage. Shows a stacked bar of disk usage by
/// category for the chosen space, plus standalone rows for the global
/// caches (custom icons, fonts, temp files) that can be cleared
/// independently.
class StorageView extends StatefulWidget {
  const StorageView({super.key, required this.spaceManager});

  final SpaceManager spaceManager;

  @override
  State<StorageView> createState() => _StorageViewState();
}

class _StorageViewState extends State<StorageView> {
  bool _loading = true;
  String _selectedSpaceId = 'default';
  SpaceStorageReport? _report;
  FileBuckets _icons = FileBuckets(0, 0);
  FileBuckets _fonts = FileBuckets(0, 0);
  FileBuckets _temp = FileBuckets(0, 0);

  @override
  void initState() {
    super.initState();
    _selectedSpaceId = widget.spaceManager.activeSpaceId;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);

    // Always rescan filesystem caches — they're space-agnostic.
    final icons = await StorageAnalyzer.analyzeCustomIcons();
    final fonts = await StorageAnalyzer.analyzeFontsCache();
    final temp = await StorageAnalyzer.analyzeTempCache();

    // Per-space DB analysis. Reuse the active space's open handle when
    // possible; otherwise temporarily open the file.
    final space = widget.spaceManager.spaces.firstWhere(
      (s) => s.id == _selectedSpaceId,
      orElse: () => widget.spaceManager.activeSpace,
    );
    SpaceStorageReport? report;
    if (_selectedSpaceId == widget.spaceManager.activeSpaceId) {
      // Use the live DB through DatabaseService — sqflite's underlying
      // handle isn't directly exposed, so we re-open a separate one for
      // analysis. This is read-only and safe to run alongside writes.
      report = await _openAndAnalyze(space);
    } else {
      report = await _openAndAnalyze(space);
    }

    if (!mounted) return;
    setState(() {
      _icons = icons;
      _fonts = fonts;
      _temp = temp;
      _report = report;
      _loading = false;
    });
  }

  Future<SpaceStorageReport?> _openAndAnalyze(Space space) async {
    final dbName = widget.spaceManager.dbNameFor(space.id);
    // Use a fresh DatabaseService for non-default spaces; for the
    // default space we share the active handle to avoid opening the
    // same file twice (sqflite forbids that on iOS/Android).
    final svc = space.id == 'default'
        ? widget.spaceManager.globalDb
        : DatabaseService(dbName: dbName);
    try {
      return await StorageAnalyzer.analyzeSpace(
        spaceId: space.id,
        spaceName: space.name,
        svc: svc,
        dbName: dbName,
      );
    } finally {
      if (space.id != 'default') await svc.close();
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _clearFonts() async {
    final s = S.of(context);
    final ok = await _confirm(s.clearFontsCacheQ, s.clearFontsCacheBody);
    if (!ok) return;
    await StorageAnalyzer.clearFontsCache();
    if (mounted) await _refresh();
  }

  Future<void> _clearTemp() async {
    final s = S.of(context);
    final ok = await _confirm(s.clearTempCacheQ, s.clearTempCacheBody);
    if (!ok) return;
    await StorageAnalyzer.clearTempCache();
    if (mounted) await _refresh();
  }

  Future<void> _clearOrphanIcons() async {
    final s = S.of(context);
    final ok = await confirmHardDelete(
      context,
      title: s.clearOrphanIconsQ,
      body: s.clearOrphanIconsBody,
    );
    if (!ok) return;
    // Gather referenced icons across every space.
    final referenced = <String>{};
    for (final space in widget.spaceManager.spaces) {
      final svc = space.id == 'default'
          ? widget.spaceManager.globalDb
          : DatabaseService(
              dbName: widget.spaceManager.dbNameFor(space.id));
      try {
        referenced.addAll(await StorageAnalyzer.referencedIconsIn(svc));
      } finally {
        if (space.id != 'default') await svc.close();
      }
    }
    await StorageAnalyzer.clearOrphanIcons(referenced);
    if (mounted) await _refresh();
  }

  Future<bool> _confirm(String title, String body) async {
    return confirmHardDelete(context, title: title, body: body);
  }

  Future<void> _pickSpace() async {
    final s = S.of(context);
    final choice = await showSelectionMenu<String>(
      context: context,
      title: s.space,
      current: _selectedSpaceId,
      options: [
        for (final sp in widget.spaceManager.spaces)
          SelectionMenuOption(value: sp.id, label: sp.name),
      ],
    );
    if (choice == null || choice == _selectedSpaceId) return;
    setState(() => _selectedSpaceId = choice);
    await _refresh();
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.storage),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _refresh),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(_buildBody(s)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildBody(S s) {
    final report = _report;
    final spaces = widget.spaceManager.spaces;
    final activeSpace = spaces.firstWhere(
      (sp) => sp.id == _selectedSpaceId,
      orElse: () => widget.spaceManager.activeSpace,
    );

    final categories = <_CategoryRow>[];
    if (report != null) {
      categories.addAll(_dbCategoryRows(s, report));
    }
    final totalDb = report?.totalBytes ?? 0;

    return [
      // Space picker
      if (spaces.length > 1)
        SettingsNavRow(
          label: s.space,
          trailingLabel: activeSpace.name,
          onTap: _pickSpace,
        ),
      if (spaces.length > 1) const SizedBox(height: 18),

      // ── Per-space DB section ────────────────────────────────────────────
      SettingsSectionHeader(s.storageDataIn(activeSpace.name)),
      const SizedBox(height: 6),
      _UsageBar(categories: categories),
      const SizedBox(height: 8),
      _LegendRow(
        label: s.storageTotal,
        sublabel:
            '${report?.totalItems ?? 0} ${s.storageItemsSuffix} · ${formatBytes(totalDb)}',
        color: AppColors.accent,
      ),
      const SizedBox(height: 12),
      for (final c in categories) _CategoryListRow(category: c),

      // ── App-wide caches ────────────────────────────────────────────────
      const SizedBox(height: 24),
      SettingsSectionHeader(s.storageAppCaches),
      const SizedBox(height: 6),
      _ClearableRow(
        label: s.storageCustomIcons,
        sublabel:
            '${_icons.count} ${s.storageFilesSuffix} · ${formatBytes(_icons.bytes)}',
        canClear: _icons.count > 0,
        onClear: _clearOrphanIcons,
        clearLabel: s.storageClearOrphans,
      ),
      const SizedBox(height: 1),
      _ClearableRow(
        label: s.storageFontsCache,
        sublabel:
            '${_fonts.count} ${s.storageFilesSuffix} · ${formatBytes(_fonts.bytes)}',
        canClear: _fonts.bytes > 0,
        onClear: _clearFonts,
        clearLabel: s.clear,
      ),
      const SizedBox(height: 1),
      _ClearableRow(
        label: s.storageTempCache,
        sublabel:
            '${_temp.count} ${s.storageFilesSuffix} · ${formatBytes(_temp.bytes)}',
        canClear: _temp.bytes > 0,
        onClear: _clearTemp,
        clearLabel: s.clear,
      ),
    ];
  }

  List<_CategoryRow> _dbCategoryRows(S s, SpaceStorageReport r) {
    String labelFor(String id) {
      switch (id) {
        case 'tasks':
          return s.tabTasks;
        case 'contacts':
          return s.listTypeBirthdays;
        case 'notes':
          return s.tabNotes;
        case 'events':
          return s.eventOption;
        case 'routines':
          return s.tabRoutines;
        case 'finance':
          return s.tabFinance;
        case 'goals':
          return s.tabGoals;
        case 'tags':
          return s.tags;
        case 'containers':
          return s.storageFoldersLists;
      }
      return id;
    }

    const colors = [
      Color(0xFFFF4D00), // accent-ish
      Color(0xFFFF2D55), // pink — contacts
      Color(0xFF34C759), // green — notes
      Color(0xFF007AFF), // blue — events
      Color(0xFFAF52DE), // purple — routines
      Color(0xFF00C7BE), // teal — finance
      Color(0xFF5856D6), // indigo — goals
      Color(0xFFFF9500), // orange — tags
      Color(0xFF8E8E93), // gray — folders/lists
    ];

    final out = <_CategoryRow>[];
    for (var i = 0; i < r.categories.length; i++) {
      final b = r.categories[i];
      if (b.bytes == 0 && b.count == 0) continue;
      out.add(_CategoryRow(
        id: b.id,
        label: labelFor(b.id),
        bytes: b.bytes,
        count: b.count,
        color: colors[i % colors.length],
      ));
    }
    return out;
  }
}

// ── Internal widgets ─────────────────────────────────────────────────────────

class _CategoryRow {
  _CategoryRow({
    required this.id,
    required this.label,
    required this.bytes,
    required this.count,
    required this.color,
  });

  final String id;
  final String label;
  final int bytes;
  final int count;
  final Color color;
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.categories});

  final List<_CategoryRow> categories;

  @override
  Widget build(BuildContext context) {
    final total = categories.fold<int>(0, (s, c) => s + c.bytes);
    if (total == 0) {
      return Container(
        height: 16,
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }
    return Container(
      height: 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.hardEdge,
      child: Row(
        children: [
          for (final c in categories)
            Expanded(
              flex: ((c.bytes * 1000) ~/ total).clamp(1, 1000),
              child: Container(color: c.color),
            ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.sublabel,
    required this.color,
  });

  final String label;
  final String sublabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(sublabel,
                  style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel
                          .resolveFrom(context))),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryListRow extends StatelessWidget {
  const _CategoryListRow({required this.category});

  final _CategoryRow category;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bg = CupertinoDynamicColor.resolve(
        CupertinoColors.tertiarySystemBackground, context);
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: category.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(category.label,
                style: const TextStyle(fontSize: 16)),
          ),
          Text(
            '${category.count} ${s.storageItemsSuffix}',
            style: TextStyle(
              fontSize: 13,
              color:
                  CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatBytes(category.bytes),
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClearableRow extends StatelessWidget {
  const _ClearableRow({
    required this.label,
    required this.sublabel,
    required this.canClear,
    required this.onClear,
    required this.clearLabel,
  });

  final String label;
  final String sublabel;
  final bool canClear;
  final Future<void> Function() onClear;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
        CupertinoColors.tertiarySystemBackground, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel
                        .resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: canClear ? onClear : null,
            child: Text(
              clearLabel,
              style: TextStyle(
                color: canClear
                    ? CupertinoColors.destructiveRed
                    : CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
