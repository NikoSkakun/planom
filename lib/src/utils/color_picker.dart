import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import '../localization/strings.dart';
import '../theme/app_theme.dart';

/// Opens a user-friendly HSV color picker as a modal bottom sheet.
///
/// Returns the chosen color, or null if the user dismissed without selecting.
/// The picker exposes a 2D saturation/value square, a hue slider, a hex input
/// and a live preview, so it works for "just pick a nice color" cases and
/// precise hex entry alike.
Future<Color?> showCustomColorPicker(
  BuildContext context, {
  required Color initialColor,
  String? title,
}) async {
  final result = await showModalBottomSheet<Color?>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => _CustomColorPickerSheet(
      initialColor: initialColor,
      title: title,
    ),
  );
  return result;
}

class _CustomColorPickerSheet extends StatefulWidget {
  const _CustomColorPickerSheet({
    required this.initialColor,
    this.title,
  });

  final Color initialColor;
  final String? title;

  @override
  State<_CustomColorPickerSheet> createState() =>
      _CustomColorPickerSheetState();
}

class _CustomColorPickerSheetState extends State<_CustomColorPickerSheet> {
  late HSVColor _hsv;
  late final TextEditingController _hexCtrl;
  // While the user is typing in the hex field we suppress the round-trip back
  // into the field so the cursor doesn't jump.
  bool _hexFromInput = false;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor).withAlpha(1.0);
    _hexCtrl = TextEditingController(text: _formatHex(_hsv.toColor()));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  String _formatHex(Color c) {
    final r = c.red.toRadixString(16).padLeft(2, '0');
    final g = c.green.toRadixString(16).padLeft(2, '0');
    final b = c.blue.toRadixString(16).padLeft(2, '0');
    return '$r$g$b'.toUpperCase();
  }

  void _updateColor(HSVColor next) {
    setState(() => _hsv = next);
    if (!_hexFromInput) {
      _hexCtrl.text = _formatHex(next.toColor());
    }
  }

  void _onHexChanged(String value) {
    final cleaned = value.trim().replaceFirst('#', '');
    if (cleaned.length != 6) return;
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) return;
    _hexFromInput = true;
    setState(() => _hsv = HSVColor.fromColor(
        Color(0xFF000000 | parsed).withAlpha(255)));
    _hexFromInput = false;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final color = _hsv.toColor();

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: CupertinoColors.separator.resolveFrom(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              widget.title ?? s.customColor,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),

          // ── Saturation × Value square ─────────────────────────────────
          AspectRatio(
            aspectRatio: 1,
            child: _SaturationValuePad(
              hsv: _hsv,
              onChanged: _updateColor,
            ),
          ),
          const SizedBox(height: 16),

          // ── Hue slider ────────────────────────────────────────────────
          SizedBox(
            height: 24,
            child: _HueSlider(
              hue: _hsv.hue,
              onChanged: (h) => _updateColor(_hsv.withHue(h)),
            ),
          ),
          const SizedBox(height: 16),

          // ── Preview + hex input ───────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: CupertinoColors.separator.resolveFrom(context),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoTextField(
                  controller: _hexCtrl,
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text('#',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w500)),
                  ),
                  placeholder: 'RRGGBB',
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                      fontSize: 17, fontFamily: 'Menlo', letterSpacing: 1),
                  maxLength: 6,
                  decoration: BoxDecoration(
                    color: CupertinoColors.tertiarySystemFill
                        .resolveFrom(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  onChanged: _onHexChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Done button ───────────────────────────────────────────────
          CupertinoButton(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(12),
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(color),
            child: Text(
              s.done,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Saturation × Value pad ────────────────────────────────────────────────────

class _SaturationValuePad extends StatelessWidget {
  const _SaturationValuePad({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  void _onPan(BuildContext context, Offset localPos, Size size) {
    final s = (localPos.dx / size.width).clamp(0.0, 1.0);
    final v = (1 - localPos.dy / size.height).clamp(0.0, 1.0);
    onChanged(hsv.withSaturation(s).withValue(v));
  }

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    return LayoutBuilder(builder: (ctx, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _onPan(ctx, d.localPosition, size),
        onPanUpdate: (d) => _onPan(ctx, d.localPosition, size),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [CupertinoColors.white, hueColor],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xFF000000)],
                ),
              ),
            ),
            Positioned(
              left: hsv.saturation * size.width - 9,
              top: (1 - hsv.value) * size.height - 9,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hsv.toColor(),
                  border:
                      Border.all(color: CupertinoColors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x40000000), blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── Hue slider ────────────────────────────────────────────────────────────────

class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  static const _hueColors = [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  void _onPan(double dx, double width) {
    final clamped = dx.clamp(0.0, width);
    onChanged((clamped / width) * 360);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final width = constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _onPan(d.localPosition.dx, width),
        onPanUpdate: (d) => _onPan(d.localPosition.dx, width),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(colors: _hueColors),
              ),
            ),
            Positioned(
              left: (hue / 360 * width).clamp(0.0, width) - 11,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                  border:
                      Border.all(color: CupertinoColors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x40000000), blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
