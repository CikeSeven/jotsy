import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';

/// 待办的属性胶囊（高 36、全圆角，13dp 图标 + `labelLarge`）：详情里的日期 /
/// 提醒 / 重复 / 优先级 / 清单 / 关联日记与快速新建面板的属性按钮共用。
///
/// 设了值（[set]）为 `secondaryContainer` 底、w600，没设为 `outlineVariant`
/// 0.8dp 描边、只写名称（w500）；[background] / [foreground] 覆盖配色（如
/// 逾期的日期为 `errorContainer`）。给出 [onClear] 时尾部多一个 11dp `xmark`
/// 清除按钮（读屏“移除”），否则右侧只留内边距。文字最宽 [maxLabelWidth]
/// 省略。
///
/// 值变化时不硬切：底色、字色与描边一起补间，宽度按弹簧过渡，文字交叉淡入。
class TodoFieldPill extends StatelessWidget {
  const TodoFieldPill({
    super.key,
    required this.icon,
    required this.label,
    required this.set,
    required this.onTap,
    this.onClear,
    this.iconColor,
    this.background,
    this.foreground,
    this.maxLabelWidth = 200,
  });

  final FaIconData icon;
  final String label;

  /// 是否设了值：没设时画成描边、只写名称的占位。
  final bool set;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final Color? iconColor;
  final Color? background;
  final Color? foreground;
  final double maxLabelWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg =
        foreground ??
        (set ? scheme.onSecondaryContainer : scheme.onSurfaceVariant);
    final bg = background ?? (set ? scheme.secondaryContainer : null);
    final outlined = !set && background == null;
    final clear = onClear;
    final medium = ExpressiveMotion.duration(context, ExpressiveMotion.medium);
    // 值变化时：底色、字色与描边一起补间（effects），宽度按弹簧过渡，文字
    // 交叉淡入；减少动画时直接换。
    return TweenAnimationBuilder<_PillColors>(
      tween: _PillColorsTween(
        end: _PillColors(
          background: bg ?? scheme.surface.withValues(alpha: 0),
          foreground: fg,
          icon: iconColor ?? fg,
          border: outlined
              ? scheme.outlineVariant
              : scheme.outlineVariant.withValues(alpha: 0),
        ),
      ),
      duration: medium,
      curve: ExpressiveMotion.effects,
      builder: (BuildContext context, _PillColors colors, Widget? _) {
        return Material(
          color: colors.background,
          shape: StadiumBorder(
            side: BorderSide(color: colors.border, width: 0.8),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: AnimatedSize(
              // AnimatedSize 不接受 0 时长（见 durationNonZero）。
              duration: ExpressiveMotion.durationNonZero(
                context,
                ExpressiveMotion.medium,
              ),
              curve: ExpressiveMotion.spatial,
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(width: AppSpacing.m),
                    FaIcon(icon, size: 13, color: colors.icon),
                    const SizedBox(width: AppSpacing.s),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxLabelWidth),
                        child: AnimatedSwitcher(
                          duration: medium,
                          switchInCurve: ExpressiveMotion.effects,
                          switchOutCurve: ExpressiveMotion.exit,
                          layoutBuilder: _stackStart,
                          child: Text(
                            label,
                            key: ValueKey<String>(label),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colors.foreground,
                              fontWeight: set
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (clear == null)
                      const SizedBox(width: AppSpacing.m)
                    else
                      Semantics(
                        button: true,
                        label: context.l10n.todoQuickParseDismiss,
                        excludeSemantics: true,
                        child: InkResponse(
                          onTap: clear,
                          radius: 16,
                          child: SizedBox(
                            width: 32,
                            height: 36,
                            child: Center(
                              child: FaIcon(
                                FontAwesomeIcons.xmark,
                                size: 11,
                                color: colors.foreground,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _stackStart(Widget? current, List<Widget> previous) => Stack(
    alignment: AlignmentDirectional.centerStart,
    children: <Widget>[...previous, ?current],
  );
}

/// 胶囊的几种颜色，随值一起补间。
@immutable
class _PillColors {
  const _PillColors({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color icon;
  final Color border;

  static _PillColors lerp(_PillColors a, _PillColors b, double t) =>
      _PillColors(
        background: Color.lerp(a.background, b.background, t)!,
        foreground: Color.lerp(a.foreground, b.foreground, t)!,
        icon: Color.lerp(a.icon, b.icon, t)!,
        border: Color.lerp(a.border, b.border, t)!,
      );
}

class _PillColorsTween extends Tween<_PillColors> {
  _PillColorsTween({super.end});

  @override
  _PillColors lerp(double t) => _PillColors.lerp(begin ?? end!, end!, t);
}
