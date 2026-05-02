import 'package:flutter/cupertino.dart';

class RoutinesView extends StatelessWidget {
  const RoutinesView({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Routines'),
      ),
      child: Center(child: Text('Routines')),
    );
  }
}
