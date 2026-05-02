import 'package:flutter/cupertino.dart';

class FastRoute<T> extends CupertinoPageRoute<T> {
  FastRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);
}
