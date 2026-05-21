import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

import '../localization/strings.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _allFontKeys = GoogleFonts.asMap().keys.toList()..sort();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
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
    Navigator.of(context).pop();
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
                      isSelected: current == kSystemFontKey,
                      onTap: () => _select(kSystemFontKey),
                    );
                  }
                  final key = filtered[showSystem ? index - 1 : index];
                  final fontFn = GoogleFonts.asMap()[key];
                  final previewStyle = fontFn != null
                      ? fontFn(fontSize: 20)
                      : const TextStyle(fontSize: 20);
                  return _FontRow(
                    fontKey: key,
                    displayName: fontDisplayName(key),
                    previewStyle: previewStyle,
                    isSelected: key == current,
                    onTap: () => _select(key),
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
    required this.isSelected,
    required this.onTap,
  });

  final String fontKey;
  final String displayName;
  final TextStyle previewStyle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
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
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'The quick brown fox',
                    style: previewStyle.copyWith(
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
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
