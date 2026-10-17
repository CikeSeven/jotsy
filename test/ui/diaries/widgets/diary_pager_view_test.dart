import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_behavior.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_pager_effects.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_pager_view.dart';

import '../../../support/expressive_test_theme.dart';

/// 一页：可竖向滚动的长列表 + 一个横向滑块；标题“第 N 页”。
class _Page extends StatefulWidget {
  const _Page({super.key, required this.position});

  final DiaryPagerPosition position;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  double slider = 0.5;

  @override
  Widget build(BuildContext context) {
    final position = widget.position;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        Text('第 ${position.index} 页'),
        Slider(
          key: ValueKey<String>('slider-${position.index}'),
          value: slider,
          onChanged: (double v) => setState(() => slider = v),
        ),
        TextButton(onPressed: position.onNext, child: const Text('next')),
        for (var i = 0; i < 40; i++)
          SizedBox(height: 48, child: Text('行 ${position.index}-$i')),
      ],
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  int count = 3,
  int initialPage = 0,
  DiaryPreviewBehavior behavior = DiaryPreviewBehavior.defaults,
  DiaryPreviewNavigationStyle navigation = const DiaryPreviewNavigationStyle(),
  bool locked = false,
  ValueChanged<int>? onPageChanged,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DiaryPagerView(
          itemCount: count,
          initialPage: initialPage,
          behavior: behavior,
          navigation: navigation,
          locked: locked,
          onPageChanged: onPageChanged,
          itemBuilder: (BuildContext context, DiaryPagerPosition position) =>
              _Page(key: ValueKey<int>(position.index), position: position),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 按 [degrees]（偏离水平方向的角度）向左上方匀速拖动 [length]，每步一帧。
Future<void> _swipe(
  WidgetTester tester, {
  required double degrees,
  double length = 300,
  Offset start = const Offset(300, 600),
}) async {
  final radians = degrees * math.pi / 180;
  const steps = 60;
  final step = Offset(
    -math.cos(radians) * length / steps,
    -math.sin(radians) * length / steps,
  );
  final gesture = await tester.startGesture(start);
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(step);
    await tester.pump(const Duration(milliseconds: 8));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

bool _onstage(String text) => find.text(text).evaluate().isNotEmpty;

DiaryPreviewBehavior _sensitivity(DiaryPreviewSwipeSensitivity value) =>
    DiaryPreviewBehavior(swipeSensitivity: value);

void main() {
  testWidgets('a horizontal swipe turns to the next page', (tester) async {
    final changes = <int>[];
    await _pump(tester, onPageChanged: changes.add);
    await _swipe(tester, degrees: 0);
    expect(_onstage('第 1 页'), isTrue);
    expect(_onstage('第 0 页'), isFalse);
    expect(changes, <int>[1]);
  });

  testWidgets('a diagonal drag scrolls the page instead of turning it', (
    tester,
  ) async {
    await _pump(tester);
    await _swipe(tester, degrees: 45);
    expect(_onstage('第 0 页'), isFalse, reason: 'the list scrolled up');
    expect(_onstage('行 0-10'), isTrue);
    expect(_onstage('行 1-10'), isFalse);
  });

  testWidgets('strict needs a flatter swipe than standard', (tester) async {
    // 25°：标准（约 34° 以内）翻页，防误触（约 22° 以内）只滚动正文。
    await _pump(
      tester,
      behavior: _sensitivity(DiaryPreviewSwipeSensitivity.standard),
    );
    await _swipe(tester, degrees: 25);
    expect(_onstage('第 1 页'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(
      tester,
      behavior: _sensitivity(DiaryPreviewSwipeSensitivity.strict),
    );
    await _swipe(tester, degrees: 25);
    expect(_onstage('行 0-10'), isTrue);
    expect(_onstage('行 1-10'), isFalse);
  });

  testWidgets('sensitive pages at angles that standard reads as scrolling', (
    tester,
  ) async {
    await _pump(
      tester,
      behavior: _sensitivity(DiaryPreviewSwipeSensitivity.standard),
    );
    await _swipe(tester, degrees: 40);
    expect(_onstage('行 1-10'), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(
      tester,
      behavior: _sensitivity(DiaryPreviewSwipeSensitivity.sensitive),
    );
    await _swipe(tester, degrees: 40);
    expect(_onstage('第 1 页'), isTrue);
  });

  testWidgets('strict ignores a quick short flick', (tester) async {
    for (final sensitivity in <DiaryPreviewSwipeSensitivity>[
      DiaryPreviewSwipeSensitivity.standard,
      DiaryPreviewSwipeSensitivity.strict,
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, behavior: _sensitivity(sensitivity));
      // 约 600dp/s 的短甩：超过平台默认阈值，低于防误触的 800。
      await tester.fling(find.text('第 0 页'), const Offset(-80, 0), 600);
      await tester.pumpAndSettle();
      expect(
        _onstage('第 1 页'),
        sensitivity == DiaryPreviewSwipeSensitivity.standard,
        reason: sensitivity.name,
      );
    }
  });

  testWidgets('dragging a slider inside a page does not turn the page', (
    tester,
  ) async {
    for (final sensitivity in DiaryPreviewSwipeSensitivity.values) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, behavior: _sensitivity(sensitivity));
      final slider = find.byKey(const ValueKey<String>('slider-0'));
      final before = tester.widget<Slider>(slider).value;
      await tester.drag(slider, const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(_onstage('第 0 页'), isTrue, reason: sensitivity.name);
      expect(tester.widget<Slider>(slider).value, lessThan(before));
    }
  });

  testWidgets('with swiping off drags do nothing but next still works', (
    tester,
  ) async {
    await _pump(
      tester,
      behavior: const DiaryPreviewBehavior(swipeBetweenDiaries: false),
    );
    await _swipe(tester, degrees: 0);
    expect(_onstage('第 0 页'), isTrue);

    await tester.tap(find.text('next'));
    await tester.pumpAndSettle();
    expect(_onstage('第 1 页'), isTrue);
  });

  testWidgets('a locked pager neither drags nor pages programmatically', (
    tester,
  ) async {
    await _pump(tester, locked: true);
    await _swipe(tester, degrees: 0);
    await tester.tap(find.text('next'));
    await tester.pumpAndSettle();
    expect(_onstage('第 0 页'), isTrue);
  });

  testWidgets('reduce motion jumps straight to the next page', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pump(tester);
    await tester.tap(find.text('next'));
    await tester.pump();
    expect(_onstage('第 1 页'), isTrue);
    expect(_onstage('第 0 页'), isFalse);
  });

  testWidgets('screen readers get previous and next page actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, initialPage: 1);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(DiaryPagerView)),
    );
    final node = tester.getSemantics(
      find
          .ancestor(
            of: find.text('第 1 页'),
            matching: find.byWidgetPredicate(
              (Widget widget) =>
                  widget is Semantics &&
                  widget.properties.customSemanticsActions != null,
            ),
          )
          .first,
    );
    final labels = <String>[
      for (final id in node.getSemanticsData().customSemanticsActionIds ?? [])
        CustomSemanticsAction.getAction(id)!.label!,
    ];
    expect(
      labels,
      containsAll(<String>[l10n.diaryPreviewPrevious, l10n.diaryPreviewNext]),
    );
    semantics.dispose();
  });

  testWidgets('only the current page enables heroes, visible pages tick', (
    tester,
  ) async {
    await _pump(tester, initialPage: 1);
    bool heroOf(int index) => tester
        .widget<HeroMode>(
          find
              .ancestor(
                of: find.byKey(ValueKey<int>(index), skipOffstage: false),
                matching: find.byType(HeroMode, skipOffstage: false),
              )
              .first,
        )
        .enabled;
    bool tickerOf(int index) => TickerMode.valuesOf(
      tester.element(find.byKey(ValueKey<int>(index), skipOffstage: false)),
    ).enabled;
    expect(heroOf(1), isTrue);
    expect(heroOf(0), isFalse);
    expect(heroOf(2), isFalse);
    expect(tickerOf(1), isTrue);
    expect(tickerOf(0), isFalse);

    // 拖到一半：露出的两页都在走 ticker，共享元素仍只属于四舍五入的那页。
    final gesture = await tester.startGesture(const Offset(300, 600));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(-8, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }
    expect(tickerOf(2), isTrue);
    expect(tickerOf(1), isTrue);
    expect(heroOf(2), isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('turning pages vibrates only when enabled', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(tester);
    await _swipe(tester, degrees: 0);
    expect(calls, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(
      tester,
      behavior: const DiaryPreviewBehavior(hapticOnPage: true),
    );
    await _swipe(tester, degrees: 0);
    expect(calls, <String>['HapticFeedbackType.lightImpact']);
  });

  testWidgets(
    'pulling past either end shows the edge hint while dragging',
    (tester) async {
      await _pump(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DiaryPagerView)),
      );
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: find.byType(DiaryPagerEdgeHint),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;
      expect(opacity(), 0);

      final gesture = await tester.startGesture(const Offset(100, 600));
      for (var i = 0; i < 30; i++) {
        await gesture.moveBy(const Offset(8, 0));
        await tester.pump(const Duration(milliseconds: 8));
      }
      expect(find.text(l10n.diaryPreviewFirstDiary), findsOneWidget);
      expect(opacity(), greaterThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(opacity(), 0);
      expect(_onstage('第 0 页'), isTrue);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('the edge hint can be turned off', (tester) async {
    await _pump(
      tester,
      navigation: const DiaryPreviewNavigationStyle(edgeHint: false),
    );
    expect(find.byType(DiaryPagerEdgeHint), findsNothing);
  });

  testWidgets('switching the transition keeps each page state', (tester) async {
    var navigation = const DiaryPreviewNavigationStyle();
    late StateSetter rebuild;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            rebuild = setState;
            return Scaffold(
              body: DiaryPagerView(
                itemCount: 3,
                navigation: navigation,
                itemBuilder: (BuildContext context, DiaryPagerPosition p) =>
                    _Page(key: ValueKey<int>(p.index), position: p),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state<_PageState>(find.byKey(const ValueKey<int>(0)));
    for (final transition in DiaryPreviewPageTransition.values.reversed) {
      rebuild(
        () => navigation = DiaryPreviewNavigationStyle(transition: transition),
      );
      await tester.pumpAndSettle();
      expect(
        tester.state<_PageState>(find.byKey(const ValueKey<int>(0))),
        same(state),
      );
    }

    // 淡入：拖到一半时当前页半透明、原地不动。
    rebuild(
      () => navigation = const DiaryPreviewNavigationStyle(
        transition: DiaryPreviewPageTransition.fade,
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(300, 600));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(-8, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }
    final opacity = tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(const ValueKey<int>(0)),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    expect(opacity, inExclusiveRange(0, 1));
    expect(tester.getTopLeft(find.byKey(const ValueKey<int>(0))).dx, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
