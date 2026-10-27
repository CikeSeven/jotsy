import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/ui/widgets/app_modal/app_dialog.dart';

import 'app_modal_test_harness.dart';

/// 对话框卡片自己的 Material（AlertDialog 里的第一层 Material）。
Material _dialogMaterial(WidgetTester tester) => tester.widget<Material>(
  find
      .descendant(of: find.byType(AlertDialog), matching: find.byType(Material))
      .first,
);

Finder get _backdropFilter => find.descendant(
  of: find.byType(AppGlassDialogBackdrop),
  matching: find.byType(BackdropFilter),
);

void main() {
  Widget dialog(BuildContext context) => AlertDialog(
    title: const Text('title'),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop('ok'),
        child: const Text('confirm'),
      ),
    ],
  );

  group('经典材质', () {
    testWidgets('路由与卡片底色同 showDialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        modalHarness(
          onOpen: (BuildContext context) =>
              showAppDialog<String>(context: context, builder: dialog),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(topRoute(tester, find.text('title')), isA<DialogRoute<String>>());
      expect(find.byType(AppGlassDialogBackdrop), findsNothing);
      final theme = Theme.of(tester.element(find.text('open')));
      expect(_dialogMaterial(tester).color, theme.dialogTheme.backgroundColor);
    });
  });

  group('玻璃材质', () {
    /// 打开玻璃对话框（点按 open 后只推进一帧，由各测试决定推进多少）。
    Future<_Opened> openGlass(
      WidgetTester tester, {
      bool highContrast = false,
      bool barrierDismissible = true,
    }) async {
      final opened = _Opened();
      await tester.pumpWidget(
        modalHarness(
          style: kGlassStyle,
          highContrast: highContrast,
          onOpen: (BuildContext context) async {
            opened.result = await showAppDialog<String>(
              context: context,
              barrierDismissible: barrierDismissible,
              builder: dialog,
            );
            opened.closed = true;
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      return opened;
    }

    testWidgets('整页磨砂：结束时 sigma = blurSigma，中途按动画值比例', (
      WidgetTester tester,
    ) async {
      await openGlass(tester);
      await tester.pump(ExpressiveMotion.medium ~/ 2);
      expect(
        topRoute(tester, find.text('title')),
        isA<AppGlassDialogRoute<String>>(),
      );
      final backdrop = tester.widget<AppGlassDialogBackdrop>(
        find.byType(AppGlassDialogBackdrop),
      );
      final t = backdrop.animation.value;
      expect(t, inExclusiveRange(0, 1));
      final glass = resolvedGlass();
      var filter = tester.widget<BackdropFilter>(_backdropFilter);
      expect(filter.enabled, isTrue);
      expect(blurSigmaOf(filter), closeTo(glass.blurSigma * t, 1e-6));
      expect(hasOpacityAncestor(_backdropFilter), isFalse);

      await tester.pumpAndSettle();
      filter = tester.widget<BackdropFilter>(_backdropFilter);
      expect(filter.enabled, isTrue);
      expect(blurSigmaOf(filter), glass.blurSigma);
      expect(hasOpacityAncestor(_backdropFilter), isFalse);
      // 磨砂层铺满整个路由。
      expect(
        tester.getSize(_backdropFilter),
        tester.getSize(find.byType(Navigator)),
      );
    });

    testWidgets('卡片底色为玻璃 fill，带玻璃描边，无投影', (WidgetTester tester) async {
      await openGlass(tester);
      await tester.pumpAndSettle();
      final glass = resolvedGlass();
      final material = _dialogMaterial(tester);
      expect(material.color, glass.fill);
      expect(material.color!.a, lessThan(1));
      expect(material.elevation, 0);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side, glass.border);
      final theme = Theme.of(tester.element(find.text('open')));
      expect(
        shape.borderRadius,
        (theme.dialogTheme.shape! as RoundedRectangleBorder).borderRadius,
      );
    });

    testWidgets('遮罩比经典浅', (WidgetTester tester) async {
      await openGlass(tester);
      await tester.pumpAndSettle();
      final route =
          topRoute(tester, find.text('title'))! as AppGlassDialogRoute<String>;
      expect(route.barrierColor!.a, lessThan(Colors.black54.a));
    });

    testWidgets('点遮罩关闭，返回 null', (WidgetTester tester) async {
      final opened = await openGlass(tester);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('title'), findsNothing);
      expect(opened.closed, isTrue);
      expect(opened.result, isNull);
    });

    testWidgets('barrierDismissible: false 时点遮罩不关闭', (
      WidgetTester tester,
    ) async {
      await openGlass(tester, barrierDismissible: false);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('title'), findsOneWidget);
    });

    testWidgets('按钮关闭时带回返回值', (WidgetTester tester) async {
      final opened = await openGlass(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('confirm'));
      await tester.pumpAndSettle();
      expect(opened.closed, isTrue);
      expect(opened.result, 'ok');
    });

    testWidgets('高对比度：不磨砂，卡片不透明，遮罩回到经典', (WidgetTester tester) async {
      await openGlass(tester, highContrast: true);
      await tester.pumpAndSettle();
      final filter = tester.widget<BackdropFilter>(_backdropFilter);
      expect(filter.enabled, isFalse);
      final material = _dialogMaterial(tester);
      expect(material.color!.a, 1);
      expect(material.color, resolvedGlass(highContrast: true).solidFill);
      final route =
          topRoute(tester, find.text('title'))! as AppGlassDialogRoute<String>;
      expect(route.barrierColor, Colors.black54);
    });

    testWidgets('显式给了 backgroundColor 的对话框保持自己的颜色', (
      WidgetTester tester,
    ) async {
      const own = Color(0xFF336699);
      await tester.pumpWidget(
        modalHarness(
          style: kGlassStyle,
          onOpen: (BuildContext context) => showAppDialog<void>(
            context: context,
            builder: (_) =>
                const AlertDialog(backgroundColor: own, title: Text('title')),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(_dialogMaterial(tester).color, own);
    });
  });
}

/// 玻璃对话框的关闭结果。
class _Opened {
  bool closed = false;
  String? result;
}
