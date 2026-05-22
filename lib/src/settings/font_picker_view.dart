import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

import '../localization/strings.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import 'font_cache.dart';
import 'settings_controller.dart';

class FontPickerView extends StatefulWidget {
  const FontPickerView({super.key, required this.controller});

  final SettingsController controller;

  @override
  State<FontPickerView> createState() => _FontPickerViewState();
}

class _FontPickerViewState extends State<FontPickerView> {
  final _searchController = TextEditingController();
  String _query = '';
  late final List<String> _allFontKeys;
  bool _isOnline = true;
  bool _ready = false;
  String _previewText = FontCache.instance.previewText;

  @override
  void initState() {
    super.initState();
    _allFontKeys = GoogleFonts.asMap().keys.toList()..sort();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _init();
  }

  Future<void> _init() async {
    await FontCache.instance.load();
    final online = await _checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = online;
        _previewText = FontCache.instance.previewText;
        _ready = true;
      });
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('fonts.gstatic.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _systemMatches() =>
      _query.isEmpty || 'system'.contains(_query) || 'sf pro'.contains(_query);

  List<String> get _filteredFontKeys {
    if (_query.isEmpty) return _allFontKeys;
    return _allFontKeys.where((k) {
      return k.toLowerCase().contains(_query) ||
          fontDisplayName(k).toLowerCase().contains(_query);
    }).toList();
  }

  void _select(String key) {
    widget.controller.updateFontKey(key);
    FontCache.instance.markCached(key);
    Navigator.of(context).pop();
  }

  void _showMenu(BuildContext context) {
    final s = S.of(context);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showEditPreviewDialog(context);
            },
            child: Text(s.editPreviewText),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(s.cancel),
        ),
      ),
    );
  }

  void _showEditPreviewDialog(BuildContext context) {
    final s = S.of(context);
    final ctrl = TextEditingController(text: _previewText);
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(s.previewText),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            autofocus: true,
            clearButtonMode: OverlayVisibilityMode.editing,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await FontCache.instance.setPreviewText(ctrl.text);
              if (mounted) {
                setState(() => _previewText = FontCache.instance.previewText);
              }
            },
            child: Text(s.ok),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final current = widget.controller.fontKey;
    final filtered = _filteredFontKeys;
    final showSystem = _systemMatches();
    final itemCount = (showSystem ? 1 : 0) + filtered.length;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.font),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showMenu(context),
          child: const Icon(CupertinoIcons.ellipsis, size: 26),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: s.searchFonts,
              ),
            ),
            if (_ready && !_isOnline)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.wifi_slash,
                      size: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      s.fontOfflineWarning,
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (showSystem && index == 0) {
                    return _FontRow(
                      fontKey: kSystemFontKey,
                      displayName: s.systemFont,
                      previewStyle: const TextStyle(fontSize: 20),
                      previewText: _previewText,
                      isSelected: current == kSystemFontKey,
                      isAvailable: true,
                      onTap: () => _select(kSystemFontKey),
                    );
                  }
                  final key = filtered[showSystem ? index - 1 : index];
                  final fontFn = GoogleFonts.asMap()[key];
                  final previewStyle = fontFn != null
                      ? fontFn(fontSize: 20)
                      : const TextStyle(fontSize: 20);

                  // When online, mark each rendered row as cached.
                  if (_isOnline) FontCache.instance.markCached(key);

                  final isAvailable = _isOnline ||
                      key == current ||
                      FontCache.instance.isCached(key);

                  return _FontRow(
                    fontKey: key,
                    displayName: fontDisplayName(key),
                    previewStyle: previewStyle,
                    previewText: _previewText,
                    isSelected: key == current,
                    isAvailable: isAvailable,
                    onTap: isAvailable ? () => _select(key) : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FontRow extends StatelessWidget {
  const _FontRow({
    required this.fontKey,
    required this.displayName,
    required this.previewStyle,
    required this.previewText,
    required this.isSelected,
    required this.isAvailable,
    required this.onTap,
  });

  final String fontKey;
  final String displayName;
  final TextStyle previewStyle;
  final String previewText;
  final bool isSelected;
  final bool isAvailable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    final unavailableColor =
        CupertinoColors.tertiaryLabel.resolveFrom(context);
    final labelColor = isAvailable
        ? CupertinoColors.secondaryLabel.resolveFrom(context)
        : unavailableColor;
    final textColor = isAvailable
        ? CupertinoColors.label.resolveFrom(context)
        : unavailableColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
                  Text(
                    displayName,
                    style: TextStyle(fontSize: 12, color: labelColor),
                  ),
                  if (isAvailable) ...[
                    const SizedBox(height: 2),
                    Text(
                      previewText,
                      style: previewStyle.copyWith(color: textColor),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(
                CupertinoIcons.checkmark,
                size: 18,
                color: AppColors.accent,
              ),
          ],
        ),
      ),
    );
  }
}
