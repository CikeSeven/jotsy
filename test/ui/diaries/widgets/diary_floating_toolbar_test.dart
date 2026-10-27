import '../../../support/diary_content_test_helpers.dart';
import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_code_block/diary_toolbar_code_block_button.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_toolbar_color_button.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';

import '../../../support/expressive_test_theme.dart';

const _moreTooltip = '更多工具';
const _hideMoreTooltip = '收起更多工具';

Finder get _dot => find.byKey(const ValueKey<String>('diary-toolbar-more-dot'));

double _dotScale(WidgetTester tester) =>
    tester.widget<AnimatedScale>(_dot).scale;

/// 按真实摆放挂载：卡片左右各缩进 12dp，贴底。
Future<void> _pumpToolbar(
  WidgetTester tester, {
  required DiaryEditorController controller,
  double screenWidth = 360,
  List<DiaryToolbarItem> order = kDefaultDiaryToolbarOrder,
  bool recordingOpen = false,
  void Function(DiaryMediaKind)? onMediaPressed,
  ValueChanged<double>? onPanelExtentChanged,
  double maxPanelExtent = double.infinity,
  DiaryToolbarSize size = DiaryToolbarSize.standard,
}) async {
  tester.view.physicalSize = Size(screenWidth, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('zh'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        ...AppLocalizations.localizationsDelegates,
        quill.AppFlowyEditorLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kDiaryFloatingToolbarInset,
            ),
            child: DiaryFloatingToolbar(
              controller: controller,
              order: order,
              recordingOpen: recordingOpen,
              onMediaPressed: onMediaPressed,
              onPanelExtentChanged: onPanelExtentChanged,
              maxPanelExtent: maxPanelExtent,
              size: size,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DiaryEditorController _controller() {
  final controller = DiaryEditorController();
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  testWidgets(
    'a 360dp screen shows the leading tools and More instead of scrolling',
    (tester) async {
      await _pumpToolbar(tester, controller: _controller());

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
        findsNothing,
      );
      // 默认顺序前 6 个常驻，「图片」排第 10，收在面板里。
      expect(find.byTooltip('录音'), findsOneWidget);
      expect(find.byTooltip('插入图片'), findsNothing);
      expect(find.byTooltip(_moreTooltip), findsOneWidget);
      // 「更多」落在屏幕内的最后一格。
      final moreRect = tester.getRect(find.byTooltip(_moreTooltip));
      expect(moreRect.right, lessThanOrEqualTo(360 - 12));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('More expands the panel in place and its tools work', (
    tester,
  ) async {
    final requested = <DiaryMediaKind>[];
    await _pumpToolbar(
      tester,
      controller: _controller(),
      onMediaPressed: requested.add,
    );
    final barTop = tester.getTopLeft(find.byTooltip('录音')).dy;

    await tester.tap(find.byTooltip(_moreTooltip));
    await tester.pumpAndSettle();

    expect(find.byTooltip(_hideMoreTooltip), findsOneWidget);
    final image = find.byTooltip('插入图片');
    expect(image, findsOneWidget);
    // 面板在工具栏一排的上方展开，常驻工具位置不动。
    expect(tester.getTopLeft(image).dy, lessThan(barTop));
    expect(tester.getTopLeft(find.byTooltip('录音')).dy, barTop);

    await tester.tap(image);
    expect(requested, <DiaryMediaKind>[DiaryMediaKind.image]);

    await tester.tap(find.byTooltip(_hideMoreTooltip));
    await tester.pumpAndSettle();
    expect(find.byTooltip('插入图片'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports the expanded panel height and zero after collapsing', (
    tester,
  ) async {
    final extents = <double>[];
    await _pumpToolbar(
      tester,
      controller: _controller(),
      onPanelExtentChanged: extents.add,
    );
    final collapsedHeight = tester
        .getSize(find.byType(DiaryFloatingToolbar))
        .height;
    expect(collapsedHeight, kDiaryToolbarBarHeight);

    await tester.tap(find.byTooltip(_moreTooltip));
    await tester.pumpAndSettle();
    final expandedHeight = tester
        .getSize(find.byType(DiaryFloatingToolbar))
        .height;
    expect(extents, hasLength(1));
    expect(extents.single, expandedHeight - collapsedHeight);

    await tester.tap(find.byTooltip(_hideMoreTooltip));
    await tester.pumpAndSettle();
    expect(extents.last, 0);
    expect(
      tester.getSize(find.byType(DiaryFloatingToolbar)).height,
      collapsedHeight,
    );
  });

  testWidgets('each tool renders at the width the layout assumes', (
    tester,
  ) async {
    // 足够宽时全部常驻，逐个核对按钮实际宽度；按钮样式或 Quill 内部间距一旦
    // 变化，常驻个数的计算就会和画面对不上。
    await _pumpToolbar(tester, controller: _controller(), screenWidth: 1200);
    // 文字颜色 / 背景颜色与代码块是自绘按钮，其余仍是单项 Quill 工具栏。
    const colorItems = <DiaryToolbarItem>{
      DiaryToolbarItem.textColor,
      DiaryToolbarItem.backgroundColor,
    };
    final quillItems = kDefaultDiaryToolbarOrder
        .where(
          (item) =>
              !colorItems.contains(item) && item != DiaryToolbarItem.codeBlock,
        )
        .toList();
    for (final item in quillItems) {
      expect(
        tester
            .getSize(
              find.byKey(ValueKey('diary-toolbar-tool-${item.storageKey}')),
            )
            .width,
        diaryToolbarItemExtent(item),
      );
    }
    final colorButtons = find.byType(DiaryToolbarColorButton);
    expect(colorButtons, findsNWidgets(colorItems.length));
    for (var index = 0; index < colorItems.length; index++) {
      expect(
        tester.getSize(colorButtons.at(index)),
        const Size.square(kDiaryToolbarButtonExtent),
      );
    }
    expect(
      tester.getSize(find.byType(DiaryToolbarCodeBlockButton)),
      const Size.square(kDiaryToolbarButtonExtent),
    );
    expect(find.byTooltip(_moreTooltip), findsNothing);
  });

  testWidgets('a larger toolbar size scales the tools and pins fewer', (
    tester,
  ) async {
    await _pumpToolbar(
      tester,
      controller: _controller(),
      size: DiaryToolbarSize.large,
    );
    const scale = 1.2;

    // 360dp 下大号一排 6 格：前 5 个常驻，「下划线」收进「更多」。
    expect(find.byTooltip('斜体'), findsOneWidget);
    expect(find.byTooltip('下划线'), findsNothing);
    final undo = find.byKey(const ValueKey('diary-toolbar-tool-undo'));
    expect(
      tester.getSize(undo),
      const Size.square(kDiaryToolbarButtonExtent * scale),
    );
    // 按钮本身随格子等比放大（点按区域同样变大）：排版尺寸仍是标准的
    // 40dp，画到屏幕上是 48dp。
    final undoButton = find.descendant(
      of: undo,
      matching: find.byType(IconButton),
    );
    expect(tester.getSize(undoButton).width, kDiaryToolbarButtonExtent);
    expect(
      tester.getRect(undoButton).width,
      moreOrLessEquals(kDiaryToolbarButtonExtent * scale),
    );
    expect(
      tester.getSize(find.byType(DiaryFloatingToolbar)).height,
      moreOrLessEquals(kDiaryToolbarBarHeight * scale),
    );

    // 「更多」面板的行高同样放大。
    await tester.tap(find.byTooltip(_moreTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('下划线'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('diary-toolbar-tool-underline')))
          .height,
      kDiaryToolbarButtonExtent * scale,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('More lights a dot while a tool inside the panel is active', (
    tester,
  ) async {
    final controller = _controller();
    controller.replaceText(0, 0, 'quoted\nplain', null);
    controller.updateSelection(const TextSelection.collapsed(offset: 0));
    controller.setBlockType('quote');
    controller.updateSelection(
      const TextSelection.collapsed(offset: 2),
      'local',
    );
    await _pumpToolbar(tester, controller: controller);

    // 「引用」在 360dp 下收在面板里。
    expect(_dotScale(tester), 1);

    controller.updateSelection(
      const TextSelection.collapsed(offset: 9),
      'local',
    );
    await tester.pumpAndSettle();
    expect(_dotScale(tester), 0);

    controller.updateSelection(
      const TextSelection.collapsed(offset: 2),
      'local',
    );
    await tester.pumpAndSettle();
    expect(_dotScale(tester), 1);

    // 展开后引用按钮本身可见，圆点让位。
    await tester.tap(find.byTooltip(_moreTooltip));
    await tester.pumpAndSettle();
    expect(_dotScale(tester), 0);
  });

  testWidgets('opening the recording panel collapses More at once', (
    tester,
  ) async {
    final controller = _controller();
    final extents = <double>[];
    await _pumpToolbar(
      tester,
      controller: controller,
      onPanelExtentChanged: extents.add,
    );
    await tester.tap(find.byTooltip(_moreTooltip));
    await tester.pumpAndSettle();
    expect(find.byTooltip('插入图片'), findsOneWidget);

    await _pumpToolbar(
      tester,
      controller: controller,
      recordingOpen: true,
      onPanelExtentChanged: extents.add,
    );

    expect(find.byTooltip('插入图片'), findsNothing);
    expect(find.byTooltip(_moreTooltip), findsOneWidget);
    expect(extents.last, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce motion expands and collapses without layout errors', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpToolbar(tester, controller: _controller());

    await tester.tap(find.byTooltip(_moreTooltip));
    await tester.pump();
    expect(find.byTooltip('插入图片'), findsOneWidget);

    await tester.tap(find.byTooltip(_hideMoreTooltip));
    await tester.pump();
    expect(find.byTooltip('插入图片'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short window caps the panel and scrolls inside it', (
    tester,
  ) async {
    final extents = <double>[];
    await _pumpToolbar(
      tester,
      controller: _controller(),
      maxPanelExtent: 70,
      onPanelExtentChanged: extents.add,
    );

    await tester.tap(find.byTooltip(_moreTooltip));
    await tester.pumpAndSettle();

    expect(extents.single, 70);
    final panelScroll = find.descendant(
      of: find.byType(DiaryFloatingToolbar),
      matching: find.byType(SingleChildScrollView),
    );
    expect(panelScroll, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
