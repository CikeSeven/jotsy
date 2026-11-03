import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';

import '../../../support/expressive_test_theme.dart';

/// 文字选区菜单测试的公共装配：应用主题 + 本地化，[home] 铺满屏幕、从原点
/// 开始（与根 Overlay 一样，锚点的全局坐标即覆盖层坐标）。
Widget textMenuTestApp(
  Widget home, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('zh'),
}) => MaterialApp(
  theme: expressiveTestTheme(brightness),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

/// 屏幕设为 [size]（逻辑像素，devicePixelRatio 1）。
void setTextMenuScreen(
  WidgetTester tester, [
  Size size = const Size(360, 800),
]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 记录点按的菜单项。
class TextMenuTaps {
  final List<String> pressed = <String>[];

  AppTextMenuAction action(
    String label, {
    FaIconData icon = FontAwesomeIcons.copy,
    AppTextMenuSlot slot = AppTextMenuSlot.primary,
    String? shortcut,
  }) => AppTextMenuAction(
    label: label,
    icon: icon,
    slot: slot,
    shortcut: shortcut,
    onPressed: () => pressed.add(label),
  );

  /// 剪切 / 复制 / 粘贴 / 全选。
  List<AppTextMenuAction> editing() => <AppTextMenuAction>[
    action('剪切', icon: FontAwesomeIcons.scissors),
    action('复制'),
    action('粘贴', icon: FontAwesomeIcons.paste),
    action('全选', icon: FontAwesomeIcons.objectGroup),
  ];
}
