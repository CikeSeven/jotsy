import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 锚定弹出菜单只经 `lib/ui/widgets/expressive_menu/`：其余源码不得再用
/// PopupMenuButton / PopupMenuItem / showMenu 或 SDK 的 MenuAnchor，
/// 否则会混入从中心放大、500ms 展开、返回键不先关菜单的旧菜单。
void main() {
  const componentDir = 'lib/ui/widgets/expressive_menu/';
  final forbidden = <String, RegExp>{
    'PopupMenuButton': RegExp(r'\bPopupMenuButton\b'),
    'PopupMenuItem': RegExp(r'\bPopupMenuItem\b'),
    'PopupMenuEntry': RegExp(r'\bPopupMenuEntry\b'),
    'showMenu': RegExp(r'\bshowMenu\s*[<(]'),
    // RawMenuAnchor 与 ExpressiveMenuAnchor 不算：前面带字母的不匹配。
    'MenuAnchor': RegExp(r'(?<![A-Za-z_])MenuAnchor\s*\('),
  };
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .where((File file) => !file.path.endsWith('.g.dart'))
      .where(
        (File file) =>
            !file.path.replaceAll(r'\', '/').startsWith(componentDir),
      )
      .toList();

  test('anchored menus outside the component use ExpressiveMenuAnchor', () {
    expect(files, isNotEmpty);
    final offenders = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // 注释里提到旧组件名不算违规。
        if (line.trimLeft().startsWith('//')) continue;
        for (final entry in forbidden.entries) {
          if (entry.value.hasMatch(line)) {
            offenders.add('${file.path}:${i + 1} uses ${entry.key}');
          }
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
