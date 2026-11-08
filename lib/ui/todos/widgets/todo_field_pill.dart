import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';

/// 待办的属性胶囊（高 36、全圆角，13dp 图标 + `labelLarge`）：详情里的日期 /
/// 提醒 / 重复 / 优先级 / 清单 / 关联日记与快速新建面板的属性按钮共用。
///
/// 设了值（[set]）为 `secondaryContainer` 底、w600，没设为 `outlineVariant`
/// 0.8dp 描边、只写名称（w500）；[background] / [foreground] 覆盖配色（如
/// 逾期的日期为 `errorContainer`）。给出 [onClear] 时尾部多一个 11dp `xmark`
/// 清除按钮（读屏“移除”），否则右侧只留内边距。文字最宽 [maxLabelWidth]
/// 省略。
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
    final clear = onClear;
    return Material(
      color: bg ?? Colors.transparent,
      shape: StadiumBorder(
        side: set || background != null
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 36,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(width: AppSpacing.m),
              FaIcon(icon, size: 13, color: iconColor ?? fg),
              const SizedBox(width: AppSpacing.s),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxLabelWidth),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: set ? FontWeight.w600 : FontWeight.w500,
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
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
