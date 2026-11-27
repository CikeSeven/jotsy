import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../ai/controllers/ai_stream_run.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../ai/widgets/ai_error_view.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../../widgets/list_item_presence.dart';
import '../controllers/todo_ai_drafts.dart';

/// 待办 AI 建议的预览（详情的“AI 拆解”、快速新建的“AI 整理”共用外壳）。
///
/// 待办领域色 `secondaryContainer` 淡底圆角块（DESIGN §5.29）：
/// - 标题行：星光图标 + [title]；生成中行尾小指示器与“正在生成…”；
/// - 建议：[itemBuilder] 逐条构建，新长出的从 0 展开进场（`medium`）；
/// - 结束没有可用结果时写一句说明，出错时为 [AiErrorView]（可重试）；
/// - 底部：生成中只有“停止”；结束后左“放弃”、右 tonal 主按钮
///   （[useLabel]，一条都没勾时不可点）。
///
/// 进出场由宿主按 [TodoAiDrafts.active] 包 [ListItemPresence]；收起途中
/// 这里仍画最后一次的内容。
class TodoAiPreview<T> extends StatefulWidget {
  const TodoAiPreview({
    super.key,
    required this.drafts,
    required this.title,
    required this.itemBuilder,
    required this.useLabel,
    required this.onUse,
    required this.onRetry,
  });

  final TodoAiDrafts<T> drafts;
  final String title;
  final Widget Function(BuildContext context, int index, T item) itemBuilder;
  final String Function(int count) useLabel;
  final VoidCallback onUse;
  final VoidCallback onRetry;

  @override
  State<TodoAiPreview<T>> createState() => _TodoAiPreviewState<T>();
}

class _TodoAiPreviewState<T> extends State<TodoAiPreview<T>> {
  /// 这一次生成已经演过进场的条数：之后重建（勾选、改写）不再演。
  int _shown = 0;
  TodoAiDrafts<T>? _listening;

  /// 上一次显示的内容：放弃 / 使用后结果马上清掉，宿主收起预览的那一段
  /// 里仍画它（不可点），不会先变空再收起。
  Widget? _last;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant TodoAiPreview<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drafts != widget.drafts) _listen();
  }

  void _listen() {
    _listening?.removeListener(_changed);
    _listening = widget.drafts..addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _listening?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drafts = widget.drafts;
    // 外面总是同一个 IgnorePointer：收起时换成不可点，内容不重新挂载。
    final content = drafts.active ? _content(context) : _last;
    return IgnorePointer(
      ignoring: !drafts.active,
      child: content ?? const SizedBox.shrink(),
    );
  }

  Widget _content(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final drafts = widget.drafts;
    final items = drafts.items;
    if (items.length < _shown) _shown = 0;
    final firstNew = _shown;
    _shown = items.length;
    final running = drafts.running;
    final error = drafts.status == AiRunStatus.failed ? drafts.error : null;
    final nothing = !running && error == null && items.isEmpty;
    final chosen = drafts.chosen.length;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    final fg = scheme.onSecondaryContainer;
    return _last = Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
        AppSpacing.s,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.32 : 0.45,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 13, color: fg),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (running) ...<Widget>[
                Text(
                  l10n.todoAiGenerating,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                ExpressiveLoadingIndicator(
                  size: 20,
                  semanticLabel: l10n.todoAiGenerating,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < items.length; i++)
            ListItemPresence(
              key: ValueKey<int>(i),
              visible: true,
              appearing: i >= firstNew,
              duration: duration,
              child: widget.itemBuilder(context, i, items[i]),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s),
              child: AiErrorView(error: error, onRetry: widget.onRetry),
            )
          else if (nothing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
              child: Text(
                l10n.todoAiNothing,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (running)
                TextButton(
                  onPressed: drafts.stop,
                  child: Text(l10n.aiPanelStop),
                )
              else ...<Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                  ),
                  onPressed: drafts.reset,
                  child: Text(l10n.todoAiDiscard),
                ),
                if (items.isNotEmpty) ...<Widget>[
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton.tonal(
                    style: AppGlassField.tonalButtonStyle(context),
                    onPressed: chosen == 0 ? null : widget.onUse,
                    child: Text(widget.useLabel(chosen)),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 预览里一条建议前的勾选框（读屏读作“保留某某”）。
class TodoAiKeepBox extends StatelessWidget {
  const TodoAiKeepBox({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.todoAiKeep(title),
      child: Checkbox(value: value, onChanged: (_) => onChanged()),
    );
  }
}
