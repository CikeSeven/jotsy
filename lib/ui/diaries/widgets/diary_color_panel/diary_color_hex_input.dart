import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_field.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';

/// 颜色代码最多几位：六位 RGB（三位简写同样接受，见 [parseDiaryHexInput]）。
const int _kHexDigits = 6;

/// 颜色代码的数字样式：等宽数字，六位代码对齐、不随输入左右抖动。
const List<FontFeature> _kTabular = <FontFeature>[FontFeature.tabularFigures()];

/// 自定义取色页的颜色代码输入框：`#` 前缀 + 六位十六进制。
///
/// - 用手机的普通文字键盘：`TextInputType.text`，联想保持默认开启，只关自动
///   更正。Android 上关掉联想会让输入框带上“可见密码”标记，有的系统（如
///   小米）会因此换成密码安全键盘；
/// - 输入法组字（如拼音）期间不改写文字，组字结束后才去掉非十六进制字符并
///   转成大写（[DiaryHexInputFormatter]）；
/// - 输出：每次编辑 [onChanged]（取色页据此预览），键盘“完成”且代码有效时
///   [onSubmitted]（不透明的输入色）；文字与焦点由取色页持有，它负责焦点
///   交接。
class DiaryColorHexField extends StatelessWidget {
  const DiaryColorHexField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<Color> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    // 工具栏为玻璃（或“控件”为玻璃）时换成半透明填充与玻璃描边；只换颜色，
    // 焦点与键盘逻辑不动。获得焦点的主色描边照旧。
    final glassField = AppGlassField.of(context);
    final restingSide = glassField?.border ?? BorderSide.none;
    // 行高由 height 固定为 18dp，上下各 11dp，胶囊正好 40dp 高、文字居中。
    final textStyle = TextStyle(
      fontSize: 14,
      height: 18 / 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      fontFeatures: _kTabular,
      color: colors.onSurface,
    );
    OutlineInputBorder pill([BorderSide side = BorderSide.none]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: side,
        );
    return Semantics(
      label: l10n.diaryColorPanelEnterCode,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        // 保持默认开启，原因见类注释。
        enableSuggestions: true,
        maxLines: 1,
        textInputAction: TextInputAction.done,
        textAlignVertical: TextAlignVertical.center,
        inputFormatters: const <TextInputFormatter>[DiaryHexInputFormatter()],
        // 键盘“完成”默认会让输入框失焦，而失焦等于放弃输入；这里接管，代码
        // 无效时留在输入框里，有效时由 onSubmitted 应用并交还焦点。
        onEditingComplete: () {},
        onChanged: onChanged,
        onSubmitted: (String text) {
          final parsed = parseDiaryHexInput(text);
          if (parsed != null) onSubmitted(parsed);
        },
        style: textStyle,
        decoration: InputDecoration(
          filled: true,
          fillColor: glassField?.fill ?? colors.surfaceContainerHigh,
          isDense: true,
          prefixText: '#',
          prefixStyle: textStyle.copyWith(color: colors.onSurfaceVariant),
          hintText: l10n.diaryColorPanelHexHint,
          hintStyle: textStyle.copyWith(color: colors.onSurfaceVariant),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 11,
          ),
          border: pill(restingSide),
          enabledBorder: pill(restingSide),
          focusedBorder: pill(BorderSide(color: colors.primary, width: 1.5)),
        ),
      ),
    );
  }
}

/// 颜色代码输入的格式化：去掉空白、`#` 与粘贴进来的 `0x` 前缀，只留十六进制
/// 数字、转成大写、最多 6 位，光标按保留下来的字符换算。
///
/// 输入法正在组字（composing 区间非空）时原样放行：组字中改写文字会打断
/// 输入法、重复上屏；组字结束（上屏）后的下一次更新再统一整理。
class DiaryHexInputFormatter extends TextInputFormatter {
  const DiaryHexInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final composing = newValue.composing;
    if (composing.isValid && !composing.isCollapsed) return newValue;
    var text = sanitizeDiaryHexInput(newValue.text);
    if (text.length > _kHexDigits) text = text.substring(0, _kHexDigits);
    if (text == newValue.text) return newValue;
    final selection = newValue.selection;
    int map(int offset) => offset < 0
        ? offset
        : sanitizeDiaryHexInput(
            newValue.text.substring(0, offset.clamp(0, newValue.text.length)),
          ).length.clamp(0, text.length);
    return TextEditingValue(
      text: text,
      selection: selection.isValid
          ? TextSelection(
              baseOffset: map(selection.baseOffset),
              extentOffset: map(selection.extentOffset),
            )
          : TextSelection.collapsed(offset: text.length),
    );
  }
}
