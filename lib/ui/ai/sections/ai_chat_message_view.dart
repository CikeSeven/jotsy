// 对话里的一条消息。
//
// - 用户：靠右的气泡；最后一个问题旁有“编辑并重发”；
// - 回答：智能体回答先列出工具步骤（`AiAgentStepsView`），再是铺满列宽的
//   Markdown（`[Dn]` 为可点的引用胶囊，合写的引用先拆开），
//   可折叠的思考过程、“参考了 N 篇日记”（展开列出被引用的日记，点按打开）、
//   出错的原因与重试、已停止的标记、可选的 token 数，以及一排操作（复制、
//   重新生成（只在最后一个回答）、另存为日记、删除）。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../controllers/ai_chat_controller.dart';
import '../models/ai_agent_steps.dart';
import '../tools/ai_tool.dart';
import '../viewmodels/ai_citations.dart';
import '../viewmodels/ai_labels.dart';
import '../viewmodels/ai_task_prompts.dart';
import '../widgets/ai_error_view.dart';
import '../widgets/ai_markdown_view.dart';
import 'ai_agent_steps_view.dart';

class AiChatMessageView extends StatelessWidget {
  const AiChatMessageView({
    super.key,
    required this.message,
    required this.showReasoning,
    required this.showTokens,
    required this.onCitation,
    required this.onCopy,
    required this.onSaveAsDiary,
    required this.onOpenPage,
    this.onUndoCalls,
    this.onEdit,
    this.onRegenerate,
    this.onDelete,
  });

  final AiMessageRow message;
  final bool showReasoning;
  final bool showTokens;

  /// 点了引用胶囊：这条回答的引用与被点的编号。
  final void Function(List<AiCitation> citations, String ref) onCitation;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onSaveAsDiary;

  /// 点了步骤里的“前往”按钮。
  final ValueChanged<AiToolNavigation> onOpenPage;

  /// 撤销这条回答里 AI 做过的改动（null 为全部）；生成中为 null。
  final void Function(Set<String>? callIds)? onUndoCalls;
  final VoidCallback? onEdit;
  final VoidCallback? onRegenerate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return message.role == AiMessageRole.user
        ? _buildQuestion(context)
        : _buildAnswer(context);
  }

  Widget _buildQuestion(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (onEdit != null)
            IconButton(
              tooltip: l10n.aiChatEditResend,
              visualDensity: VisualDensity.compact,
              onPressed: onEdit,
              icon: FaIcon(
                FontAwesomeIcons.pen,
                size: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: SelectableText(
                    message.content,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                      height: 1.5,
                    ),
                    contextMenuBuilder: appTextContextMenuBuilder,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswer(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final citations = AiCitation.decodeList(message.citations);
    final error = aiMessageError(message);
    final meta = _AnswerMeta.decode(message.meta);
    final steps = AiAgentStepRecord.decodeList(message.steps);
    final endNote = switch (meta.agentEnd) {
      'stepsExhausted' => l10n.aiAgentStepsExhausted,
      'incomplete' => l10n.aiAgentIncomplete,
      _ => null,
    };
    final metaStyle = theme.textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final footer = <String>[
      if (message.status == AiMessageStatus.stopped) l10n.aiChatStoppedLabel,
      if (showTokens && meta.input != null && meta.output != null)
        l10n.aiChatTokens(
          aiCompactCount(meta.input!),
          aiCompactCount(meta.output!),
        ),
      ?meta.model,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (steps.isNotEmpty)
            AiAgentStepsView(
              steps: steps,
              live: false,
              showReasoning: showReasoning,
              onCitation: (ref) => onCitation(citations, ref),
              onOpen: onOpenPage,
              onUndo: onUndoCalls,
            ),
          if (message.content.trim().isNotEmpty ||
              (showReasoning && message.reasoning.trim().isNotEmpty))
            AiChatAnswerBody(
              text: message.content,
              reasoning: showReasoning ? message.reasoning : '',
              onCitation: (ref) => onCitation(citations, ref),
            ),
          if (endNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                endNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          if (error != null) ...<Widget>[
            const SizedBox(height: 8),
            AiErrorView(error: error, onRetry: onRegenerate),
          ],
          if (message.status != AiMessageStatus.error ||
              message.content.trim().isNotEmpty) ...<Widget>[
            if (meta.contextEntries != null)
              _CitationList(
                citations: citations,
                contextEntries: meta.contextEntries!,
                onOpen: (ref) => onCitation(citations, ref),
              ),
            if (footer.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  footer.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle,
                ),
              ),
            Wrap(
              spacing: 0,
              children: <Widget>[
                if (message.content.trim().isNotEmpty) ...<Widget>[
                  _ActionIcon(
                    icon: FontAwesomeIcons.copy,
                    tooltip: l10n.aiPanelCopy,
                    onPressed: () => onCopy(message.content),
                  ),
                  _ActionIcon(
                    icon: FontAwesomeIcons.filePen,
                    tooltip: l10n.aiRecapSaveAsDiary,
                    onPressed: () => onSaveAsDiary(message.content),
                  ),
                ],
                if (onRegenerate != null && error == null)
                  _ActionIcon(
                    icon: FontAwesomeIcons.rotateRight,
                    tooltip: l10n.aiReplyRegenerate,
                    onPressed: onRegenerate!,
                  ),
                if (onDelete != null)
                  _ActionIcon(
                    icon: FontAwesomeIcons.trashCan,
                    tooltip: l10n.aiChatDeleteMessage,
                    onPressed: onDelete!,
                  ),
              ],
            ),
          ] else if (onDelete != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _ActionIcon(
                icon: FontAwesomeIcons.trashCan,
                tooltip: l10n.aiChatDeleteMessage,
                onPressed: onDelete!,
              ),
            ),
        ],
      ),
    );
  }
}

