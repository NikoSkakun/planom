import 'dart:async';

import 'package:flutter/foundation.dart';

import '../settings/settings_controller.dart';
import '../spaces/space_manager.dart';
import '../utils/platform_capabilities.dart';
import 'home_widget_service.dart';

/// Keeps the iOS widgets in sync with the app's live data.
///
/// Listens to the [SpaceManager] (re-attaching to the active space's
/// controllers on every space switch) plus the global [SettingsController]
/// (accent / locale changes), and pushes a fresh "Today" payload — debounced
/// so a burst of mutations collapses into a single widget reload.
class WidgetSyncCoordinator {
  WidgetSyncCoordinator({
    required this.spaceManager,
    required this.settings,
  });

  final SpaceManager spaceManager;
  final SettingsController settings;

  final List<Listenable> _attached = [];
  Timer? _debounce;
  bool _started = false;

  void start() {
    if (_started || !PlatformCapabilities.supportsHomeWidgets) return;
    _started = true;
    spaceManager.addListener(_onSpaceChanged);
    settings.addListener(_schedule);
    _attachActiveControllers();
    // Initial push so the widget has data before the first mutation.
    unawaited(pushNow());
  }

  void _onSpaceChanged() {
    _detachActiveControllers();
    _attachActiveControllers();
    _schedule();
  }

  void _attachActiveControllers() {
    final listenables = <Listenable>[
      spaceManager.taskController,
      spaceManager.eventController,
      spaceManager.routineController,
      spaceManager.contactController,
      spaceManager.folderController,
    ];
    for (final l in listenables) {
      l.addListener(_schedule);
      _attached.add(l);
    }
  }

  void _detachActiveControllers() {
    for (final l in _attached) {
      l.removeListener(_schedule);
    }
    _attached.clear();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), pushNow);
  }

  Future<void> pushNow() async {
    if (!PlatformCapabilities.supportsHomeWidgets) return;
    await HomeWidgetService.instance.pushFromControllers(
      settings: settings,
      taskController: spaceManager.taskController,
      eventController: spaceManager.eventController,
      routineController: spaceManager.routineController,
      contactController: spaceManager.contactController,
      folderController: spaceManager.folderController,
      spaceName: spaceManager.activeSpace.name,
      activeDbName: spaceManager.dbNameFor(spaceManager.activeSpaceId),
    );
  }

  void dispose() {
    _debounce?.cancel();
    _detachActiveControllers();
    spaceManager.removeListener(_onSpaceChanged);
    settings.removeListener(_schedule);
  }
}
