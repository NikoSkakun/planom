import 'package:flutter/cupertino.dart';

class FastRoute<T> extends CupertinoPageRoute<T> {
  FastRoute({
    required super.builder,
    super.settings,
    super.fullscreenDialog,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);
}
