import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/app_surface/models/app_glass_style.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';

import '../../../support/expressive_test_theme.dart';

/// 全部组件都是玻璃（含面板与对话框）。
const AppGlassStyle kGlassStyle = AppGlassStyle(mode: AppGlassMode.glass);

/// 带应用主题与材质 scope 的测试外壳：首页一个“open”按钮，点按时用按钮
/// 自己的 context 调 [onOpen]。scope 与高对比度都挂在 Navigator 之上，与
/// 应用里 `MaterialApp.builder` 的位置一致。
Widget modalHarness({
  AppGlassStyle style = AppGlassStyle.defaults,
  bool highContrast = false,
  required void Function(BuildContext context) onOpen,
}) {
  return MaterialApp(
    theme: expressiveTestTheme(Brightness.light),
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(highContrast: highContrast),
      child: AppGlassScope(style: style, child: child!),
    ),
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => onOpen(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

/// 当前栈顶路由（从页面里任取一个 context 查）。
Route<dynamic>? topRoute(WidgetTester tester, Finder inside) {
  final context = tester.element(inside);
  return ModalRoute.of(context);
}

/// [target] 的祖先里有没有透明度层（Opacity / FadeTransition）。
bool hasOpacityAncestor(Finder target) {
  return find
          .ancestor(of: target, matching: find.byType(Opacity))
          .evaluate()
          .isNotEmpty ||
      find
          .ancestor(of: target, matching: find.byType(FadeTransition))
          .evaluate()
          .isNotEmpty;
}

/// 从 `ImageFilter.blur(σx, σy, …)` 的描述里取出 σx。
double blurSigmaOf(BackdropFilter filter) {
  final match = RegExp(
    r'blur\(([0-9.]+),',
  ).firstMatch(filter.filter.toString());
  expect(match, isNotNull, reason: filter.filter.toString());
  return double.parse(match!.group(1)!);
}

/// 测试主题下的玻璃解析结果。
AppGlassResolved resolvedGlass({
  AppGlassStyle style = kGlassStyle,
  bool highContrast = false,
}) => AppGlassResolved.resolve(
  style,
  expressiveTestTheme(Brightness.light).colorScheme,
  highContrast: highContrast,
);
