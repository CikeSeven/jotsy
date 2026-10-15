import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/launch_reveal.dart';

const _masthead = ValueKey<String>('masthead');
const _firstCard = ValueKey<String>('first_card');
const _laterCard = ValueKey<String>('later_card');
const _action = ValueKey<String>('action');

double _opacity(WidgetTester tester, Key key) => tester
    .widget<Opacity>(
      find.ancestor(of: find.byKey(key), matching: find.byType(Opacity)).first,
    )
    .opacity;

/// 区块相对落点的纵向偏移（正值 = 仍在落点下方）。
double _offsetY(WidgetTester tester, Key key) {
  final transform = tester.widget<Transform>(
    find.ancestor(of: find.byKey(key), matching: find.byType(Transform)).last,
  );
  return transform.transform.getTranslation().y;
}

double _scale(WidgetTester tester, Key key) => tester
    .widget<Transform>(
      find
          .ancestor(of: find.byKey(key), matching: find.byType(Transform))
          .first,
    )
    .transform
    // Transform.scale 只缩放 x/y（z 轴恒为 1），读 x 轴分量。
    .entry(0, 0);

Widget _stage(Animation<double> progress) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: LaunchRevealScope(
      progress: progress,
      child: const Column(
        children: <Widget>[
          LaunchReveal(
            slot: LaunchRevealSlot.masthead,
            child: SizedBox(key: _masthead, height: 10),
          ),
          _Card(index: 0, markerKey: _firstCard),
          _Card(index: 3, markerKey: _laterCard),
          LaunchReveal(
            slot: LaunchRevealSlot.action,
            child: SizedBox(key: _action, height: 10),
          ),
        ],
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.index, required this.markerKey});

  final int index;
  final Key markerKey;

  @override
  Widget build(BuildContext context) => LaunchReveal(
    slot: LaunchRevealSlot.content(index),
    child: SizedBox(key: markerKey, height: 10),
  );
}

void main() {
  testWidgets('without a scope the child is used as is', (tester) async {
    await tester.pumpWidget(
      const LaunchReveal(
        slot: LaunchRevealSlot.masthead,
        child: SizedBox(key: _masthead),
      ),
    );
    expect(
      find.ancestor(of: find.byKey(_masthead), matching: find.byType(Opacity)),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byKey(_masthead),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });

  testWidgets('slots start hidden below their place and arrive in order', (
    tester,
  ) async {
    final progress = ValueNotifier<double>(0);
    addTearDown(progress.dispose);
    final animation = _NotifierAnimation(progress);
    await tester.pumpWidget(_stage(animation));

    for (final key in <Key>[_masthead, _firstCard, _laterCard, _action]) {
      expect(_opacity(tester, key), 0, reason: '$key');
    }
    expect(_offsetY(tester, _masthead), LaunchRevealSlot.masthead.rise);
    expect(_offsetY(tester, _firstCard), LaunchRevealSlot.content(0).rise);
    expect(_scale(tester, _action), LaunchRevealSlot.action.scaleFrom);

    // 编排进行到 40%：顶栏先于卡片、前面的卡片先于后面的卡片，FAB 尚未开始。
    progress.value = 0.4;
    await tester.pump();
    final masthead = _opacity(tester, _masthead);
    final firstCard = _opacity(tester, _firstCard);
    final laterCard = _opacity(tester, _laterCard);
    expect(masthead, greaterThan(firstCard));
    expect(firstCard, greaterThan(laterCard));
    expect(laterCard, greaterThan(0));
    expect(_opacity(tester, _action), 0);
    expect(
      _offsetY(tester, _firstCard),
      lessThan(LaunchRevealSlot.content(0).rise),
    );

    progress.value = 1;
    await tester.pump();
    for (final key in <Key>[_masthead, _firstCard, _laterCard, _action]) {
      expect(_opacity(tester, key), 1, reason: '$key');
      expect(_offsetY(tester, key), 0, reason: '$key');
      expect(_scale(tester, key), 1, reason: '$key');
    }
  });

  test('cards past the first screen share the last stagger step', () {
    expect(
      LaunchRevealSlot.content(9).start,
      LaunchRevealSlot.content(4).start,
    );
    expect(
      LaunchRevealSlot.content(4).start,
      greaterThan(LaunchRevealSlot.content(3).start),
    );
    // 每个槽位都在整段编排内走完。
    for (final slot in <LaunchRevealSlot>[
      LaunchRevealSlot.masthead,
      LaunchRevealSlot.filters,
      LaunchRevealSlot.navigation,
      LaunchRevealSlot.content(9),
      LaunchRevealSlot.action,
    ]) {
      expect(slot.start + LaunchRevealSlot.span, lessThanOrEqualTo(1));
    }
  });
}

/// 把 ValueNotifier 当作进度动画，测试里逐点设定编排进度。
class _NotifierAnimation extends Animation<double> {
  _NotifierAnimation(this._notifier);

  final ValueNotifier<double> _notifier;

  @override
  double get value => _notifier.value;

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  void addListener(VoidCallback listener) => _notifier.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _notifier.removeListener(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}
}
