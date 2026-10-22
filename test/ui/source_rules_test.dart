/// 合并各功能重复的源码规则检查：每个文件只读一次，每条规则只注册一个用例。
///
/// 这里只约束公共组件与样式的使用，不替代交互测试。检查范围沿用原有各模块的
/// 白名单；控制器的防抖计时仍排除在动画时长规则外。违规一次列出全部文件与行号，
/// 不再为每个源码文件启动一个仅重复相同 expect 的测试。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const common = <String>[
    '.showSnackBar(',
    'CircularProgressIndicator',
    'Gradient(',
  ];
  const animation = 'Duration(milliseconds';
  const fixedColors = <String>['Colors.white', 'Colors.black'];
  final rulesByFile = <String, Set<String>>{};

  List<File> filesUnder(String directory) {
    final files = Directory(directory)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    if (files.isEmpty) {
      throw StateError('No guarded source files in $directory');
    }
    return files;
  }

  void guard(Iterable<File> files, List<String> rules) {
    for (final file in files) {
      rulesByFile.putIfAbsent(file.path, () => <String>{}).addAll(rules);
    }
  }

  final notebooks = filesUnder('lib/ui/notebooks');
  guard(notebooks, [...common, ...fixedColors, 'Icon(Icons.']);
  guard(notebooks.where((file) => !file.path.contains('/controllers/')), [
    animation,
  ]);
  // SDK 菜单已由 expressive_menu_source_test.dart 在全应用统一检查。
  guard(filesUnder('lib/ui/diary_templates'), [
    ...common,
    ...fixedColors,
    animation,
    'Icon(Icons.',
    // createTag 会改写同名标签的颜色；模板只能补建缺失的标签。
    'createTag(',
  ]);
  guard(filesUnder('lib/ui/anniversaries'), [...common, animation]);
  guard(filesUnder('lib/ui/calendar'), ['.showSnackBar(']);

  guard(
    [
      for (final directory in [
        'lib/ui/diaries/models/diary_card_style',
        'lib/ui/diaries/widgets/diary_card',
        'lib/ui/settings/sections/diary_card_style',
        'lib/ui/diaries/models/style_library',
        'lib/ui/settings/widgets/style_editor',
        'lib/ui/diaries/models/diary_preview_style',
        'lib/ui/diaries/widgets/diary_preview',
        'lib/ui/settings/sections/diary_preview_style',
      ])
        ...filesUnder(directory),
      for (final path in [
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
    ],
    [...common, animation],
  );

  guard(
    [
      for (final path in [
        'lib/ui/settings/pages/cloud_backup_page.dart',
        'lib/ui/settings/pages/cloud_backup_target_page.dart',
        'lib/ui/settings/sections/cloud_backup_account_section.dart',
        'lib/ui/settings/sections/cloud_backup_config_forms.dart',
        'lib/ui/settings/sections/cloud_backup_remote_list.dart',
        'lib/ui/settings/widgets/cloud_backup_authorization_dialogs.dart',
        'lib/ui/settings/widgets/cloud_backup_config_field.dart',
        'lib/ui/settings/widgets/cloud_backup_dialogs.dart',
        'lib/ui/settings/widgets/cloud_backup_provider_sheet.dart',
      ])
        File(path),
    ],
    [
      ...common,
      ...fixedColors,
      animation,
      'ScaffoldMessenger',
      'Material Icons',
    ],
  );

  final sources = <String, List<String>>{
    for (final path in rulesByFile.keys) path: File(path).readAsLinesSync(),
  };
  final rules = rulesByFile.values.expand((rules) => rules).toSet().toList()
    ..sort();
  for (final rule in rules) {
    test('guarded UI sources avoid $rule', () {
      final pattern = rule == 'Material Icons'
          ? RegExp(r'(?<!FontAwesome)Icons\.')
          : RegExp(RegExp.escape(rule));
      final offenders = <String>[
        for (final entry in rulesByFile.entries)
          if (entry.value.contains(rule))
            for (final (index, line) in sources[entry.key]!.indexed)
              if (pattern.hasMatch(line)) '${entry.key}:${index + 1}',
      ];
      expect(offenders, isEmpty, reason: 'Uses $rule');
    });
  }
}
