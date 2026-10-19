import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/expressive_state_blend.dart';
import '../providers/notebook_insights_providers.dart';
import '../viewmodels/notebook_goal_progress.dart';
import '../viewmodels/notebook_labels.dart';
import '../viewmodels/notebook_view.dart';

/// 写作目标的进度条：`primary` 填充在 16% `primary` 的轨道上，两端圆角。
///
/// 这是进度而不是等待状态，所以不用加载指示器；比例变化时按 `medium +
/// effects` 补间（减少动画时直接落位）。
class NotebookGoalBar extends StatelessWidget {
  const NotebookGoalBar({super.key, required this.fraction, this.height = 6});

  final double fraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(height / 2);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        // 轨道取 16% 的 primary 而不是 primaryContainer：部分种子色下
        // primaryContainer 与 primary 太接近，已完成与未完成分不开（与日历
        // 范围选择不用 primaryContainer 同理，DESIGN.md §5.7）。
        child: ColoredBox(
          color: scheme.primary.withValues(alpha: 0.16),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: fraction.clamp(0.0, 1.0)),
            duration: ExpressiveMotion.duration(
              context,
              ExpressiveMotion.medium,
            ),
            curve: ExpressiveMotion.effects,
            builder: (BuildContext context, double value, Widget? _) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: value,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 首页日记本头部卡片里的写作目标行：细进度条 + “本周 2 / 3 篇 · 连续达成
/// 4 周”。本周期达成时文字经 [ExpressiveStateBlend] 补间到 `primary` 并在
/// 前面出现对勾。点按打开编辑页（[onTap]）。
///
/// 没有目标（或不是普通日记本、成员还没读到）时不占位置。
class NotebookGoalRow extends ConsumerWidget {
  const NotebookGoalRow({super.key, required this.notebook, this.onTap});

  final NotebookView notebook;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = watchNotebookGoalProgress(context, ref, notebook);
    if (progress == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.m),
      child: NotebookGoalProgressView(progress: progress, onTap: onTap),
    );
  }
}

/// 进度条 + 进度文字（头部卡片与统计页目标卡共用）。
class NotebookGoalProgressView extends StatelessWidget {
  const NotebookGoalProgressView({
    super.key,
    required this.progress,
    this.onTap,
  });

  final NotebookGoalProgress progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final line = notebookGoalLine(
      l10n,
      progress.goal.period,
      current: progress.current,
      target: progress.target,
      streak: progress.streak,
    );
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          NotebookGoalBar(fraction: progress.fraction),
          const SizedBox(height: AppSpacing.s),
          ExpressiveStateBlend(
            active: progress.met,
            builder: (BuildContext context, double t, Widget? _) {
              final color = Color.lerp(
                scheme.onSurfaceVariant,
                scheme.primary,
                t,
              );
              return Row(
                children: <Widget>[
                  FaIcon(FontAwesomeIcons.bullseye, size: 12, color: color),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      line,
                      key: const ValueKey<String>('notebook_goal_line'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
    final onTap = this.onTap;
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }
}
