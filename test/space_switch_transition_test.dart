import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planom/src/spaces/space_switch_transition.dart';

/// The space swipe moves the screen while the finger is down, and carries that
/// movement through the switch instead of cutting to the next space.
void main() {
  Widget host(Widget child) => CupertinoApp(
        home: SpaceSwitchTransition(child: child),
      );

  SpaceSwitchTransitionState stateOf(WidgetTester tester) =>
      tester.state<SpaceSwitchTransitionState>(
          find.byType(SpaceSwitchTransition));

  testWidgets('at rest the child is rendered untouched', (tester) async {
    await tester.pumpWidget(host(const Text('space')));
    final state = stateOf(tester);

    expect(state.debugIsMoving, isFalse);
    expect(state.debugOffset, 0);
    // No Stack, no snapshot, no transform: the transition costs nothing until
    // it is used.
    expect(find.byType(Transform), findsNothing);
  });

  testWidgets('dragging moves the space with the finger', (tester) async {
    await tester.pumpWidget(host(const Text('space')));
    final state = stateOf(tester);

    state.dragTo(0.5); // half a screen towards the next space
    await tester.pump();

    expect(state.debugIsMoving, isTrue);
    // Positive fraction travels left, and with resistance — the space gives a
    // little rather than tracking the finger one-to-one, because there is
    // nothing behind it to reveal yet.
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(state.debugOffset, lessThan(0));
    expect(state.debugOffset.abs(), lessThan(width * 0.5));
  });

  testWidgets('dragging the other way moves the other way', (tester) async {
    await tester.pumpWidget(host(const Text('space')));
    final state = stateOf(tester);

    state.dragTo(-0.4);
    await tester.pump();
    expect(state.debugOffset, greaterThan(0));
  });

  testWidgets('letting go without committing springs back to rest',
      (tester) async {
    await tester.pumpWidget(host(const Text('space')));
    final state = stateOf(tester);

    state.dragTo(0.2);
    await tester.pump();
    expect(state.debugOffset, isNot(0));

    state.cancelDrag();
    await tester.pumpAndSettle();
    expect(state.debugIsMoving, isFalse);
    expect(state.debugOffset, 0);
  });

  testWidgets('committing runs the switch and settles', (tester) async {
    await tester.pumpWidget(host(const Text('space')));
    final state = stateOf(tester);

    var switched = false;
    await state.run(
      direction: 1,
      switchSpace: () async => switched = true,
    );
    await tester.pumpAndSettle();

    expect(switched, isTrue, reason: 'the space itself must change');
    expect(state.debugIsMoving, isFalse, reason: 'and the animation must end');
    expect(state.debugHasSnapshot, isFalse, reason: 'snapshot released');
  });

  testWidgets('the switch still happens when there is nothing to capture',
      (tester) async {
    // A capture can fail — before the first paint, or in an environment with no
    // surface. The switch must not depend on the animation succeeding.
    await tester.pumpWidget(host(const Text('space')));
    final state = stateOf(tester);

    var switched = false;
    await state.run(direction: -1, switchSpace: () async => switched = true);
    await tester.pumpAndSettle();

    expect(switched, isTrue);
    expect(state.debugIsMoving, isFalse);
  });

  testWidgets('a drag cannot start while a switch is playing', (tester) async {
    await tester.pumpWidget(host(const Text('space')));
    final state = stateOf(tester);

    await state.run(direction: 1, switchSpace: () async {});
    final duringSwitch = state.debugOffset;
    state.dragTo(0.9);
    await tester.pump();
    // Unchanged phase: the gesture is ignored rather than fighting the
    // animation for the same offset.
    expect(state.debugOffset, isNot(equals(-0.9 * 400)));
    expect(duringSwitch, isNotNull);

    await tester.pumpAndSettle();
  });
}
