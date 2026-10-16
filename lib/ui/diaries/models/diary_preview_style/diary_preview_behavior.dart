import 'package:flutter/foundation.dart';

import '../style_library/style_json.dart';

/// 预览页的阅读行为：不属于外观，不随内置预设、样式码与“我的样式”改变
/// （套用一个预设不该顺手关掉别的习惯）。与外观一起存在单键
/// `diaryPreviewStyleRaw` 的 `behavior` 里，逐字段容错、稀疏编码。
@immutable
class DiaryPreviewBehavior {
  const DiaryPreviewBehavior({
    this.todoToggle = true,
    this.textSelection = true,
  });

  static const DiaryPreviewBehavior defaults = DiaryPreviewBehavior();

  factory DiaryPreviewBehavior.fromJson(Object? raw) {
    final json = StyleJson.map(raw);
    if (json == null) {
      return defaults;
    }
    return DiaryPreviewBehavior(
      todoToggle: StyleJson.boolean(json['todoToggle'], defaults.todoToggle),
      textSelection: StyleJson.boolean(
        json['textSelection'],
        defaults.textSelection,
      ),
    );
  }

  /// 允许在预览页直接勾选待办（勾选会自动保存）。
  final bool todoToggle;

  /// 允许长按选择、复制正文文字。
  final bool textSelection;

  bool get isDefault => this == defaults;

  Map<String, Object> toJson() {
    final json = <String, Object>{};
    StyleJson.put(json, 'todoToggle', todoToggle, defaults.todoToggle);
    StyleJson.put(json, 'textSelection', textSelection, defaults.textSelection);
    return json;
  }

  DiaryPreviewBehavior copyWith({bool? todoToggle, bool? textSelection}) {
    return DiaryPreviewBehavior(
      todoToggle: todoToggle ?? this.todoToggle,
      textSelection: textSelection ?? this.textSelection,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryPreviewBehavior &&
        other.todoToggle == todoToggle &&
        other.textSelection == textSelection;
  }

  @override
  int get hashCode => Object.hash(todoToggle, textSelection);
}
