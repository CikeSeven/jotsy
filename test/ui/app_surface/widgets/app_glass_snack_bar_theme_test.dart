import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/app_surface/models/app_glass_style.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_snack_bar_theme.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_colors.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

import '../../../support/expressive_test_theme.dart';

const AppGlassStyle _glass = AppGlassStyle(mode: AppGlassMode.glass);

/// 与 `NodeDiaryApp` 的 builder 同样的装配：scope 之下挂提示条主题。
Widget _host({
  required AppGlassStyle style,
  Brightness brightness = Brightness.light,
  bool highContrast = false,
}) {
  return MaterialApp(
    theme: expressiveTestTheme(brightness),
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(highContrast: highContrast),
      child: AppGlassScope(
        style: style,
        child: AppGlassSnackBarTheme(child: child!),
      ),
    ),
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => HomeHintVisibilityScope.showTrackedSnackBar(
            context: context,
            snackBar: SnackBar(
              content: const Text('Saved'),
              action: SnackBarAction(label: 'Undo', onPressed: () {}),
              persist: false,
            ),
          ),
          child: const Text('show'),
        ),
      ),
    ),
  );
}

Future<void> _show(WidgetTester tester) async {
  await tester.tap(find.text('show'));
  await tester.pumpAndSettle();
}

Material _snackMaterial(WidgetTester tester) => tester.widget<Material>(
  find
      .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
      .first,
);

Color _textColor(WidgetTester tester) => tester
    .widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.text('Saved'),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    )
    .style
    .color!;

ThemeData _snackTheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(SnackBar)));

void main() {
  testWidgets('经典材质的提示条保持 inverseSurface 配色', (tester) async {
    await tester.pumpWidget(_host(style: AppGlassStyle.defaults));
    await _show(tester);
    final scheme = _snackTheme(tester).colorScheme;
    expect(_snackMaterial(tester).color, scheme.inverseSurface);
    expect(_textColor(tester), scheme.onInverseSurface);
    expect(
      _snackTheme(tester).snackBarTheme.actionTextColor,
      scheme.inversePrimary,
    );
  });

  testWidgets('只把其他组件设为玻璃时提示条仍为经典', (tester) async {
    final style = AppGlassStyle.defaults.withOverride(
      AppGlassComponent.sheets,
      AppGlassOverride.glass,
    );
    await tester.pumpWidget(_host(style: style));
    await _show(tester);
    final scheme = _snackTheme(tester).colorScheme;
    expect(_snackMaterial(tester).color, scheme.inverseSurface);
  });

  for (final brightness in Brightness.values) {
    testWidgets('小控件为玻璃时提示条用玻璃底色、描边与可读前景（$brightness）', (tester) async {
      await tester.pumpWidget(_host(style: _glass, brightness: brightness));
      await _show(tester);
      final theme = _snackTheme(tester);
      final scheme = theme.colorScheme;
      final material = _snackMaterial(tester);
      final color = material.color!;
      expect(color, isNot(scheme.inverseSurface));
      // 不透明度抬到下限之上，但仍是半透明玻璃。
      expect(color.a, closeTo(AppGlassSnackBarTheme.minOpacity, 0.01));
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side, isNot(BorderSide.none));
      expect(shape.borderRadius, BorderRadius.circular(20));
      expect(material.elevation, 0);
      // 叠在页面底色上的实际底色，对正文与动作按钮都要 ≥ 4.5。
      final effective = Color.alphaBlend(color, scheme.surface);
      expect(_textColor(tester), scheme.onSurface);
      expect(
        DiaryCardColors.contrastRatio(_textColor(tester), effective),
        greaterThanOrEqualTo(4.5),
      );
      final action = theme.snackBarTheme.actionTextColor!;
      expect(
        DiaryCardColors.contrastRatio(action, effective),
        greaterThanOrEqualTo(4.5),
      );
      expect(theme.snackBarTheme.insetPadding, const EdgeInsets.all(16));
    });
  }

  testWidgets('高对比度时玻璃提示条不透明', (tester) async {
    await tester.pumpWidget(_host(style: _glass, highContrast: true));
    await _show(tester);
    final color = _snackMaterial(tester).color!;
    expect(color.a, 1.0);
    final glass = AppGlass.of(tester.element(find.byType(SnackBar)));
    expect(color, glass.solidFill);
  });

  testWidgets('关闭描边时玻璃提示条没有描边', (tester) async {
    await tester.pumpWidget(
      _host(
        style: const AppGlassStyle(mode: AppGlassMode.glass, border: false),
      ),
    );
    await _show(tester);
    final shape = _snackMaterial(tester).shape! as RoundedRectangleBorder;
    expect(shape.side, BorderSide.none);
  });
}
