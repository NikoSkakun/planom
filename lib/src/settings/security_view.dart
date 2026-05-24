import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../security/security_service.dart';
import '../theme/app_theme.dart';

class SecuritySettingsView extends StatefulWidget {
  const SecuritySettingsView({super.key, required this.securityService});

  final SecurityService securityService;

  @override
  State<SecuritySettingsView> createState() => _SecuritySettingsViewState();
}

class _SecuritySettingsViewState extends State<SecuritySettingsView> {
  PasswordType get _type => widget.securityService.type;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    widget.securityService.isBiometricAvailable().then((available) {
      if (!mounted) return;
      setState(() => _biometricAvailable = available);
    });
  }

  String _lockTypeLabel(S s, PasswordType t) {
    switch (t) {
      case PasswordType.pin4: return s.lockTypePin4;
      case PasswordType.pin5: return s.lockTypePin5;
      case PasswordType.pin6: return s.lockTypePin6;
      case PasswordType.pin7: return s.lockTypePin7;
      case PasswordType.pin8: return s.lockTypePin8;
      case PasswordType.custom: return s.lockTypeCustom;
      case PasswordType.none: return s.lockDisabled;
    }
  }

  Future<void> _handleEnableLock(BuildContext context) async {
    final result = await _showSetPasswordSheet(context, requireCurrent: false);
    if (result != null && mounted) {
      await widget.securityService.setPassword(result.$1, result.$2);
      setState(() {});
      if (mounted) _showBanner(context, S.of(context).lockEnabled);
    }
  }

  Future<void> _handleChangeLock(BuildContext context) async {
    final s = S.of(context);
    // First verify current password
    final current = await _showVerifySheet(context, s.verifyToChange);
    if (current == null) return; // cancelled
    final ok = await widget.securityService.verify(current);
    if (!mounted) return;
    if (!ok) {
      _showError(context, s.wrongPassword);
      return;
    }
    final result = await _showSetPasswordSheet(context, requireCurrent: false);
    if (result != null && mounted) {
      await widget.securityService.setPassword(result.$1, result.$2);
      setState(() {});
      _showBanner(context, s.lockEnabled);
    }
  }

  Future<void> _handleRemoveLock(BuildContext context) async {
    final s = S.of(context);
    final current = await _showVerifySheet(context, s.verifyToDisable);
    if (current == null) return;
    final ok = await widget.securityService.verify(current);
    if (!mounted) return;
    if (!ok) {
      _showError(context, s.wrongPassword);
      return;
    }
    await widget.securityService.removePassword();
    if (mounted) {
      setState(() {});
      _showBanner(context, s.lockDisabled);
    }
  }

  void _showError(BuildContext context, String msg) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(msg),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.of(context).ok),
          ),
        ],
      ),
    );
  }

  void _showBanner(BuildContext context, String msg) {
    // Use a subtle alert since CupertinoSnackBar doesn't exist
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(msg),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.of(context).ok),
          ),
        ],
      ),
    );
  }

  Future<String?> _showVerifySheet(BuildContext context, String subtitle) async {
    final ctrl = TextEditingController();
    final s = S.of(context);
    final isPin = _type.isPin;
    String? result;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return _PasswordEntrySheet(
          title: s.currentPassword,
          subtitle: subtitle,
          isPin: isPin,
          pinLength: _type.pinLength,
          onConfirm: (pw) {
            result = pw;
            Navigator.of(ctx).pop();
          },
          onCancel: () => Navigator.of(ctx).pop(),
        );
      },
    );

    ctrl.dispose();
    return result;
  }

  Future<(String, PasswordType)?> _showSetPasswordSheet(
      BuildContext context, {required bool requireCurrent}) async {
    PasswordType chosenType = PasswordType.pin6;
    String? result;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _SetPasswordSheet(
        initialType: chosenType,
        onConfirm: (pw, t) {
          result = pw;
          chosenType = t;
          Navigator.of(ctx).pop();
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );

    if (result == null) return null;
    return (result!, chosenType);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final bg = CupertinoDynamicColor.resolve(
        CupertinoColors.tertiarySystemBackground, context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        middle: Text(s.sectionSecurity),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            Text(
              s.appLock,
              style: TextStyle(
                  fontSize: 13, color: labelColor, letterSpacing: -0.08),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  _Row(
                    label: s.lockType,
                    trailing: _lockTypeLabel(s, _type),
                    hasChevron: false,
                  ),
                  Container(
                      height: 0.5,
                      color: CupertinoColors.separator.resolveFrom(context)),
                  if (_type == PasswordType.none)
                    _TapRow(
                      label: s.enableLock,
                      onTap: () => _handleEnableLock(context),
                    )
                  else ...[
                    _TapRow(
                      label: s.changeLock,
                      onTap: () => _handleChangeLock(context),
                    ),
                    Container(
                        height: 0.5,
                        color:
                            CupertinoColors.separator.resolveFrom(context)),
                    _TapRow(
                      label: s.removeLock,
                      isDestructive: true,
                      onTap: () => _handleRemoveLock(context),
                    ),
                  ],
                  if (_type != PasswordType.none && _biometricAvailable) ...[
                    Container(
                        height: 0.5,
                        color: CupertinoColors.separator.resolveFrom(context)),
                    _SwitchRow(
                      label: s.useBiometric,
                      value: widget.securityService.biometricEnabled,
                      onChanged: (v) async {
                        await widget.securityService.setBiometricEnabled(v);
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ],
              ),
            ),
            if (_type == PasswordType.none) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  s.forgotPasswordHint,
                  style: TextStyle(fontSize: 13, color: labelColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Simple row widgets ────────────────────────────────────────────────────────

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 16)),
          ),
          CupertinoSwitch(
            value: value,
            activeColor: AppColors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.trailing, this.hasChevron = true});
  final String label;
  final String? trailing;
  final bool hasChevron;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 17,
                    color: CupertinoColors.label)),
          ),
          if (trailing != null)
            Text(trailing!,
                style: TextStyle(
                    fontSize: 15,
                    color:
                        CupertinoColors.secondaryLabel.resolveFrom(context))),
          if (hasChevron) ...[
            const SizedBox(width: 4),
            Icon(CupertinoIcons.chevron_right,
                size: 14,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
          ],
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  const _TapRow(
      {required this.label, required this.onTap, this.isDestructive = false});
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  color: isDestructive
                      ? CupertinoColors.destructiveRed
                      : CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
                size: 14,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
          ],
        ),
      ),
    );
  }
}

