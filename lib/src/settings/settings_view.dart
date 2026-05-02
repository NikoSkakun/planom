import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'settings_controller.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.controller});

  static const routeName = '/settings';

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  letterSpacing: -0.08,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoSlidingSegmentedControl<ThemeMode>(
                groupValue: controller.themeMode,
                onValueChanged: controller.updateThemeMode,
                children: const {
                  ThemeMode.light: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Light'),
                  ),
                  ThemeMode.system: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('System'),
                  ),
                  ThemeMode.dark: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Dark'),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
