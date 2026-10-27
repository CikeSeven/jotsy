import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';

/// 日历显示选项面板的通用行组件：分组标题、字段标签、开关行与淡入说明。
/// 只负责排版，状态与保存由面板处理。

class CalendarOptionsSectionHeader extends StatelessWidget {
  const CalendarOptionsSectionHeader({
    super.key,
    required this.icon,
    required this.label,
  });

  final FaIconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Row(
        children: <Widget>[
          FaIcon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.s),
          // 窄屏与大字号下标题换行，不溢出（DESIGN.md §6）。
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CalendarOptionsFieldLabel extends StatelessWidget {
  const CalendarOptionsFieldLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.s),
      child: Text(
        text,
        // 也用在模板编辑、日记本编辑这类表单页上，标签直接画在页面背景上：
        // 有背景图时加可读性兜底（面板与对话框里没有页面背景，原样返回）。
        style: AppPageBackdrop.onBackgroundTextStyle(
          context,
          theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 面板内开关行：与设置页的 SwitchListTile 同款，内边距收窄以对齐分组标题。
class CalendarOptionSwitch extends StatelessWidget {
  const CalendarOptionSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    final theme = Theme.of(context);
    // 与面板里的单选项同一字阶（bodyMedium w500），开关行不比分组标题更抢眼。
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      value: value,
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: description == null
          ? null
          : Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
      onChanged: onChanged,
    );
  }
}

/// 样式说明：随选中样式短交叉淡入，不在一帧内换字。
class CalendarOptionsFadingText extends StatelessWidget {
  const CalendarOptionsFadingText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: AnimatedSwitcher(
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        switchInCurve: ExpressiveMotion.effects,
        switchOutCurve: ExpressiveMotion.exit,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: <Widget>[...previousChildren, ?currentChild],
        ),
        child: Text(
          text,
          key: ValueKey<String>(text),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
