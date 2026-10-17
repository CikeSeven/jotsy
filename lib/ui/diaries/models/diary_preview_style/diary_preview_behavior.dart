import 'package:flutter/foundation.dart';

import '../style_library/style_json.dart';
import 'diary_preview_style_enums.dart';

/// 预览页的阅读行为：不属于外观，不随内置预设、样式码与“我的样式”改变
/// （套用一个预设不该顺手关掉翻页之类的习惯）。与外观一起存在单键
/// `diaryPreviewStyleRaw` 的 `behavior` 里，逐字段容错、稀疏编码。
@immutable
class DiaryPreviewBehavior {
  const DiaryPreviewBehavior({
    this.swipeBetweenDiaries = true,
    this.swipeSensitivity = DiaryPreviewSwipeSensitivity.standard,
    this.hapticOnPage = false,
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
      swipeBetweenDiaries: StyleJson.boolean(
        json['swipeBetweenDiaries'],
        defaults.swipeBetweenDiaries,
      ),
      swipeSensitivity: StyleJson.enumByName(
        DiaryPreviewSwipeSensitivity.values,
        json['swipeSensitivity'],
        defaults.swipeSensitivity,
      ),
      hapticOnPage: StyleJson.boolean(
        json['hapticOnPage'],
        defaults.hapticOnPage,
      ),
      todoToggle: StyleJson.boolean(json['todoToggle'], defaults.todoToggle),
      textSelection: StyleJson.boolean(
        json['textSelection'],
        defaults.textSelection,
      ),
    );
  }

  /// 左右滑动切换到进入时所在列表的上一篇 / 下一篇。关闭后仍可用正文末尾的
  /// “上一篇 / 下一篇”与读屏动作翻页。
  final bool swipeBetweenDiaries;
  final DiaryPreviewSwipeSensitivity swipeSensitivity;

  /// 翻到新的一篇时轻震一次。
  final bool hapticOnPage;

  /// 允许在预览页直接勾选待办（勾选会自动保存）。
  final bool todoToggle;

  /// 允许长按选择、复制正文文字。
  final bool textSelection;

  bool get isDefault => this == defaults;

  Map<String, Object> toJson() {
    final json = <String, Object>{};
    StyleJson.put(
      json,
      'swipeBetweenDiaries',
      swipeBetweenDiaries,
      defaults.swipeBetweenDiaries,
    );
    StyleJson.putEnum(
      json,
      'swipeSensitivity',
      swipeSensitivity,
      defaults.swipeSensitivity,
    );
    StyleJson.put(json, 'hapticOnPage', hapticOnPage, defaults.hapticOnPage);
    StyleJson.put(json, 'todoToggle', todoToggle, defaults.todoToggle);
    StyleJson.put(json, 'textSelection', textSelection, defaults.textSelection);
    return json;
  }

  DiaryPreviewBehavior copyWith({
    bool? swipeBetweenDiaries,
    DiaryPreviewSwipeSensitivity? swipeSensitivity,
    bool? hapticOnPage,
    bool? todoToggle,
    bool? textSelection,
  }) {
    return DiaryPreviewBehavior(
      swipeBetweenDiaries: swipeBetweenDiaries ?? this.swipeBetweenDiaries,
      swipeSensitivity: swipeSensitivity ?? this.swipeSensitivity,
      hapticOnPage: hapticOnPage ?? this.hapticOnPage,
      todoToggle: todoToggle ?? this.todoToggle,
      textSelection: textSelection ?? this.textSelection,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryPreviewBehavior &&
        other.swipeBetweenDiaries == swipeBetweenDiaries &&
        other.swipeSensitivity == swipeSensitivity &&
        other.hapticOnPage == hapticOnPage &&
        other.todoToggle == todoToggle &&
        other.textSelection == textSelection;
  }

  @override
  int get hashCode => Object.hash(
    swipeBetweenDiaries,
    swipeSensitivity,
    hapticOnPage,
    todoToggle,
    textSelection,
  );
}
