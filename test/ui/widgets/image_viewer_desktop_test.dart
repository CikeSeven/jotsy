import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/image_viewer_page.dart';

import '../../support/expressive_test_theme.dart';

const _previous = ValueKey<String>('desktop-page-previous');
const _next = ValueKey<String>('desktop-page-next');

/// 首页一个按钮经 [openImageViewer] 打开两张图（Esc 要有上一页可回）。
Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => openImageViewer(
                context,
                items: const <ImageViewerItem>[
                  ImageViewerItem(source: '/missing/first.jpg'),
                  ImageViewerItem(source: '/missing/second.jpg'),
                ],
                initialIndex: 0,
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

double _opacity(WidgetTester tester, Key key) => tester
    .widget<AnimatedOpacity>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

/// 当前页（PageView 里未被裁掉的那一页）的缩放倍数。
double _scale(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
    .transformationController!
    .value
    .getMaxScaleOnAxis();

ScrollPhysics? _pagePhysics(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).physics;

void main() {
  testWidgets(
    'hover arrows and arrow keys page through images, escape closes',
    (tester) async {
      await _open(tester);
      final semantics = tester.ensureSemantics();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(640, 400));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(const Offset(650, 420));
      await tester.pumpAndSettle();
      expect(_opacity(tester, _previous), 0, reason: 'first image');
      expect(_opacity(tester, _next), 1);

      await tester.tap(
        find.descendant(
          of: find.byKey(_next),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('2 / 2'), findsOneWidget);
      expect(_opacity(tester, _next), 0, reason: 'last image');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('1 / 2'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('2 / 2'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerPage), findsNothing);
      expect(find.text('open'), findsOneWidget);
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'the mouse wheel zooms the image instead of dismissing or paging',
    (tester) async {
      await _open(tester);
      expect(_scale(tester), 1);
      final center = tester.getCenter(find.byType(PageView));
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: center,
          kind: PointerDeviceKind.mouse,
          scrollDelta: const Offset(0, -200),
        ),
      );
      await tester.pumpAndSettle();
      expect(_scale(tester), greaterThan(1));
      expect(find.byType(ImageViewerPage), findsOneWidget);
      // 放大后左右翻页（拖动、按键、按钮）都停用。
      expect(_pagePhysics(tester), isA<NeverScrollableScrollPhysics>());
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_scale(tester), greaterThan(1));

      // 反向滚动缩回原大小，翻页恢复。
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: center,
          kind: PointerDeviceKind.mouse,
          scrollDelta: const Offset(0, 2000),
        ),
      );
      await tester.pumpAndSettle();
      expect(_scale(tester), 1);
      expect(_pagePhysics(tester), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('a mouse double-click zooms in and back out', (tester) async {
    await _open(tester);
    final center = tester.getCenter(find.byType(PageView));
    Future<void> doubleClick() async {
      await tester.tapAt(center, kind: PointerDeviceKind.mouse);
      await tester.pump(kDoubleTapMinTime + const Duration(milliseconds: 10));
      await tester.tapAt(center, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
    }

    await doubleClick();
    expect(_scale(tester), greaterThan(1));
    await doubleClick();
    expect(_scale(tester), 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('touch platforms show no page arrows', (tester) async {
    await _open(tester);
    expect(find.byKey(_next), findsNothing);
    expect(find.byKey(_previous), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
