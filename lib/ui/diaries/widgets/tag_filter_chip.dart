import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/expressive_state_blend.dart';

/// 顶部标签筛选项通用组件。
///
/// 支持两类视觉形态：
/// - 普通标签（可选颜色点）；
/// - 特殊入口（通过 `leading` 自定义左侧图标）。
///
/// 选中切换的动效（外框尺寸不随选中变化：邻居不被挤动，展开多行时不换行）：
/// - 字重 w600 → w700 不是一帧跳变：两种字重的文字叠放、交叉淡入，宽度
///   始终按粗体占位；
/// - 文字颜色与底色、描边、圆角同步补间（`ExpressiveStateBlend` /
///   AnimatedContainer，同为 fast + effects）；
/// - [animateBorder] 时描边 1.2 ↔ 2.0 的粗细差补进内边距，外框不变；
/// - 自己画选中底色时（[paintsSelectedSurface]），变为选中的那一刻按
///   `springSpatialFast` 轻弹一下（减少动画时没有）。
class TagFilterChip extends StatefulWidget {
  const TagFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.selectedForegroundColor,
    required this.unselectedColor,
    required this.unselectedForegroundColor,
    required this.onTap,
    this.onLongPress,
    this.longPressHint,
    this.colorDot,
    this.leading,
    this.radius = AppRadii.nav,
    this.colorDotSize = 8,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.m,
      vertical: AppSpacing.s,
    ),
    this.animateBorder = false,
    this.showSelectedShadow = false,
    this.selectedBorderColor,
    this.unselectedBorderColor,
    this.paintsSelectedSurface = true,
  });

  /// [animateBorder] 时选中与未选中的描边粗细；外框按较粗的一档占位。
  static const double selectedBorderWidth = 2.0;
  static const double unselectedBorderWidth = 1.2;

  /// 选中时的圆角（超过胶囊高度一半，即两端全圆）。
  static const double selectedRadius = 24.0;

  /// 变为选中时叠加的缩放初速度（倍 / 秒）：`springSpatialFast` 下峰值约
  /// 1.035 倍，看得出“弹了一下”又不显得跳。
  static const double popKick = 2.0;

  /// 文案标签。
  final String label;

  /// 当前是否选中。
  final bool selected;
  final Color selectedColor;
  final Color selectedForegroundColor;
  final Color unselectedColor;
  final Color unselectedForegroundColor;
  final Color? selectedBorderColor;
  final Color? unselectedBorderColor;

  /// 点击回调。
  final VoidCallback onTap;

  /// 长按回调（首页标签栏用来多选）；为 null 时不响应长按。
  final VoidCallback? onLongPress;

  /// 读屏的长按说明（“双击并按住以 …”），只在 [onLongPress] 不为 null 时
  /// 有意义。
  final String? longPressHint;
  final Color? colorDot;
  final Widget? leading;
  final double radius;
  final double colorDotSize;
  final EdgeInsetsGeometry padding;

  /// 动态边框过渡（用于和主色卡片一致的“选中态切换感”）。
  final bool animateBorder;

  /// 选中态阴影开关。
  final bool showSelectedShadow;

  /// 选中时是否由胶囊自己画选中底色与描边。为 false 时（首页标签栏只选
  /// 一个标签，由滑动色块画在胶囊下方）底色与描边淡成透明、露出下面的
  /// 色块，文字仍按选中补间。
  final bool paintsSelectedSurface;

  @override
  State<TagFilterChip> createState() => _TagFilterChipState();
}

