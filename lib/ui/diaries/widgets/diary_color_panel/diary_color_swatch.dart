import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';

/// 色块直径；选中环 = 色块 + 2dp 间隙 + 2dp 环宽，直径 36dp，放进 40dp 一格。
const double kDiaryColorSwatchSize = 28;
const double _kRingGap = 2;
const double _kRingWidth = 2;
const double _kRingSize = kDiaryColorSwatchSize + 2 * (_kRingGap + _kRingWidth);

/// 预设颜色的显示名（读屏与长按提示）。
extension DiaryColorPresetLabel on DiaryColorPreset {
  String label(AppLocalizations l10n) => switch (this) {
    DiaryColorPreset.red => l10n.diaryColorRed,
    DiaryColorPreset.orange => l10n.diaryColorOrange,
    DiaryColorPreset.yellow => l10n.diaryColorYellow,
    DiaryColorPreset.green => l10n.diaryColorGreen,
    DiaryColorPreset.teal => l10n.diaryColorTeal,
    DiaryColorPreset.blue => l10n.diaryColorBlue,
    DiaryColorPreset.indigo => l10n.diaryColorIndigo,
    DiaryColorPreset.purple => l10n.diaryColorPurple,
    DiaryColorPreset.pink => l10n.diaryColorPink,
    DiaryColorPreset.brown => l10n.diaryColorBrown,
    DiaryColorPreset.gray => l10n.diaryColorGray,
  };
}

/// 颜色面板里的一格色块（含第一格的“默认 / 无背景”）。
///
/// - 输入：色块颜色 [color]（null 表示默认 / 无背景）、目标、选中态、点按回调；
/// - 文字目标画实心圆，选中时加勾；背景目标让半透明色叠在卡片上，并在中间写
///   一个 onSurface 的“A”，就是高亮后正文的样子（所见即所得）；
/// - “默认”格：文字目标是 onSurface 实心圆（正文实际的默认墨色），背景目标是
///   空心圆加一道斜线；
/// - 切换目标时色块原地补间到新颜色（`medium` + effects），“A”与斜线随之淡入
///   淡出；选中环缩放淡入（`fast`，缩放 spatial、透明度 effects / exit），按下
///   时色块弹性缩小。普通点按不震动（DESIGN §4.3）。
class DiaryColorSwatch extends StatefulWidget {
  const DiaryColorSwatch({
    super.key,
    required this.color,
    required this.target,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final Color? color;
  final DiaryColorTarget target;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  State<DiaryColorSwatch> createState() => _DiaryColorSwatchState();
}

class _DiaryColorSwatchState extends State<DiaryColorSwatch> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDefault = widget.color == null;
    final background = widget.target == DiaryColorTarget.background;
    final selected = widget.selected;
    // 默认格：文字目标填正文默认墨色，背景目标为透明（空心）。
    final fill = isDefault
        ? (background
              ? colors.onSurface.withValues(alpha: 0)
              : colors.onSurface)
        : widget.color!;
    final medium = ExpressiveMotion.duration(context, ExpressiveMotion.medium);
    final fast = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    final showCheck = selected && !background;

    final swatch = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: fill),
      duration: medium,
      curve: ExpressiveMotion.effects,
      builder: (BuildContext context, Color? animated, Widget? child) {
        final color = animated ?? fill;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.6),
              width: isDefault && background ? 1.2 : 1,
            ),
          ),
          child: SizedBox.square(
            dimension: kDiaryColorSwatchSize,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // 背景目标的“A”：高亮在正文上的样子。
                AnimatedOpacity(
                  opacity: background && !isDefault ? 1 : 0,
                  duration: medium,
                  curve: ExpressiveMotion.effects,
                  child: Text(
                    'A',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                // “无背景”的斜线。
                AnimatedOpacity(
                  opacity: background && isDefault ? 1 : 0,
                  duration: medium,
                  curve: ExpressiveMotion.effects,
                  child: CustomPaint(
                    size: const Size.square(kDiaryColorSwatchSize),
                    painter: _SlashPainter(colors.outline),
                  ),
                ),
                ExpressiveIconSwap(
                  switchKey: showCheck,
                  child: showCheck
                      ? FaIcon(
                          FontAwesomeIcons.check,
                          size: 11,
                          color: _checkColor(color),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );

    return Tooltip(
      message: widget.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: widget.label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: widget.onTap,
          onHighlightChanged: (bool highlighted) {
            if (highlighted != _pressed) {
              setState(() => _pressed = highlighted);
            }
          },
          radius: _kRingSize / 2,
          child: Center(
            child: SizedBox.square(
              dimension: _kRingSize,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: fast,
                    curve: selected
                        ? ExpressiveMotion.effects
                        : ExpressiveMotion.exit,
                    child: AnimatedScale(
                      scale: selected ? 1 : 0.8,
                      duration: fast,
                      curve: selected
                          ? ExpressiveMotion.spatial
                          : ExpressiveMotion.exit,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.onSurface,
                            width: _kRingWidth,
                          ),
                        ),
                        child: const SizedBox.square(dimension: _kRingSize),
                      ),
                    ),
                  ),
                  AnimatedScale(
                    scale: _pressed ? 0.88 : 1,
                    duration: fast,
                    curve: ExpressiveMotion.spatial,
                    child: swatch,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 勾选画在任意颜色上，对比色只能由色块明度决定（与 ColorSwatchButton 同一
  /// 做法，AGENTS §6 例外条款）。
  static Color _checkColor(Color swatch) =>
      ThemeData.estimateBrightnessForColor(swatch) == Brightness.dark
      ? Colors.white
      : Colors.black87;
}

/// “无背景色”格子里的斜线：从右上到左下，两端收在圆内。
class _SlashPainter extends CustomPainter {
  const _SlashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width * 0.2;
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SlashPainter oldDelegate) => oldDelegate.color != color;
}
