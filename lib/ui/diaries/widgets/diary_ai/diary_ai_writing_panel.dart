// 编辑页的 AI 写作面板（DESIGN.md §5.29）。
//
// 与录音面板同一位置：悬浮工具栏下方的一张卡片（工具栏材质）。由编辑页
// 持有会话（[AiWritingSession]），键盘收起、工具栏卸载时生成不中断。面板
// 只负责展示与收集操作，流程（确认、请求、写回）由编辑页经回调执行。
//
// 结构：标题行（作用范围 + 关闭）→ 指令胶囊一行（横向滚动）→ 自由指令
// 输入框 → 结果区（生成中显示“正在思考”或流式文字，结束后给出替换 / 插在
// 下方 / 复制 / 重试；出错给出原因）。结果区最高 [_resultMaxHeight]，超出
// 在区内滚动，整张卡片高度有上限，编辑页按 [reservedHeight] 给正文让位。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/text_stats.dart';
import '../../../ai/controllers/ai_stream_run.dart';
import '../../../ai/controllers/ai_writing_session.dart';
import '../../../ai/models/ai_built_ins.dart';
import '../../../ai/models/ai_preference_parts.dart';
import '../../../ai/widgets/ai_error_view.dart';
import '../../../ai/widgets/ai_markdown_view.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../widgets/desktop_horizontal_scroll.dart';
import '../../../widgets/expressive_loading_indicator.dart';
import '../../../widgets/expressive_menu/expressive_menu_button.dart';
import '../../../widgets/expressive_menu/expressive_menu_item.dart';
import '../../../widgets/expressive_menu/expressive_menu_layout.dart';
import '../../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../controllers/diary_ai_editing.dart';

class DiaryAiWritingPanel extends StatefulWidget {
  const DiaryAiWritingPanel({
    super.key,
    required this.session,
    required this.actions,
    required this.showReasoning,
    required this.onAction,
    required this.onInstruction,
    required this.onApply,
    required this.onCopy,
    required this.onClose,
  });

  /// 编辑页给正文末尾让出的高度（卡片上限 + 与工具栏的间距）。
  static const double reservedHeight = 380;

  final AiWritingSession session;
  final List<AiActionInfo> actions;
  final bool showReasoning;
  final ValueChanged<AiActionInfo> onAction;
  final ValueChanged<String> onInstruction;
  final ValueChanged<AiActionOutput> onApply;
  final ValueChanged<String> onCopy;
  final VoidCallback onClose;

  @override
  State<DiaryAiWritingPanel> createState() => _DiaryAiWritingPanelState();
}

class _DiaryAiWritingPanelState extends State<DiaryAiWritingPanel> {
  static const double _resultMaxHeight = 180;

  final TextEditingController _instruction = TextEditingController();

  @override
  void dispose() {
    _instruction.dispose();
    super.dispose();
  }

  void _send() {
    final text = _instruction.text.trim();
    if (text.isEmpty || widget.session.run.running) return;
    FocusScope.of(context).unfocus();
    widget.onInstruction(text);
  }

  void _retry() {
    final session = widget.session;
    final action = session.action;
    if (action != null) {
      widget.onAction(action);
    } else if (session.instruction case final instruction?) {
      widget.onInstruction(instruction);
    }
  }

