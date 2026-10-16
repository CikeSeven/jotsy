import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AGENTS.md §6 的源码约束（日记卡片样式相关文件）：提示条经 Home 的跟踪
/// 接口、动画时长只取 ExpressiveMotion token、不用转圈加载；渐变只允许出现在
/// 绘制用户开启的渐变底色的 DiarySelectionSurface 里。
void main() {
  final files = <File>[
    for (final dir in <String>[
      'lib/ui/diaries/models/diary_card_style',
      'lib/ui/diaries/widgets/diary_card',
      'lib/ui/settings/sections/diary_card_style',
      'lib/ui/diaries/models/style_library',
      'lib/ui/settings/widgets/style_editor',
    ])
      ...Directory(dir).listSync(recursive: true).whereType<File>(),
    for (final path in <String>[
      'lib/ui/diaries/viewmodels/diary_card_appearance.dart',
      'lib/ui/diaries/viewmodels/diary_card_colors.dart',
      'lib/ui/diaries/viewmodels/diary_card_date_formatter.dart',
      'lib/ui/diaries/viewmodels/diary_card_media_summary.dart',
      'lib/ui/diaries/viewmodels/diary_card_resolved_style.dart',
      'lib/ui/diaries/viewmodels/diary_card_shadows.dart',
      'lib/ui/diaries/viewmodels/diary_card_surface_spec.dart',
      'lib/ui/diaries/sections/diaries_list_section.dart',
      'lib/ui/settings/pages/diary_card_style_page.dart',
      'lib/ui/settings/controllers/diary_card_style_editor_controller.dart',
      'lib/ui/settings/controllers/style_editor_controller.dart',
      'lib/ui/settings/widgets/diary_card_color_tile.dart',
      'lib/ui/settings/widgets/settings_option_tiles.dart',
      'lib/ui/settings/sections/settings_diary_card_style_tile.dart',
    ])
      File(path),
  ].where((File file) => file.path.endsWith('.dart')).toList();

  test('the card style feature has source files', () {
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

  test('gradients are painted only by the selection surface', () {
    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .where(
          (File file) => file.readAsStringSync().contains('LinearGradient('),
        )
        .map((File file) => file.path)
        .toList();
    expect(users, <String>[
      'lib/ui/diaries/widgets/diary_selection_surface.dart',
    ]);
  });
}
