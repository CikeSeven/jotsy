import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/app_modal/app_modal_bottom_sheet.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';

import 'app_modal_test_harness.dart';

const _body = SizedBox(height: 200, child: Center(child: Text('body')));

/// 记下 BottomSheet 的关键属性，用来比较两种入口的经典路径是否完全一致。
List<Object?> _sheetProps(WidgetTester tester) {
  final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Material),
        )
        .first,
  );
  return <Object?>[
    sheet.backgroundColor,
    sheet.elevation,
    sheet.shape,
    sheet.constraints,
    sheet.showDragHandle,
    material.color,
    material.shape,
    tester.getSize(find.byType(BottomSheet)),
  ];
}

void main() {
  group('经典材质', () {
    testWidgets('与直接调用 showModalBottomSheet 的路由与面板完全一致', (
      WidgetTester tester,
    ) async {
      late List<Object?> viaSdk;
      await tester.pumpWidget(
        modalHarness(
          onOpen: (BuildContext context) => showModalBottomSheet<void>(
            context: context,
            useSafeArea: true,
            showDragHandle: true,
            builder: (_) => _body,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        topRoute(tester, find.text('body')),
        isA<ModalBottomSheetRoute<void>>(),
      );
      viaSdk = _sheetProps(tester);
      Navigator.of(tester.element(find.text('body'))).pop();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        modalHarness(
          onOpen: (BuildContext context) => showAppModalBottomSheet<void>(
            context: context,
            useSafeArea: true,
            showDragHandle: true,
            builder: (_) => _body,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        topRoute(tester, find.text('body')),
        isA<ModalBottomSheetRoute<void>>(),
      );
      expect(_sheetProps(tester), viaSdk);
      expect(find.byType(GlassSurface), findsNothing);
      expect(find.byType(AppGlassSheetDragHandle), findsNothing);
    });

    testWidgets('返回值经入口原样带回', (WidgetTester tester) async {
      String? result;
      await tester.pumpWidget(
        modalHarness(
          onOpen: (BuildContext context) async {
            result = await showAppModalBottomSheet<String>(
              context: context,
              builder: (BuildContext sheetContext) => TextButton(
                onPressed: () => Navigator.of(sheetContext).pop('picked'),
                child: const Text('pick'),
              ),
            );
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();
      expect(result, 'picked');
    });
  });

  group('玻璃材质', () {
    Future<void> openGlass(
      WidgetTester tester, {
      bool? showDragHandle,
      bool highContrast = false,
      bool isScrollControlled = false,
      WidgetBuilder? builder,
      bool settle = true,
    }) async {
      await tester.pumpWidget(
        modalHarness(
          style: kGlassStyle,
          highContrast: highContrast,
          onOpen: (BuildContext context) => showAppModalBottomSheet<void>(
            context: context,
            useSafeArea: true,
            showDragHandle: showDragHandle,
            isScrollControlled: isScrollControlled,
            builder: builder ?? (_) => _body,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      if (settle) await tester.pumpAndSettle();
    }

    testWidgets('面板透明、内容包在只有上圆角的玻璃里，模糊开启', (WidgetTester tester) async {
      await openGlass(tester);
      expect(
        topRoute(tester, find.text('body')),
        isA<ModalBottomSheetRoute<void>>(),
      );
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, Colors.transparent);
      expect(sheet.elevation, 0);
      expect(sheet.showDragHandle, isFalse);

      final glassFinder = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(GlassSurface),
      );
      expect(glassFinder, findsOneWidget);
      final glass = tester.widget<GlassSurface>(glassFinder);
      expect(
        glass.borderRadius,
        const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      );
      expect(glass.fill, resolvedGlass().fill);
      final filter = tester.widget<BackdropFilter>(
        find.descendant(of: glassFinder, matching: find.byType(BackdropFilter)),
      );
      expect(filter.enabled, isTrue);
      expect(hasOpacityAncestor(glassFinder), isFalse);
      expect(
        find.descendant(of: glassFinder, matching: find.text('body')),
        findsOneWidget,
      );
    });

    testWidgets('入场途中玻璃也没有透明度祖先（面板靠位移入场）', (WidgetTester tester) async {
      await openGlass(tester, settle: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final glassFinder = find.byType(GlassSurface);
      expect(glassFinder, findsOneWidget);
      expect(hasOpacityAncestor(glassFinder), isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('主题打开拖动条时，拖动条画在玻璃里面、尺寸与间距同 SDK', (WidgetTester tester) async {
      await openGlass(tester);
      final glassFinder = find.byType(GlassSurface);
      final handle = find.byType(AppGlassSheetDragHandle);
      expect(
        find.descendant(of: glassFinder, matching: handle),
        findsOneWidget,
      );
      // 可点区域 48×48，贴着玻璃顶边居中；中间的小条 32×4、onSurfaceVariant。
      final glassRect = tester.getRect(glassFinder);
      final handleRect = tester.getRect(handle);
      expect(handleRect.size, const Size(48, 48));
      expect(handleRect.top, glassRect.top);
      expect(handleRect.center.dx, closeTo(glassRect.center.dx, 0.01));
      final bar = find.descendant(of: handle, matching: find.byType(Container));
      expect(tester.getSize(bar), const Size(32, 4));
      final decoration =
          tester.widget<Container>(bar).decoration! as BoxDecoration;
      final scheme = Theme.of(tester.element(handle)).colorScheme;
      expect(decoration.color, scheme.onSurfaceVariant);
      // 内容从拖动条下方 48 开始，与 SDK 的 Padding 一致。
      expect(
        tester.getTopLeft(find.byWidget(_body)).dy,
        glassRect.top + kMinInteractiveDimension,
      );
    });

    testWidgets('调用方关闭拖动条时不画', (WidgetTester tester) async {
      await openGlass(tester, showDragHandle: false);
      expect(find.byType(AppGlassSheetDragHandle), findsNothing);
      expect(
        tester.getTopLeft(find.byWidget(_body)).dy,
        tester.getRect(find.byType(GlassSurface)).top,
      );
    });

    testWidgets('读屏点按拖动条关闭面板', (WidgetTester tester) async {
      await openGlass(tester);
      final semantics = tester.ensureSemantics();
      final node = tester.getSemantics(find.byType(AppGlassSheetDragHandle));
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.text('body'), findsNothing);
      semantics.dispose();
    });

    testWidgets('高对比度：仍是玻璃布局，但底色不透明、不模糊', (WidgetTester tester) async {
      await openGlass(tester, highContrast: true);
      final glassFinder = find.byType(GlassSurface);
      final glass = tester.widget<GlassSurface>(glassFinder);
      expect(glass.fill.a, 1);
      expect(glass.fill, resolvedGlass(highContrast: true).solidFill);
      final filter = tester.widget<BackdropFilter>(
        find.descendant(of: glassFinder, matching: find.byType(BackdropFilter)),
      );
      expect(filter.enabled, isFalse);
    });

    testWidgets('isScrollControlled + 键盘：内容按 viewInsets 让开，不被遮住', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openGlass(
        tester,
        isScrollControlled: true,
        builder: (BuildContext context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: const SizedBox(height: 120, child: TextField()),
        ),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final field = tester.getRect(find.byType(TextField));
      expect(field.bottom, lessThanOrEqualTo(800 - 300));
      // 玻璃一直铺到屏幕底边（键盘后面也是面板），而不是只包住输入框。
      expect(tester.getRect(find.byType(GlassSurface)).bottom, 800);
    });

    testWidgets('DraggableScrollableSheet 内容照常显示并可拖动', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openGlass(
        tester,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          builder: (BuildContext context, ScrollController controller) =>
              ListView(
                controller: controller,
                children: <Widget>[
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 40, child: Text('row $i')),
                ],
              ),
        ),
      );
      final before = tester.getRect(find.byType(GlassSurface)).height;
      await tester.drag(find.text('row 2'), const Offset(0, -200));
      await tester.pumpAndSettle();
      final after = tester.getRect(find.byType(GlassSurface)).height;
      expect(after, greaterThan(before));
      expect(tester.takeException(), isNull);
    });
  });
}
