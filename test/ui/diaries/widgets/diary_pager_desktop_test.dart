import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_pager_view.dart';

import '../../../support/expressive_test_theme.dart';

const _previous = ValueKey<String>('desktop-page-previous');
const _next = ValueKey<String>('desktop-page-next');

/// 从首页推入一个翻页器路由（Esc 要有可返回的上一页）。
Future<void> _pump(
  WidgetTester tester, {
  int count = 3,
  bool desktopControls = true,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => Scaffold(
                    body: DiaryPagerView(
                      itemCount: count,
                      desktopControls: desktopControls,
                      itemBuilder:
                          (BuildContext context, DiaryPagerPosition position) =>
                              ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: <Widget>[
                                  Text('第 ${position.index} 页'),
                                ],
                              ),
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// 鼠标移到页面中间（悬停）。
Future<void> _hover(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(640, 400));
  addTearDown(mouse.removePointer);
  await mouse.moveTo(const Offset(650, 420));
  await tester.pumpAndSettle();
}

double _opacity(WidgetTester tester, Key key) => tester
    .widget<AnimatedOpacity>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

bool _onstage(String text) => find.text(text).evaluate().isNotEmpty;

void main() {
  testWidgets('hovering shows only the arrows that can turn the page', (
    tester,
  ) async {
    await _pump(tester);
    expect(_opacity(tester, _next), 0, reason: 'hidden before hovering');
    await _hover(tester);
    expect(_opacity(tester, _previous), 0, reason: 'already on the first');
    expect(_opacity(tester, _next), 1);
    // 44dp 的圆，贴在页面左右边缘、竖直居中。
    final next = tester.getRect(
      find.descendant(of: find.byKey(_next), matching: find.byType(IconButton)),
    );
    expect(next.size, const Size(44, 44));
    expect(next.right, closeTo(1280 - 16, 0.5));
    expect(next.center.dy, closeTo(400, 0.5));

    await tester.tap(
      find.descendant(of: find.byKey(_next), matching: find.byType(IconButton)),
    );
    await tester.pumpAndSettle();
    expect(_onstage('第 1 页'), isTrue);
    expect(_opacity(tester, _previous), 1);
    expect(_opacity(tester, _next), 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('arrow keys and page keys turn the page on desktop', (
    tester,
  ) async {
    await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_onstage('第 1 页'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(_onstage('第 2 页'), isTrue);
    // 已在最后一篇：不再前进。
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_onstage('第 2 页'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_onstage('第 1 页'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(_onstage('第 0 页'), isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('escape closes the preview like the back button', (tester) async {
    await _pump(tester);
    expect(find.text('open'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('touch platforms get no arrows and keep the keys untouched', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(_next), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_onstage('第 0 页'), isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the settings preview keeps desktop controls off', (
    tester,
  ) async {
    await _pump(tester, desktopControls: false);
    expect(find.byKey(_next), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('open'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
