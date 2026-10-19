import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../sections/notebook_action_sheets.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_header_card.dart';

/// 首页标签栏与列表之间的日记本头部：进入日记本时卡片从 0 高度展开并淡入，
/// 回到全部日记时反向收起，列表随之平滑移动而不是一帧跳开（DESIGN §4.3
/// “内容插入与移除”）。随列表一起滚走。
///
/// 在两本之间切换时新旧卡片交叉淡入，高度差同样经 [AnimatedSize] 过渡。
class NotebookHeaderSliver extends StatelessWidget {
  const NotebookHeaderSliver({
    super.key,
    required this.notebook,
    required this.onAction,
  });

  /// 当前日记本；null（全部日记）时收起为 0 高度。
  final NotebookView? notebook;
  final ValueChanged<NotebookAction> onAction;

  @override
  Widget build(BuildContext context) {
    final current = notebook;
    return SliverToBoxAdapter(
      child: AnimatedSize(
        // AnimatedSize 不接受 0 时长（见 ExpressiveMotion.durationNonZero）。
        duration: ExpressiveMotion.durationNonZero(
          context,
          ExpressiveMotion.medium,
        ),
        curve: ExpressiveMotion.effects,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
          switchInCurve: ExpressiveMotion.effects,
          switchOutCurve: ExpressiveMotion.exit,
          layoutBuilder: (Widget? currentChild, List<Widget> previous) => Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[...previous, ?currentChild],
          ),
          child: current == null
              ? const SizedBox(
                  key: ValueKey<String>('notebook_header_none'),
                  width: double.infinity,
                )
              : NotebookHeaderCard(
                  key: ValueKey<String>('notebook_header_${current.id}'),
                  notebook: current,
                  onAction: onAction,
                ),
        ),
      ),
    );
  }
}

/// 日记本里还没有日记时列表位置的空状态（沿用日记页空状态的排布）。
class NotebookEmptyState extends StatelessWidget {
  const NotebookEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FaIcon(FontAwesomeIcons.bookOpen, size: 38, color: scheme.secondary),
          const SizedBox(height: AppSpacing.m),
          Text(
            l10n.notebookEmptyTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.notebookEmptyCreateHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
