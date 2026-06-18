import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../theme/app_theme.dart';
import 'money.dart';

/// Modal currency picker. Returns the chosen ISO code, or null if dismissed.
Future<String?> showCurrencyPicker(BuildContext context,
    {String? current}) async {
  String? result;
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) {
      final s = S.of(ctx);
      return Container(
        height: 420,
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(s.cancel),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    Text(s.financeCurrency,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 60),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: Currencies.all.length,
                  itemBuilder: (c, i) {
                    final cur = Currencies.all[i];
                    final selected = cur.code == current;
                    return CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      onPressed: () {
                        result = cur.code;
                        Navigator.of(ctx).pop();
                      },
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(cur.symbol,
                                style: TextStyle(
                                    fontSize: 17,
                                    color: CupertinoColors.label
                                        .resolveFrom(ctx))),
                          ),
                          Expanded(
                            child: Text('${cur.code} · ${cur.name}',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: CupertinoColors.label
                                        .resolveFrom(ctx))),
                          ),
                          if (selected)
                            Icon(CupertinoIcons.checkmark,
                                color: AppColors.accent, size: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result;
}