/// 回答的正文：可折叠的思考过程 + Markdown（流式生成中与落库后共用）。
class AiChatAnswerBody extends StatelessWidget {
  const AiChatAnswerBody({
    super.key,
    required this.text,
    required this.reasoning,
    required this.onCitation,
  });

  final String text;
  final String reasoning;
  final ValueChanged<String> onCitation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (reasoning.trim().isNotEmpty) ...<Widget>[
          AiReasoningFold(reasoning: reasoning),
          const SizedBox(height: 6),
        ],
        if (text.trim().isNotEmpty)
          AiMarkdownView(
            markdown: aiNormalizeCitations(text),
            onCitation: onCitation,
            bodyStyle: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
      ],
    );
  }
}

/// “参考了 N 篇日记”：点按展开被引用的日记（标题或日期），点一篇打开。
/// 放进上下文但没被引用的不列出；一篇都没找到时说“没有找到相关的日记”。
class _CitationList extends StatefulWidget {
  const _CitationList({
    required this.citations,
    required this.contextEntries,
    required this.onOpen,
  });

  final List<AiCitation> citations;
  final int contextEntries;
  final ValueChanged<String> onOpen;

  @override
  State<_CitationList> createState() => _CitationListState();
}

class _CitationListState extends State<_CitationList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.textTheme.labelMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    if (widget.contextEntries == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(l10n.aiChatNoCitations, style: style),
      );
    }
    final cited = widget.citations;
    final format = DateFormat.yMMMd(l10n.localeName);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: cited.isEmpty
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FaIcon(
                    FontAwesomeIcons.bookOpen,
                    size: 12,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.aiChatCitations(widget.contextEntries),
                    style: style,
                  ),
                  if (cited.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 4),
                    FaIcon(
                      _expanded
                          ? FontAwesomeIcons.angleUp
                          : FontAwesomeIcons.angleDown,
                      size: 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: ExpressiveMotion.duration(
              context,
              ExpressiveMotion.medium,
            ),
            curve: ExpressiveMotion.effects,
            alignment: Alignment.topLeft,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final citation in cited)
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => widget.onOpen(citation.ref),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: <Widget>[
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    child: Text(
                                      citation.ref.substring(1),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colors.onPrimaryContainer,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    citation.title.trim().isEmpty
                                        ? format.format(citation.date)
                                        : '${citation.title.trim()} · '
                                              '${format.format(citation.date)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final FaIconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: FaIcon(
        icon,
        size: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 回答 meta 里显示用的几项。
class _AnswerMeta {
  const _AnswerMeta({
    this.input,
    this.output,
    this.model,
    this.contextEntries,
    this.agentEnd,
  });

  factory _AnswerMeta.decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        int? number(String key) => json[key] is int ? json[key] as int : null;
        final model = json['model'];
        return _AnswerMeta(
          input: number('inputTokens'),
          output: number('outputTokens'),
          model: model is String ? model : null,
          contextEntries: number('contextEntries'),
          agentEnd: json['agentEnd'] is String
              ? json['agentEnd'] as String
              : null,
        );
      }
    } on FormatException {
      // 没有就不显示。
    }
    return const _AnswerMeta();
  }

  final int? input;
  final int? output;
  final String? model;

  /// 这一轮放进上下文的篇数；“继续聊聊”带进来的回应等没有检索过的为 null。
  final int? contextEntries;

  /// 智能体没有正常作答的原因（步数用完 / 响应被截断）。
  final String? agentEnd;
}
