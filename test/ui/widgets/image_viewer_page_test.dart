import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/image_viewer_actions_sheet.dart';
import 'package:node_diary/ui/widgets/image_viewer_page.dart';

import '../../support/expressive_test_theme.dart';

Widget _host(Brightness brightness) => MaterialApp(
  theme: expressiveTestTheme(brightness),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const ImageViewerPage(
    items: <ImageViewerItem>[
      ImageViewerItem(source: '/missing/first.jpg'),
      ImageViewerItem(source: '/missing/second.jpg'),
    ],
    initialIndex: 0,
  ),
);

ScrollPhysics? _pagePhysics(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).physics;

Future<void> _doubleTapCenter(WidgetTester tester) async {
  final center = tester.getCenter(find.byType(PageView));
  await tester.tapAt(center);
  await tester.pump(kDoubleTapMinTime + const Duration(milliseconds: 10));
  await tester.tapAt(center);
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'zooming in locks paging until zoomed back out in $brightness',
      (tester) async {
        await tester.pumpWidget(_host(brightness));
        await tester.pumpAndSettle();
        expect(_pagePhysics(tester), isNull);

        await _doubleTapCenter(tester);
        expect(_pagePhysics(tester), isA<NeverScrollableScrollPhysics>());

        // 放大态下的水平快滑用于平移查看细节，不能翻到下一张。
        await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel('1 / 2'), findsOneWidget);

        await _doubleTapCenter(tester);
        expect(_pagePhysics(tester), isNull);
        await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('2 / 2'), findsOneWidget);
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('page number rolls in from the paging direction', (tester) async {
    await tester.pumpWidget(_host(Brightness.light));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    // 翻页结束前后的某一帧里，新旧数字同时在场并各自滑动。
    var sawBothNumbers = false;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('1').evaluate().isNotEmpty &&
          find.text('2').evaluate().isNotEmpty) {
        sawBothNumbers = true;
        final incoming = tester.getTopLeft(find.text('2')).dy;
        final outgoing = tester.getTopLeft(find.text('1')).dy;
        // 向后翻：新数字在下方滑入，旧数字向上滑出。
        expect(incoming, greaterThan(outgoing));
        break;
      }
    }
    expect(sawBothNumbers, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  Future<void> openFromHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
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
    expect(find.byType(ImageViewerPage), findsOneWidget);
  }

  testWidgets('swiping down closes the viewer', (tester) async {
    await openFromHost(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(ImageViewerPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'long pressing an image opens the share and save sheet in $brightness',
      (tester) async {
        await tester.pumpWidget(_host(brightness));
        await tester.pumpAndSettle();
        final l10n = tester.element(find.byType(ImageViewerPage)).l10n;

        // 顶栏只剩返回、页码与 ⋮：保存与分享都收进了操作面板。
        expect(
          find.descendant(
            of: find.byType(ImageViewerPage),
            matching: find.byType(IconButton),
          ),
          findsNWidgets(2),
        );
        expect(find.byTooltip(l10n.imageViewerMoreActions), findsOneWidget);
        expect(find.byTooltip(l10n.imageViewerSaveToGallery), findsNothing);
        expect(find.byTooltip(l10n.commonShare), findsNothing);

        await tester.longPress(find.byType(PageView));
        await tester.pumpAndSettle();

        expect(find.byType(ImageViewerActionsSheet), findsOneWidget);
        expect(find.text(l10n.diaryShareTargetsSection), findsOneWidget);
        // 测试环境没有已安装的应用，只剩始终可用的“更多应用”。
        expect(find.text(l10n.diaryShareTargetSystem), findsOneWidget);
        expect(find.text(l10n.imageViewerSaveToGallery), findsOneWidget);
        // 入口没给“打开日记”的处理（预览页、编辑页看图），面板里就没有这项。
        expect(find.text(l10n.imageViewerOpenDiary), findsNothing);
        expect(tester.takeException(), isNull);

        // 关掉面板什么也不做，看图页还在原处。
        await tester.tapAt(const Offset(20, 120));
        await tester.pumpAndSettle();
        expect(find.byType(ImageViewerActionsSheet), findsNothing);
        expect(find.byType(ImageViewerPage), findsOneWidget);
      },
    );
  }

  testWidgets('the top-bar more button opens the same sheet for the page', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImageViewerPage(
          items: const <ImageViewerItem>[
            ImageViewerItem(source: '/missing/first.jpg', diaryId: 'd1'),
            ImageViewerItem(source: '/missing/second.jpg', diaryId: 'd2'),
          ],
          initialIndex: 1,
          onOpenDiary: opened.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(ImageViewerPage)).l10n;

    await tester.tap(find.byTooltip(l10n.imageViewerMoreActions));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerActionsSheet), findsOneWidget);
    expect(find.text(l10n.imageViewerSaveToGallery), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 面板作用于当前停着的那一张。
    await tester.tap(find.text(l10n.imageViewerOpenDiary));
    await tester.pumpAndSettle();
    expect(opened, <String>['d2']);
  });

  testWidgets('open diary hands the long-pressed image\'s diary to the entry', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => openImageViewer(
                  context,
                  items: const <ImageViewerItem>[
                    ImageViewerItem(
                      source: '/missing/first.jpg',
                      diaryId: 'd1',
                    ),
                    ImageViewerItem(source: '/missing/second.jpg'),
                  ],
                  initialIndex: 0,
                  onOpenDiary: opened.add,
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
    final l10n = tester.element(find.byType(ImageViewerPage)).l10n;

    await tester.longPress(find.byType(PageView));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.imageViewerOpenDiary));
    await tester.pumpAndSettle();

    expect(opened, <String>['d1']);
    expect(find.byType(ImageViewerActionsSheet), findsNothing);
    // 预览页由入口叠在看图页之上，看图页本身不关闭。
    expect(find.byType(ImageViewerPage), findsOneWidget);

    // 第二张图没有所属日记：即使入口能打开日记，也不给这一项。
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(PageView));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerActionsSheet), findsOneWidget);
    expect(find.text(l10n.imageViewerOpenDiary), findsNothing);
  });

  testWidgets('vertical drags pan instead of closing while zoomed', (
    tester,
  ) async {
    await openFromHost(tester);
    await _doubleTapCenter(tester);
    expect(_pagePhysics(tester), isA<NeverScrollableScrollPhysics>());

    await tester.drag(find.byType(PageView), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(find.byType(ImageViewerPage), findsOneWidget);
  });
}
