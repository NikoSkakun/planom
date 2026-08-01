import 'package:flutter/cupertino.dart';

import '../integrations/google/google_calendar_controller.dart';
import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../utils/fast_route.dart';
import '../utils/selection_menu.dart';
import 'finance_settings_view.dart';
import 'module_settings_views.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';
import 'tasks_settings_view.dart';

/// Logical tab indices that can carry a per-tab + button override. (Notes only
/// uses the global side in practice, but it's still configurable for symmetry.)
const List<int> _plusOverrideTabs = [0, 1, 2, 3, 5];

String _tabName(S s, int tab) {
  switch (tab) {
    case 0:
      return s.tabTasks;
    case 1:
      return s.tabNotes;
    case 2:
      return s.tabCalendar;
    case 3:
      return s.tabRoutines;
    case 5:
      return s.tabFinance;
    default:
      return '';
  }
}

String _sideLabel(S s, PlusButtonSide side) =>
    side == PlusButtonSide.left ? s.sideLeft : s.sideRight;

/// Dedicated screen for configuring the floating + button: its global side,
/// its size, and shortcuts into each tab's per-tab override.
class PlusButtonSettingsView extends StatelessWidget {
  const PlusButtonSettingsView({
    super.key,
    required this.controller,
    this.googleCalendarController,
  });

  final SettingsController controller;
  final GoogleCalendarController? googleCalendarController;

  Future<void> _pickSide(BuildContext context) async {
    final s = S.of(context);
    final selected = await showSelectionMenu<PlusButtonSide>(
      context: context,
      title: s.plusButtonPosition,
      current: controller.plusButtonSide,
      options: [
        SelectionMenuOption(value: PlusButtonSide.right, label: s.sideRight),
        SelectionMenuOption(value: PlusButtonSide.left, label: s.sideLeft),
      ],
    );
    if (selected != null) await controller.updatePlusButtonSide(selected);
  }

  void _openTab(BuildContext context, int tab) {
    Widget page;
    switch (tab) {
      case 1:
        page = NotesSettingsView(controller: controller);
      case 2:
        page = CalendarSettingsView(
          controller: controller,
          googleCalendarController: googleCalendarController,
        );
      case 3:
        page = RoutinesSettingsView(controller: controller);
      case 5:
        page = FinanceSettingsView(controller: controller);
      case 0:
      default:
        page = TasksSettingsView(controller: controller);
    }
    Navigator.of(context).push(FastRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.plusButton),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                SettingsSectionHeader(s.plusButtonPosition),
                SettingsNavRow(
                  label: s.plusButtonPosition,
                  trailingLabel: _sideLabel(s, controller.plusButtonSide),
                  onTap: () => _pickSide(context),
                ),

                const SizedBox(height: 18),
                SettingsSectionHeader(s.plusButtonSize),
                _PlusSizeControl(controller: controller),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    s.plusButtonSizeHint,
                    style: TextStyle(fontSize: 13, color: labelColor),
                  ),
                ),

                const SizedBox(height: 18),
                SettingsSectionHeader(s.plusButtonPerTab),
                for (var i = 0; i < _plusOverrideTabs.length; i++) ...[
                  if (i > 0) const SizedBox(height: 1),
                  Builder(builder: (ctx) {
                    final tab = _plusOverrideTabs[i];
                    final override = controller.plusButtonSideOverride(tab);
                    return SettingsNavRow(
                      label: _tabName(s, tab),
                      trailingLabel: override == null
                          ? s.plusButtonInherit
                          : _sideLabel(s, override),
                      onTap: () => _openTab(ctx, tab),
                    );
                  }),
                ],
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    s.plusButtonPerTabHint,
                    style: TextStyle(fontSize: 13, color: labelColor),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Live-preview slider for the + button size. Holds the value locally while
/// dragging and only persists (and reschedules the global value) on release to
/// avoid hammering the settings store per frame.
class _PlusSizeControl extends StatefulWidget {
  const _PlusSizeControl({required this.controller});

  final SettingsController controller;

  @override
  State<_PlusSizeControl> createState() => _PlusSizeControlState();
}

class _PlusSizeControlState extends State<_PlusSizeControl> {
  late double _value = widget.controller.plusButtonScale;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemBackground,
      context,
    );
    final dimension = 52.0 * _value;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Live preview at the chosen size, sized to a stable max box so the
          // row height doesn't jump as the slider moves.
          SizedBox(
            width: 52 * 1.6,
            height: 52 * 1.6,
            child: Center(
              child: Container(
                width: dimension,
                height: dimension,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  CupertinoIcons.plus,
                  color: CupertinoColors.white,
                  size: 24 * _value,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoSlider(
              value: _value,
              min: 0.6,
              max: 1.6,
              divisions: 10,
              activeColor: AppColors.accent,
              onChanged: (v) => setState(() => _value = v),
              onChangeEnd: (v) => widget.controller.updatePlusButtonScale(v),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(
              '${(_value * 100).round()}%',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable row that lets the user override the + button side for [tab]
/// (Default = inherit the global side). Placed inside each tab's module
/// settings page; the Plus Button settings page links here.
class PlusButtonOverrideRow extends StatelessWidget {
  const PlusButtonOverrideRow({
    super.key,
    required this.controller,
    required this.tab,
  });

  final SettingsController controller;
  final int tab;

  Future<void> _pick(BuildContext context) async {
    final s = S.of(context);
    // Sentinel for "inherit global side".
    const inheritSentinel = -1;
    int encode(PlusButtonSide? side) =>
        side == null ? inheritSentinel : side.index;
    final selected = await showSelectionMenu<int>(
      context: context,
      title: s.plusButtonPosition,
      current: encode(controller.plusButtonSideOverride(tab)),
      options: [
        SelectionMenuOption(
            value: inheritSentinel, label: s.plusButtonInherit),
        SelectionMenuOption(
            value: PlusButtonSide.right.index, label: s.sideRight),
        SelectionMenuOption(
            value: PlusButtonSide.left.index, label: s.sideLeft),
      ],
    );
    if (selected == null) return;
    await controller.updatePlusButtonSideOverride(
      tab,
      selected == inheritSentinel ? null : PlusButtonSide.values[selected],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final override = controller.plusButtonSideOverride(tab);
        return SettingsNavRow(
          label: s.plusButtonPosition,
          trailingLabel: override == null
              ? s.plusButtonInherit
              : _sideLabel(s, override),
          onTap: () => _pick(context),
        );
      },
    );
  }
}
