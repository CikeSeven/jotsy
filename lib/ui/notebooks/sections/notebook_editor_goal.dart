import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../widgets/expressive_button_group.dart';
import '../controllers/notebook_editor_controller.dart';
import '../viewmodels/notebook_labels.dart';

/// 写作目标（只对普通日记本）：“设置目标”开关；打开后选周期（每天 | 每周 |
/// 每月）与篇数（1–20 的步进器），下方一行写出目标原话（“每周写 3 篇”）。
///
/// 关闭开关不丢周期与篇数（再打开时恢复），保存时才决定写不写；进度显示在
/// 首页头部卡片与统计页，不做提醒通知。
class NotebookEditorGoalSection extends StatelessWidget {
  const NotebookEditorGoalSection({super.key, required this.controller});

  final NotebookEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = controller.goalTarget;
    return SettingsCardGroup(
      title: l10n.notebookGoalLabel,
      // 开关与展开的设置放在同一格里：分组卡片会在子项之间画分隔线，收起时
      // 不应留下一条线。
      children: <Widget>[
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SettingsSwitchTile(
              key: const ValueKey<String>('notebook_goal_switch'),
              title: l10n.notebookGoalEnable,
              subtitle: l10n.notebookGoalEnableHint,
              value: controller.goalEnabled,
              onChanged: (bool value) => controller.goalEnabled = value,
            ),
            // 展开 / 收起时高度过渡，下方分组随之平滑移动（DESIGN §4.3）。
            AnimatedSize(
              duration: ExpressiveMotion.durationNonZero(
                context,
                ExpressiveMotion.medium,
              ),
              curve: ExpressiveMotion.effects,
              alignment: Alignment.topCenter,
              child: !controller.goalEnabled
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.l,
                        AppSpacing.xs,
                        AppSpacing.l,
                        AppSpacing.l,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          ExpressiveButtonGroup<NotebookGoalPeriod>(
                            minSegmentWidth: 72,
                            segments: <ButtonSegment<NotebookGoalPeriod>>[
                              for (final period in NotebookGoalPeriod.values)
                                ButtonSegment<NotebookGoalPeriod>(
                                  value: period,
                                  label: Text(
                                    notebookGoalPeriodLabel(l10n, period),
                                  ),
                                ),
                            ],
                            selected: <NotebookGoalPeriod>{
                              controller.goalPeriod,
                            },
                            onSelectionChanged: (value) =>
                                controller.goalPeriod = value.single,
                          ),
                          const SizedBox(height: AppSpacing.m),
                          // 取卡片之内的 context：分组卡片为玻璃时加减按钮才
                          // 读得到 OnGlass。
                          Builder(
                            builder: (BuildContext cardContext) {
                              final tonal = AppGlassField.tonalButtonStyle(
                                cardContext,
                              );
                              return Row(
                                children: <Widget>[
                                  IconButton.filledTonal(
                                    key: const ValueKey<String>(
                                      'notebook_goal_minus',
                                    ),
                                    tooltip: l10n.notebookGoalDecrease,
                                    style: tonal,
                                    onPressed: target > NotebookGoal.minTarget
                                        ? () =>
                                              controller.goalTarget = target - 1
                                        : null,
                                    icon: const FaIcon(
                                      FontAwesomeIcons.minus,
                                      size: 14,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 48,
                                    child: Text(
                                      '$target',
                                      key: const ValueKey<String>(
                                        'notebook_goal_target',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontFeatures: const <FontFeature>[
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    key: const ValueKey<String>(
                                      'notebook_goal_plus',
                                    ),
                                    tooltip: l10n.notebookGoalIncrease,
                                    style: tonal,
                                    onPressed: target < NotebookGoal.maxTarget
                                        ? () =>
                                              controller.goalTarget = target + 1
                                        : null,
                                    icon: const FaIcon(
                                      FontAwesomeIcons.plus,
                                      size: 14,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.m),
                                  Expanded(
                                    child: Text(
                                      notebookGoalSummary(
                                        l10n,
                                        controller.goalPeriod,
                                        target,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}