// ── Password entry sheet (verify) ─────────────────────────────────────────────

class _PasswordEntrySheet extends StatefulWidget {
  const _PasswordEntrySheet({
    required this.title,
    required this.subtitle,
    required this.isPin,
    required this.pinLength,
    required this.onConfirm,
    required this.onCancel,
  });

  final String title;
  final String subtitle;
  final bool isPin;
  final int pinLength;
  final ValueChanged<String> onConfirm;
  final VoidCallback onCancel;

  @override
  State<_PasswordEntrySheet> createState() => _PasswordEntrySheetState();
}

class _PasswordEntrySheetState extends State<_PasswordEntrySheet>
    with SingleTickerProviderStateMixin {
  String _entered = '';
  final _ctrl = TextEditingController();
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_entered.length >= widget.pinLength) return;
    setState(() => _entered += d);
    if (_entered.length == widget.pinLength) widget.onConfirm(_entered);
  }

  void _onBack() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final s = S.of(context);

    return Container(
      color: bg,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Text(widget.title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color:
                        CupertinoColors.secondaryLabel.resolveFrom(context))),
            const SizedBox(height: 24),
            if (widget.isPin) ...[
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                    offset: Offset(_shakeAnim.value, 0), child: child!),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.pinLength, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _entered.length
                            ? CupertinoColors.label.resolveFrom(context)
                            : CupertinoColors.systemGrey4
                                .resolveFrom(context),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),
              _Numpad(onDigit: _onDigit, onBack: _onBack),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: CupertinoTextField(
                  controller: _ctrl,
                  obscureText: true,
                  placeholder: s.enterPassword,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  onSubmitted: (_) => widget.onConfirm(_ctrl.text.trim()),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        onPressed: widget.onCancel,
                        child: Text(s.cancel,
                            style: const TextStyle(
                                color: CupertinoColors.destructiveRed)),
                      ),
                    ),
                    Expanded(
                      child: CupertinoButton.filled(
                        onPressed: () => widget.onConfirm(_ctrl.text.trim()),
                        child: Text(s.ok),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (widget.isPin)
              CupertinoButton(
                onPressed: widget.onCancel,
                child: Text(s.cancel,
                    style: const TextStyle(
                        color: CupertinoColors.destructiveRed)),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Set password sheet (create/change) ───────────────────────────────────────

class _SetPasswordSheet extends StatefulWidget {
  const _SetPasswordSheet({
    required this.initialType,
    required this.onConfirm,
    required this.onCancel,
  });

  final PasswordType initialType;
  final void Function(String password, PasswordType type) onConfirm;
  final VoidCallback onCancel;

  @override
  State<_SetPasswordSheet> createState() => _SetPasswordSheetState();
}

class _SetPasswordSheetState extends State<_SetPasswordSheet> {
  late PasswordType _selectedType;
  int _step = 0; // 0 = choose type, 1 = enter, 2 = confirm
  String _first = '';
  String _second = '';
  bool _mismatch = false;
  final _ctrl1 = TextEditingController();
  final _ctrl2 = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    super.dispose();
  }

  bool get _isPin => _selectedType.isPin;
  int get _pinLen => _selectedType.pinLength;

  void _onDigitStep1(String d) {
    if (_first.length >= _pinLen) return;
    setState(() => _first += d);
    if (_first.length == _pinLen) setState(() => _step = 2);
  }

  void _onBackStep1() {
    if (_first.isEmpty) return;
    setState(() => _first = _first.substring(0, _first.length - 1));
  }

  void _onDigitStep2(String d) {
    if (_second.length >= _pinLen) return;
    setState(() => _second += d);
    if (_second.length == _pinLen) _finalize(_first, _second);
  }

  void _onBackStep2() {
    if (_second.isEmpty) return;
    setState(() => _second = _second.substring(0, _second.length - 1));
  }

  void _finalize(String a, String b) {
    if (a != b) {
      setState(() {
        _mismatch = true;
        _second = '';
        _first = '';
        _step = 1;
      });
      return;
    }
    widget.onConfirm(a, _selectedType);
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final s = S.of(context);

    return Container(
      color: bg,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            if (_step == 0) _buildTypeChooser(s)
            else if (_step == 1) _buildEnterStep(s)
            else _buildConfirmStep(s),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChooser(S s) {
    final types = [
      PasswordType.pin4,
      PasswordType.pin5,
      PasswordType.pin6,
      PasswordType.pin7,
      PasswordType.pin8,
      PasswordType.custom,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.lockType,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        ...types.map((t) {
          final label = _typeName(s, t);
          final selected = t == _selectedType;
          return GestureDetector(
            onTap: () => setState(() { _selectedType = t; _step = 1; _mismatch = false; }),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                      child: Text(label,
                          style: const TextStyle(fontSize: 17))),
                  if (selected)
                    Icon(CupertinoIcons.checkmark,
                        size: 18, color: AppColors.accent),
                ],
              ),
            ),
          );
        }),
        CupertinoButton(
          onPressed: widget.onCancel,
          child: Text(s.cancel,
              style:
                  const TextStyle(color: CupertinoColors.destructiveRed)),
        ),
      ],
    );
  }

  String _typeName(S s, PasswordType t) {
    switch (t) {
      case PasswordType.pin4: return s.lockTypePin4;
      case PasswordType.pin5: return s.lockTypePin5;
      case PasswordType.pin6: return s.lockTypePin6;
      case PasswordType.pin7: return s.lockTypePin7;
      case PasswordType.pin8: return s.lockTypePin8;
      case PasswordType.custom: return s.lockTypeCustom;
      case PasswordType.none: return '';
    }
  }

  Widget _buildEnterStep(S s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.enterNewPassword,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        if (_mismatch) ...[
          const SizedBox(height: 8),
          Text(s.passwordsDoNotMatch,
              style: const TextStyle(
                  fontSize: 13, color: CupertinoColors.destructiveRed)),
        ],
        const SizedBox(height: 24),
        if (_isPin) ...[
          _PinDots(entered: _first, total: _pinLen),
          const SizedBox(height: 24),
          _Numpad(onDigit: _onDigitStep1, onBack: _onBackStep1),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: CupertinoTextField(
              controller: _ctrl1,
              obscureText: true,
              placeholder: s.enterNewPassword,
              textAlign: TextAlign.center,
              autofocus: true,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: CupertinoButton.filled(
              onPressed: () {
                if (_ctrl1.text.trim().isEmpty) return;
                setState(() { _first = _ctrl1.text.trim(); _step = 2; });
              },
              child: Text(s.done),
            ),
          ),
        ],
        CupertinoButton(
          onPressed: () => setState(() { _step = 0; _first = ''; }),
          child: Text(s.cancel,
              style:
                  const TextStyle(color: CupertinoColors.destructiveRed)),
        ),
      ],
    );
  }

  Widget _buildConfirmStep(S s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.confirmNewPassword,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        if (_isPin) ...[
          _PinDots(entered: _second, total: _pinLen),
          const SizedBox(height: 24),
          _Numpad(onDigit: _onDigitStep2, onBack: _onBackStep2),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: CupertinoTextField(
              controller: _ctrl2,
              obscureText: true,
              placeholder: s.confirmNewPassword,
              textAlign: TextAlign.center,
              autofocus: true,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: CupertinoButton.filled(
              onPressed: () => _finalize(_first, _ctrl2.text.trim()),
              child: Text(s.done),
            ),
          ),
        ],
        CupertinoButton(
          onPressed: () => setState(() { _step = 1; _second = ''; }),
          child: Text(s.cancel,
              style:
                  const TextStyle(color: CupertinoColors.destructiveRed)),
        ),
      ],
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _PinDots extends StatelessWidget {
  const _PinDots({required this.entered, required this.total});
  final String entered;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < entered.length
                ? CupertinoColors.label.resolveFrom(context)
                : CupertinoColors.systemGrey4.resolveFrom(context),
          ),
        );
      }),
    );
  }
}

class _Numpad extends StatelessWidget {
  const _Numpad({required this.onDigit, required this.onBack});
  final ValueChanged<String> onDigit;
  final VoidCallback onBack;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _rows.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((d) {
            if (d.isEmpty) return const SizedBox(width: 80, height: 64);
            final isBack = d == '⌫';
            return SizedBox(
              width: 80,
              height: 64,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: isBack ? onBack : () => onDigit(d),
                child: Text(d,
                    style: TextStyle(
                        fontSize: isBack ? 20 : 26,
                        color: CupertinoColors.label.resolveFrom(context),
                        fontWeight: FontWeight.w300)),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
