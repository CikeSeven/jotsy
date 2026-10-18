import 'package:flutter/foundation.dart';

import '../../diaries/models/time_capsule.dart';
import '../models/diary_template.dart';
import '../models/diary_template_json.dart';
import 'diary_template_variable_values.dart';

/// 一个模板按某天展开后的结果：变量已替换的标题与正文，以及要带上的预设。
@immutable
class DiaryTemplateApplication {
  const DiaryTemplateApplication({
    required this.template,
    required this.title,
    required this.ops,
  });

  /// 按 [values] 展开 [template]。正文在解码时再清洗一次（白名单），变量
  /// 逐段文字替换，格式不变。
  factory DiaryTemplateApplication.resolve(
    DiaryTemplate template,
    DiaryTemplateVariableValues values,
  ) {
    return DiaryTemplateApplication(
      template: template,
      title: values.resolve(template.titlePattern),
      ops: List<Map<String, Object?>>.unmodifiable(
        values.resolveOps(decodeDiaryTemplateBody(template.bodyJson)),
      ),
    );
  }

  final DiaryTemplate template;
  final String title;

  /// 正文 Delta 操作（已替换变量）。
  final List<Map<String, Object?>> ops;

  List<DiaryTemplateTagRef> get tags => template.tags;
  String? get mood => template.mood;
  int? get energy => template.energy;
  TimeCapsulePreset? get capsule => template.capsule;
}
