import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart' show FaIconData;

import '../../../core/database/app_database.dart';
import '../../diary_templates/viewmodels/diary_template_accent.dart';
import '../../notebooks/models/notebook_icon.dart';

/// 清单的强调色与图标。
///
/// - 颜色：`color_key` 存色板（`kColorPaletteFamilies`）中间色的 ARGB 十六进制
///   （如 `ff2196f3`），空串为跟随主题；显示时与日记模板、日记本同一套换算
///   （[diaryTemplateAccentColors]：`ColorScheme.fromSeed` 后取容器色，明暗
///   两种主题下都满足对比度），不直接涂种子色；
/// - 图标：`icon_key` 存 [NotebookIcon] 的名字（与日记本共用同一套图标），
///   空串或认不出时为清单的默认图标。
abstract final class TodoListStyle {
  /// 没设图标的清单显示的图标。
  static const NotebookIcon defaultIcon = NotebookIcon.listCheck;

  static int? seedOf(String colorKey) =>
      colorKey.isEmpty ? null : int.tryParse(colorKey, radix: 16);

  static String keyOfSeed(int? seed) =>
      seed == null ? '' : seed.toRadixString(16).padLeft(8, '0');

  static NotebookIcon? notebookIconOf(String iconKey) =>
      iconKey.isEmpty ? null : NotebookIcon.values.asNameMap()[iconKey];

  static FaIconData iconOf(String iconKey) =>
      (notebookIconOf(iconKey) ?? defaultIcon).data;

  static DiaryTemplateAccentColors accentOf(
    String colorKey,
    ColorScheme scheme,
  ) => diaryTemplateAccentColors(seedOf(colorKey), scheme);

  static FaIconData iconOfRow(TodoListRow list) => iconOf(list.iconKey);
}
