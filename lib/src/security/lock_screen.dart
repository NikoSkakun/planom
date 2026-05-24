import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../theme/app_theme.dart';
import 'security_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.securityService,
    required this.onUnlocked,
  });

  final SecurityService securityService;
  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  String _entered = '';
  bool _showError = false;
  bool _isChecking = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  // custom-text mode
  final _textCtrl = TextEditingController();
  final _textFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);

    // Auto-prompt the biometric sheet on display when the user has opted in.
    // Failures (cancel, no enrolment) fall through to the manual PIN entry.
    if (widget.securityService.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _tryBiometric() async {
    if (!mounted) return;
    final s = S.of(context);
    final ok = await widget.securityService
        .authenticateBiometric(s.unlockPrompt);
    if (!mounted) return;
    if (ok) widget.onUnlocked();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _textCtrl.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  bool get _isPin => widget.securityService.type.isPin;
  int get _pinLength => widget.securityService.type.pinLength;

  void _onDigit(String d) {
    if (_isChecking) return;
    if (_entered.length >= _pinLength) return;
    setState(() { _entered += d; _showError = false; });
    if (_entered.length == _pinLength) _submit(_entered);
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _submit(String password) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    final ok = await widget.securityService.verify(password);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
      return;
    }
    _shakeCtrl.forward(from: 0);
    setState(() {
      _entered = '';
      _showError = true;
      _isChecking = false;
      if (!_isPin) _textCtrl.clear();
    });
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (i) {
        final filled = i < _entered.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? CupertinoColors.label.resolveFrom(context)
                : CupertinoColors.systemGrey4.resolveFrom(context),
          ),
        );
      }),
    );
  }

  Widget _buildNumpad() {
    const digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: digits.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((d) {
            if (d.isEmpty) return const SizedBox(width: 88, height: 72);
            final isBack = d == '⌫';
            return SizedBox(
              width: 88,
              height: 72,
              child: Semantics(
                label: isBack ? 'Backspace' : d,
                button: true,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: isBack ? _onBackspace : () => _onDigit(d),
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: isBack ? 22 : 28,
                      color: CupertinoColors.label.resolveFrom(context),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildCustomInput(S s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          CupertinoTextField(
            controller: _textCtrl,
            focusNode: _textFocus,
            obscureText: true,
            placeholder: s.enterPassword,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17),
            onSubmitted: (_) => _submit(_textCtrl.text.trim()),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: _isChecking ? null : () => _submit(_textCtrl.text.trim()),
              child: Text(s.ok),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bg = CupertinoColors.systemBackground.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.lock_fill, size: 44),
            const SizedBox(height: 24),
            Text(
              'planom',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              s.enterPassword,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 32),
            if (_isPin) ...[
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0),
                  child: child,
                ),
                child: _buildDots(),
              ),
              const SizedBox(height: 8),
              AnimatedOpacity(
                opacity: _showError ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  s.wrongPassword,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.destructiveRed,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildNumpad(),
            ] else ...[
              _buildCustomInput(s),
              const SizedBox(height: 12),
              AnimatedOpacity(
                opacity: _showError ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  s.wrongPassword,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.destructiveRed,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (widget.securityService.biometricEnabled)
              CupertinoButton(
                onPressed: _tryBiometric,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.lock_open, size: 18),
                    const SizedBox(width: 8),
                    Text(s.useBiometric),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              s.forgotPasswordHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
