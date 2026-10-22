import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 全应用的渐变白名单；各模块共用的 UI 规则见 source_rules_test.dart。
void main() {
  // 例外只有两处（AGENTS.md §6）：用户开启的卡片渐变，以及颜色面板自定义
  // 页的色谱（颜色空间本身）。
  test('gradients are painted only by the selection surface and spectrum', () {
    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .where(
          (File file) => file.readAsStringSync().contains('LinearGradient('),
        )
        .map((File file) => file.path)
        .toList();
    expect(users..sort(), <String>[
      'lib/ui/diaries/widgets/diary_color_panel/diary_color_spectrum_painters.dart',
      'lib/ui/diaries/widgets/diary_selection_surface.dart',
    ]);
  });
}
