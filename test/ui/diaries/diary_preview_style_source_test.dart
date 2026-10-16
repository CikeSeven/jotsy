import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AGENTS.md §6 的源码约束（预览页样式与字数相关文件）：提示条经 Home 的
/// 跟踪接口、动画时长只取 ExpressiveMotion token、不用转圈加载、不画渐变。
/// 导出与待办自动保存控制器里的毫秒数是防闪 / 防抖计时，不在检查范围。
void main() {
  final files = <File>[
    for (final dir in <String>[
      'lib/ui/diaries/models/diary_preview_style',
      'lib/ui/diaries/widgets/diary_preview',
      'lib/ui/settings/sections/diary_preview_style',
    ])
      ...Directory(dir).listSync(recursive: true).whereType<File>(),
    for (final path in <String>[
      'lib/ui/diaries/pages/diary_preview_page.dart',
      'lib/ui/diaries/providers/diary_preview_style_provider.dart',
      'lib/ui/diaries/viewmodels/diary_preview_resolved_style.dart',
      'lib/ui/diaries/viewmodels/diary_preview_view_data.dart',
      'lib/ui/settings/pages/diary_preview_style_page.dart',
      'lib/ui/settings/controllers/diary_preview_style_editor_controller.dart',
      'lib/ui/settings/sections/settings_diary_preview_style_tile.dart',
      'lib/ui/settings/widgets/style_editor/style_editor_scaffold.dart',
      'lib/ui/settings/widgets/style_editor/style_custom_color_tile.dart',
      'lib/app/theme/seeded_theme_cache.dart',
      'lib/utils/text_stats.dart',
    ])
      File(path),
  ].where((File file) => file.path.endsWith('.dart')).toList();

  test('the preview style feature has source files', () {
    expect(files.length, greaterThan(30));
  });

  for (final file in files) {
    test('${file.path} follows the UI rules', () {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('.showSnackBar(')));
      expect(source, isNot(contains('CircularProgressIndicator')));
      expect(source, isNot(contains('Gradient(')));
      expect(source, isNot(contains('Duration(milliseconds')));
    });
  }
}
