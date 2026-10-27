import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/expressive_entrance.dart';
import 'package:node_diary/ui/widgets/glass/glass_reveal.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';
import 'package:node_diary/ui/widgets/list_item_presence.dart';

const _fill = Color(0xB8FFFFFF);
const _rootKey = ValueKey<String>('reveal-root');
const _childKey = ValueKey<String>('glass-child');

/// 页面路由本身带 FadeTransition 等过渡，祖先检查只看测试根节点以内。
Future<void> _pump(WidgetTester tester, Widget body) => tester.pumpWidget(
  MaterialApp(
    home: Center(
      child: SizedBox(key: _rootKey, width: 200, height: 64, child: body),
    ),
  ),
);

const _glass = GlassSurface(
  fill: _fill,
  blurSigma: 20,
  child: SizedBox.expand(key: _childKey),
);

/// GlassSurface 与测试根节点之间的祖先组件。
List<Widget> _ancestorsInsideRoot(WidgetTester tester) {
  final widgets = <Widget>[];
  final element = tester.element(find.byType(GlassSurface));
  element.visitAncestorElements((Element ancestor) {
    if (ancestor.widget.key == _rootKey) return false;
    widgets.add(ancestor.widget);
    return true;
  });
  return widgets;
}

bool _hasFadeAncestor(WidgetTester tester) => _ancestorsInsideRoot(
  tester,
).any((Widget widget) => widget is Opacity || widget is FadeTransition);

/// 记录读到的进度与重建次数。
class _Probe extends StatelessWidget {
  const _Probe(this.onBuild);

  final void Function(double reveal, bool hasScope) onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(GlassReveal.of(context), GlassReveal.hasScope(context));
    return const SizedBox();
  }
}

void main() {
  group('GlassReveal', () {
    testWidgets('defaults to 1 without an ancestor', (tester) async {
      late double reveal;
      late bool scoped;
      await _pump(
        tester,
        _Probe((double value, bool hasScope) {
          reveal = value;
          scoped = hasScope;
        }),
      );
      expect(reveal, 1);
      expect(scoped, isFalse);
    });

    testWidgets('multiplies nested progress', (tester) async {
      late double reveal;
      late bool scoped;
      await _pump(
        tester,
        GlassReveal(
          progress: 0.5,
          child: GlassReveal(
            progress: 0.5,
            child: _Probe((double value, bool hasScope) {
              reveal = value;
              scoped = hasScope;
            }),
          ),
        ),
      );
      expect(reveal, 0.25);
      expect(scoped, isTrue);
    });

    testWidgets('does not notify dependents when the value is unchanged', (
      tester,
    ) async {
      var builds = 0;
      final probe = _Probe((double value, bool hasScope) => builds++);
      await _pump(tester, GlassReveal(progress: 0.5, child: probe));
      expect(builds, 1);
      await _pump(tester, GlassReveal(progress: 0.5, child: probe));
      expect(builds, 1);
      await _pump(tester, GlassReveal(progress: 0.75, child: probe));
      expect(builds, 2);
    });
  });

  group('GlassSurface under GlassReveal', () {
    testWidgets('scales the glass and fades the content inside it', (
      tester,
    ) async {
      await _pump(tester, const GlassReveal(progress: 0.5, child: _glass));

      final filter = tester.widget<BackdropFilter>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(BackdropFilter),
        ),
      );
      expect(filter.enabled, isTrue);
      expect(
        filter.filter,
        ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        reason: 'sigma 按显现进度减半',
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(Material),
        ),
      );
      expect(material.color!.a, closeTo(_fill.a * 0.5, 1e-6));

      // 内容外有一层 Opacity(0.5)，且它在 BackdropFilter 之内。
      final opacity = find.ancestor(
        of: find.byKey(_childKey),
        matching: find.byType(Opacity),
      );
      expect(opacity, findsOneWidget);
      expect(tester.widget<Opacity>(opacity).opacity, 0.5);
      expect(
        find.ancestor(of: opacity, matching: find.byType(BackdropFilter)),
        findsOneWidget,
      );

      expect(_hasFadeAncestor(tester), isFalse);
    });

    testWidgets('multiplies the reveal with its own progress', (tester) async {
      await _pump(
        tester,
        const GlassReveal(
          progress: 0.5,
          child: GlassSurface(
            fill: _fill,
            blurSigma: 20,
            progress: 0.5,
            child: SizedBox.expand(key: _childKey),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(Material),
        ),
      );
      expect(material.color!.a, closeTo(_fill.a * 0.25, 1e-6));
      // 内容只跟随作用域的进度；自身 progress 仍由调用方另行处理内容。
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(
                of: find.byKey(_childKey),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        0.5,
      );
    });

    testWidgets('adds no Opacity without a GlassReveal ancestor', (
      tester,
    ) async {
      await _pump(tester, _glass);
      expect(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });
  });

  group('ExpressiveEntrance', () {
    testWidgets('glass entrance keeps the glass out of opacity layers', (
      tester,
    ) async {
      await _pump(tester, const ExpressiveEntrance(glass: true, child: _glass));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.descendant(
          of: find.byType(ExpressiveEntrance),
          matching: find.byType(GlassReveal),
        ),
        findsOneWidget,
      );
      expect(_hasFadeAncestor(tester), isFalse);
      final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(filter.enabled, isTrue);
      final opacity = tester
          .widget<Opacity>(
            find.ancestor(
              of: find.byKey(_childKey),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      expect(opacity, inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(_hasFadeAncestor(tester), isFalse);
    });

    testWidgets('classic entrance keeps Opacity → FractionalTranslation', (
      tester,
    ) async {
      await _pump(tester, const ExpressiveEntrance(child: _glass));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(GlassReveal), findsNothing);
      final opacity = find.descendant(
        of: find.byType(ExpressiveEntrance),
        matching: find.byType(Opacity),
      );
      expect(opacity, findsOneWidget);
      expect(
        find.descendant(
          of: opacity,
          matching: find.byType(FractionalTranslation),
        ),
        findsOneWidget,
      );
    });
  });

  group('ListItemPresence', () {
    Widget presence({required bool glass}) => ListItemPresence(
      visible: true,
      appearing: true,
      duration: const Duration(milliseconds: 250),
      glass: glass,
      child: _glass,
    );

    testWidgets('glass presence replaces the FadeTransition', (tester) async {
      await _pump(tester, presence(glass: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(_hasFadeAncestor(tester), isFalse);
      expect(find.byType(GlassRevealTransition), findsOneWidget);
      final opacity = tester
          .widget<Opacity>(
            find.ancestor(
              of: find.byKey(_childKey),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      expect(opacity, inExclusiveRange(0, 1));
      expect(find.byType(ClipRect), findsWidgets);

      await tester.pumpAndSettle();
      expect(_hasFadeAncestor(tester), isFalse);
    });

    testWidgets('default presence keeps the FadeTransition', (tester) async {
      await _pump(tester, presence(glass: false));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(GlassRevealTransition), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ListItemPresence),
          matching: find.byType(FadeTransition),
        ),
        findsOneWidget,
      );
    });
  });
}