class _TagFilterChipState extends State<TagFilterChip>
    with SingleTickerProviderStateMixin {
  /// 选中轻弹的缩放（无界：弹簧会越过 1 再落回）。
  late final AnimationController _pop = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  @override
  void didUpdateWidget(TagFilterChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected &&
        !oldWidget.selected &&
        widget.paintsSelectedSurface) {
      ExpressiveMotion.springTo(
        context,
        _pop,
        1,
        spring: ExpressiveMotion.springSpatialFast,
        kick: TagFilterChip.popKick,
      );
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = widget.selected;
    final selfSelected = selected && widget.paintsSelectedSurface;
    final selectedBorder =
        widget.selectedBorderColor ??
        widget.selectedForegroundColor.withValues(alpha: 0.45);
    final unselectedBorder =
        widget.unselectedBorderColor ??
        colorScheme.outlineVariant.withValues(alpha: 0.55);
    // 由色块代画时淡到同色的全透明（而不是 Colors.transparent），补间途中
    // 不会先发灰发黑。
    final Color backgroundColor;
    final Color borderColor;
    if (selfSelected) {
      backgroundColor = widget.selectedColor;
      borderColor = selectedBorder;
    } else if (selected) {
      backgroundColor = widget.unselectedColor.withValues(alpha: 0);
      borderColor = unselectedBorder.withValues(alpha: 0);
    } else {
      backgroundColor = widget.unselectedColor;
      borderColor = unselectedBorder;
    }
    final borderWidth = selected
        ? TagFilterChip.selectedBorderWidth
        : TagFilterChip.unselectedBorderWidth;
    // 描边变细时把差额补进内边距：AnimatedContainer 用同一条曲线补间两者，
    // 途中每一帧外框都不变。
    final padding = widget.animateBorder
        ? widget.padding.add(
            EdgeInsets.all(TagFilterChip.selectedBorderWidth - borderWidth),
          )
        : widget.padding;
    final duration = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    final targetRadius = selected
        ? TagFilterChip.selectedRadius
        : widget.radius;
    final labelStyle = Theme.of(context).textTheme.labelMedium!;

    return Semantics(
      selected: selected,
      button: true,
      onLongPressHint: widget.onLongPress == null ? null : widget.longPressHint,
      child: ScaleTransition(
        scale: _pop,
        child: ExpressiveStateBlend(
          active: selected,
          child: _buildPrefix(),
          builder: (BuildContext context, double t, Widget? prefix) {
            // 水波纹的裁切圆角与底色圆角同一条曲线补间，按下时不露方角。
            final inkRadius = BorderRadius.circular(
              lerpDouble(widget.radius, TagFilterChip.selectedRadius, t)!,
            );
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                borderRadius: inkRadius,
                child: AnimatedContainer(
                  duration: duration,
                  curve: ExpressiveMotion.effects,
                  padding: padding,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(targetRadius),
                    border: widget.animateBorder
                        ? Border.all(color: borderColor, width: borderWidth)
                        : null,
                    boxShadow: selfSelected && widget.showSelectedShadow
                        ? <BoxShadow>[
                            BoxShadow(
                              color: backgroundColor.withAlpha(140),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: _ChipLabelBlend(
                    t: t,
                    label: widget.label,
                    style: labelStyle,
                    foreground: Color.lerp(
                      widget.unselectedForegroundColor,
                      widget.selectedForegroundColor,
                      t,
                    )!,
                    leading: widget.leading,
                    prefix: prefix,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// `#` 色点：颜色不随选中变化，交给补间的 builder 原样复用。
  Widget? _buildPrefix() {
    final colorDot = widget.colorDot;
    if (colorDot == null) {
      return null;
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: SizedBox(
        width: 14,
        child: Center(
          child: Text(
            '#',
            style: TextStyle(
              color: colorDot,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// 胶囊里的一行：前置图标、`#` 色点与两种字重叠放的标签文字。
///
/// 常规字重的一层是真正的文字（参与语义与 `find.text`）；粗体的一层用
/// RichText 直接画并排除语义，只负责交叉淡入与按粗体宽度占位——Stack 取
/// 最宽的子项，选中前后宽度一致。
class _ChipLabelBlend extends StatelessWidget {
  const _ChipLabelBlend({
    required this.t,
    required this.label,
    required this.style,
    required this.foreground,
    required this.leading,
    required this.prefix,
  });

  /// 选中程度（0 未选中 → 1 选中）。
  final double t;
  final String label;
  final TextStyle style;
  final Color foreground;
  final Widget? leading;
  final Widget? prefix;

  @override
  Widget build(BuildContext context) {
    final defaults = DefaultTextStyle.of(context);
    final regular = style.copyWith(
      color: foreground,
      fontWeight: FontWeight.w600,
    );
    final bold = defaults.style.merge(
      style.copyWith(color: foreground, fontWeight: FontWeight.w700),
    );
    final leading = this.leading;
    final prefix = this.prefix;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (leading != null) ...[
          IconTheme(
            data: IconThemeData(color: foreground, size: 12),
            child: leading,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        ?prefix,
        Flexible(
          fit: FlexFit.loose,
          child: Stack(
            alignment: Alignment.center,
            // 粗体垫在下面：命中测试从上往下找，点在文字上命中的是常规
            // 那一层（真正的文字），交叉淡入与叠放顺序无关。
            children: <Widget>[
              ExcludeSemantics(
                child: Opacity(
                  opacity: t,
                  child: RichText(
                    text: TextSpan(text: label, style: bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: MediaQuery.textScalerOf(context),
                    textHeightBehavior: defaults.textHeightBehavior,
                  ),
                ),
              ),
              Opacity(
                opacity: 1 - t,
                // 选中后这一层完全透明，读屏仍要读到标签名。
                alwaysIncludeSemantics: true,
                child: Text(
                  label,
                  style: regular,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
