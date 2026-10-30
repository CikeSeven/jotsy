import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';

/// 工具栏「对齐」「字号」两块面板的选项与它们写进正文的值。纯数据，不依赖
/// BuildContext；读写选区见 `diary_text_style_editing.dart`。

/// 段落对齐：存在块的 `data.align`，左对齐（起始侧）不写这个键（稀疏）。
enum DiaryTextAlign {
  left(null),
  center(kDiaryAlignCenter),
  right(kDiaryAlignRight),
  justify(kDiaryAlignJustify);

  const DiaryTextAlign(this.attributeValue);

  /// 写进 `data.align` 的值；左对齐为 null（移除这个键）。
  final String? attributeValue;

  /// 读出块上的对齐。没有这个键或认不出的值（如导入保留下来的 `left`）按
  /// 左对齐处理，与正文的渲染一致。
  static DiaryTextAlign fromAttribute(Object? value) {
    for (final align in values) {
      if (align.attributeValue != null && align.attributeValue == value) {
        return align;
      }
    }
    return DiaryTextAlign.left;
  }
}

/// 行内字号档位：存在文字的 `size` 属性（见 [kDiaryInlineSize]），正文档不写。
///
/// [scale] 是相对正文字号的倍数，编辑器渲染（`diaryEditorSpanDecorator`）与
/// 面板里各档标签的大小共用；代码块里不生效。
enum DiaryFontSize {
  small('small', 0.85),
  normal(null, 1),
  large('large', 1.25),
  huge('huge', 1.5);

  const DiaryFontSize(this.attributeValue, this.scale);

  /// 写进 `size` 的值；正文为 null（移除这个属性）。
  final String? attributeValue;
  final double scale;

  /// 读出 `size` 属性。没有这个属性为正文；认不出的值（如导入保留下来的
  /// 数字字号）为 null：渲染按正文，面板不选中任何一档。
  static DiaryFontSize? fromAttribute(Object? value) {
    if (value == null) return DiaryFontSize.normal;
    for (final size in values) {
      if (size.attributeValue == value) return size;
    }
    return null;
  }
}

/// 上标 / 下标：存在文字的 `script` 属性（见 [kDiaryInlineScript]），同一个键，
/// 两者互斥；普通文字不写。
///
/// [scale] 与 [baselineShift] 都相对所在文字的字号，只用于编辑器渲染
/// （`diary_script_spans.dart`）；代码块里不生效。
enum DiaryScript {
  superscript(kDiaryScriptSuper, 0.34),
  subscript(kDiaryScriptSub, -0.2);

  const DiaryScript(this.attributeValue, this.baselineShift);

  /// 写进 `script` 的值。
  final String attributeValue;

  /// 基线位移，正值向上。
  final double baselineShift;

  /// 上下标字的字号倍数。
  static const double scale = 0.7;

  /// 读出 `script` 属性；没有或认不出的值（按普通文字渲染）为 null。
  static DiaryScript? fromAttribute(Object? value) {
    for (final script in values) {
      if (script.attributeValue == value) return script;
    }
    return null;
  }
}
