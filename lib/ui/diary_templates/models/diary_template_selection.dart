import 'package:flutter/foundation.dart';

import 'diary_template.dart';

/// 在模板面板里选定、交给新建编辑页套用的模板。
///
/// [questionShift] 是预览时按“换一题”换过的次数：`{{今日一问}}` 按日期取题，
/// 换题只在这个偏移上加一，编辑页套用时沿用同一个偏移，看到的就是预览里
/// 那一题。
@immutable
class DiaryTemplateSelection {
  const DiaryTemplateSelection(this.template, {this.questionShift = 0});

  final DiaryTemplate template;
  final int questionShift;
}
