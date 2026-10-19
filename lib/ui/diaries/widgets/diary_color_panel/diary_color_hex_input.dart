import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';

/// 取消 / 应用按钮与输入框同为 40dp（主题默认 48dp）；触控区不再补到 48dp
/// （shrinkWrap），整行放进 40dp 表头，与工具栏 40dp 一格的触控区一致。
const ButtonStyle _kActionStyle = ButtonStyle(
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  minimumSize: WidgetStatePropertyAll<Size>(Size.square(40)),
  fixedSize: WidgetStatePropertyAll<Size>(Size.square(40)),
  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.zero),
);

/// 输入行左端实时预览圆点的直径；面板据此让它与第一列色块同圆心。
const double kDiaryColorHexPreviewSize = 32;

/// 颜色代码的数字样式：等宽数字，六位代码对齐、不随输入左右抖动。
const List<FontFeature> _kTabular = <FontFeature>[FontFeature.tabularFigures()];

/// 颜色面板表头右侧的颜色代码胶囊：显示选区当前颜色的 `#RRGGBB`，点按进入
/// 输入模式。没有颜色或读不懂时显示“自定义”，色点为空心圆。
class DiaryColorHexChip extends StatelessWidget {
  const DiaryColorHexChip({
    super.key,
    required this.value,
    required this.onPressed,
  });

  final DiaryColorValue value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final color = value.color;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: colors.outlineVariant.withValues(alpha: 0.5),
        width: 0.8,
      ),
    );
    return Tooltip(
      message: l10n.diaryColorPanelEnterCode,
      child: Material(
        color: colors.surfaceContainerHigh,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: shape,
          child: SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DiaryColorDot(color: color, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    color == null
                        ? l10n.diaryColorPanelCustom
                        : diaryColorRgbHex(color),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      fontFeatures: _kTabular,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  FaIcon(
                    FontAwesomeIcons.pen,
                    size: 10,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 小色点：有颜色时实心（半透明背景色按原样叠在卡片上），没有颜色或无效时
/// 为空心圆。[showGlyph] 时在中间写“A”，即背景色作为高亮的样子。
class DiaryColorDot extends StatelessWidget {
  const DiaryColorDot({
    super.key,
    required this.color,
    required this.size,
    this.showGlyph = false,
  });

  final Color? color;
  final double size;
  final bool showGlyph;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fill = color;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(
          color: fill == null
              ? colors.outline
              : colors.outlineVariant.withValues(alpha: 0.6),
          width: fill == null ? 1.2 : 1,
        ),
      ),
      child: showGlyph && fill != null
          ? Text(
              'A',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1,
                color: colors.onSurface,
              ),
            )
          : null,
    );
  }
}

/// 颜色代码输入行：实时预览色点 + `#` 输入框 + 取消 / 应用。
///
/// - 输入：文字控制器与焦点由面板持有（进出输入模式时要交接焦点）；
/// - 输出：[onSubmit]（按应用或键盘“完成”，代码有效时才调用，给出不透明的
///   输入色，透明度由调用方按 [resolveDiaryHexInputColor] 决定）、[onCancel]；
/// - 键盘类型用 visiblePassword：强制 ASCII 键盘，不会弹出拼音输入法的候选；
///   同时关闭自动更正与联想（Android 上关联想本身也会带上可见密码变体）。
///   有的系统（如小米的安全键盘）会因此换一个输入法，旧键盘收起、新键盘
///   弹出之间键盘高度短暂归零，所以编辑页在焦点位于工具栏内时不以键盘高度
///   决定工具栏去留。不改成 url 等类型并打开联想：输入法组字时与转大写的
///   [DiaryHexInputFormatter] 可能冲突、重复上屏。
class DiaryColorHexInputRow extends StatelessWidget {
  const DiaryColorHexInputRow({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.target,
    required this.currentColor,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final DiaryColorTarget target;

  /// 选区当前的颜色：预览按落到正文的颜色画，RGB 没改时沿用它的透明度。
  final Color? currentColor;
  final ValueChanged<Color> onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    // 行高固定为 18dp（与 strut 一致）：前缀“#”与提示文字由同一样式派生，
    // 不会把输入框撑得比 40dp 高。
    final textStyle = TextStyle(
      fontSize: 15,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      fontFeatures: _kTabular,
      color: colors.onSurface,
    );
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, Widget? field) {
        final parsed = parseDiaryHexInput(value.text);
        return Row(
          children: <Widget>[
            DiaryColorDot(
              color: parsed == null
                  ? null
                  : resolveDiaryHexInputColor(parsed, currentColor),
              size: kDiaryColorHexPreviewSize,
              showGlyph: target == DiaryColorTarget.background,
            ),
            const SizedBox(width: 8),
            Expanded(child: field!),
            const SizedBox(width: 4),
            IconButton(
              tooltip: l10n.commonCancel,
              onPressed: onCancel,
              style: _kActionStyle,
              // 卡片外壳的 IconTheme 不带颜色，这里显式取语义色，暗色下不发黑。
              icon: FaIcon(
                FontAwesomeIcons.xmark,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
            ),
            IconButton.filled(
              tooltip: l10n.diaryColorPanelApply,
              onPressed: parsed == null ? null : () => onSubmit(parsed),
              style: _kActionStyle,
              // FaIcon 取不到按钮的前景色（同上），按启用 / 禁用显式给出：
              // 禁用色与 Material 的禁用前景一致（onSurface 38%）。
              icon: FaIcon(
                FontAwesomeIcons.check,
                size: 16,
                color: parsed == null
                    ? colors.onSurface.withValues(alpha: 0.38)
                    : colors.onPrimary,
              ),
            ),
          ],
        );
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: textStyle,
        strutStyle: const StrutStyle(
          fontSize: 15,
          height: 1.2,
          forceStrutHeight: true,
        ),
        maxLength: 6,
        // 不显示字数：counterText 为空串时仍会在下方留出一行，输入框偏上。
        buildCounter:
            (
              BuildContext context, {
              required int currentLength,
              required bool isFocused,
              int? maxLength,
            }) => null,
        maxLines: 1,
        keyboardType: TextInputType.visiblePassword,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        textAlignVertical: TextAlignVertical.center,
        inputFormatters: const <TextInputFormatter>[DiaryHexInputFormatter()],
        // 键盘“完成”默认会让输入框失焦，而失焦等于放弃输入；这里接管，代码
        // 无效时留在输入模式，有效时由 onSubmit 应用并交还焦点。
        onEditingComplete: () {},
        onSubmitted: (String text) {
          final parsed = parseDiaryHexInput(text);
          if (parsed != null) onSubmit(parsed);
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: colors.surfaceContainerHigh,
          isDense: true,
          // 行高由 strut 固定为 18dp，上下各 11dp，胶囊正好 40dp 高、文字居中；
          // 不用 constraints 撑高：多出的高度会落在输入行下方，文字偏上。
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 11,
          ),
          prefixText: '#',
          prefixStyle: textStyle.copyWith(color: colors.onSurfaceVariant),
          hintText: l10n.diaryColorPanelHexHint,
          hintStyle: textStyle.copyWith(
            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          border: pill,
          enabledBorder: pill,
          focusedBorder: pill,
        ),
      ),
    );
  }
}

/// 只留十六进制数字并转大写；粘贴的 `#3A7BD5`、`0x3A7BD5` 先去掉前缀再过滤，
/// 光标按保留下来的字符数换算，不会跳到末尾。
class DiaryHexInputFormatter extends TextInputFormatter {
  const DiaryHexInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = sanitizeDiaryHexInput(newValue.text);
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