  String _scopeLabel(AppLocalizations l10n, DiaryAiScope scope) =>
      switch (scope) {
        DiaryAiScope.selection => l10n.aiScopeSelection,
        DiaryAiScope.paragraph => l10n.aiScopeParagraph,
        DiaryAiScope.beforeCaret => l10n.aiScopeBeforeCaret,
        DiaryAiScope.document => l10n.aiScopeDocument,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListenableBuilder(
      listenable: widget.session,
      builder: (BuildContext context, Widget? child) {
        final session = widget.session;
        final run = session.run;
        final target = session.target;
        final scopes = <DiaryAiScope>[
          if (session.hasSelection) DiaryAiScope.selection,
          DiaryAiScope.paragraph,
          DiaryAiScope.document,
        ];
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  FaIcon(
                    FontAwesomeIcons.wandMagicSparkles,
                    size: 14,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.aiPanelTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ExpressiveMenuButton(
                        tooltip: l10n.aiPanelTitle,
                        placement: ExpressiveMenuPlacement.start,
                        enabled: !run.running,
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                l10n.aiScopeSummary(
                                  _scopeLabel(l10n, session.scope),
                                  TextStats.countWords(target?.text ?? ''),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            FaIcon(
                              FontAwesomeIcons.angleDown,
                              size: 10,
                              color: colors.onSurfaceVariant,
                            ),
                          ],
                        ),
                        items: <Widget>[
                          for (final scope in scopes)
                            ExpressiveMenuItem(
                              selected: scope == session.scope,
                              onPressed: () => session.setScope(scope),
                              child: Text(_scopeLabel(l10n, scope)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonClose,
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onClose,
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 40,
                child: DesktopHorizontalScroll(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.actions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final action = widget.actions[index];
                      final selected =
                          identical(session.action?.id, action.id) &&
                          run.status != AiRunStatus.idle;
                      return ActionChip(
                        avatar: Text(action.emoji),
                        label: Text(action.label),
                        backgroundColor: selected
                            ? colors.primaryContainer
                            : null,
                        onPressed: run.running
                            ? null
                            : () => widget.onAction(action),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextField(
                  controller: _instruction,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.aiPanelInstructionHint,
                    suffixIcon: IconButton(
                      tooltip: l10n.aiPanelSend,
                      onPressed: run.running ? null : _send,
                      icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 14),
                    ),
                  ),
                  contextMenuBuilder: appTextContextMenuBuilder,
                ),
              ),
              AnimatedSize(
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.medium,
                ),
                curve: ExpressiveMotion.effects,
                alignment: Alignment.topCenter,
                child: run.status == AiRunStatus.idle
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 10, right: 4),
                        child: _Result(
                          session: session,
                          showReasoning: widget.showReasoning,
                          maxHeight: _resultMaxHeight,
                          onApply: widget.onApply,
                          onCopy: widget.onCopy,
                          onRetry: _retry,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.session,
    required this.showReasoning,
    required this.maxHeight,
    required this.onApply,
    required this.onCopy,
    required this.onRetry,
  });

  final AiWritingSession session;
  final bool showReasoning;
  final double maxHeight;
  final ValueChanged<AiActionOutput> onApply;
  final ValueChanged<String> onCopy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final run = session.run;
    final body = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurface,
      height: 1.55,
    );
    final tonal = AppGlassField.tonalButtonStyle(context);
    final fill = AppGlassField.of(context)?.fill ?? colors.surfaceContainerHigh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SingleChildScrollView(
            reverse: run.running,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (showReasoning && run.reasoning.trim().isNotEmpty)
                  AiReasoningFold(reasoning: run.reasoning),
                if (run.hasText)
                  AiMarkdownView(markdown: session.result, bodyStyle: body)
                else if (run.running)
                  Row(
                    children: <Widget>[
                      const ExpressiveLoadingIndicator(size: 20),
                      const SizedBox(width: 10),
                      Text(
                        l10n.aiPanelThinking,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                if (run.status == AiRunStatus.failed && run.error != null)
                  Padding(
                    padding: EdgeInsets.only(top: run.hasText ? 8 : 0),
                    child: AiErrorView(error: run.error!, onRetry: onRetry),
                  ),
                if (run.status == AiRunStatus.stopped)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l10n.aiErrorCancelled,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (run.running)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: run.stop,
              icon: const FaIcon(FontAwesomeIcons.stop, size: 12),
              label: Text(l10n.aiPanelStop),
            ),
          )
        else if (run.hasResult)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => onCopy(session.result),
                child: Text(l10n.aiPanelCopy),
              ),
              TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
              FilledButton.tonal(
                style: tonal,
                onPressed: () => onApply(AiActionOutput.insertBelow),
                child: Text(l10n.aiPanelInsertBelow),
              ),
              if (session.target?.scope != DiaryAiScope.beforeCaret &&
                  session.action?.scope != AiActionScope.beforeCaret)
                FilledButton(
                  onPressed: () => onApply(AiActionOutput.replace),
                  child: Text(l10n.aiPanelReplace),
                ),
            ],
          ),
      ],
    );
  }
}
