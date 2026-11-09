// 对话里的一条消息（DESIGN §5.29“消息”）。
//
// - 问题：靠右的气泡（`primaryContainer`，20 圆角、右下角 6，最宽 520），
//   可长按选字（`AppSelectionArea`）；最后一问左侧 12dp 铅笔“编辑并重发”。
// - 回答：头部（24dp 人设头像 + 名称），分段（`AiAnswerSegmentsView`：思考
//   过程折叠块、前往 / 改动 / 确认卡片、正文），然后是没有正常作答的说明、
//   错误与重试、“参考了 N 篇日记”（点按展开为可点的日记胶囊）、一行灰字
//   （已停止 · 思考强度 · token · 模型）与一排 14dp 图标按钮（复制、另存为
//   日记、重新生成（只在最后一个回答）、删除）。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/widgets/diary_comments/diary_comment_images.dart';
import '../controllers/ai_chat_controller.dart';
import '../controllers/ai_chat_links.dart';
import '../models/ai_agent_steps.dart';
import '../models/ai_built_ins.dart';
import '../models/ai_tool_subject.dart';
import '../viewmodels/ai_answer_segments.dart';
import '../viewmodels/ai_labels.dart';
import '../viewmodels/ai_task_prompts.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../widgets/ai_error_view.dart';
import '../widgets/ai_view_state.dart';
import 'chat/ai_answer_actions.dart';
import 'chat/ai_answer_segments_view.dart';
import 'chat/ai_subject_chips.dart';

class AiChatMessageView extends StatelessWidget {
  const AiChatMessageView({
    super.key,
    required this.message,
    required this.persona,
    required this.showReasoning,
    required this.showTokens,
    required this.actions,
    required this.onCopy,
    required this.onSaveAsDiary,
    this.onEdit,
    this.onRegenerate,
    this.onDelete,
  });

  final AiMessageRow message;
  final AiPersonaInfo persona;
  final bool showReasoning;
  final bool showTokens;
  final AiAnswerActions actions;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onSaveAsDiary;
  final VoidCallback? onEdit;
  final VoidCallback? onRegenerate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (message.role == AiMessageRole.user) {
      final images = decodeAiMessageImages(message.images);
      return AiQuestionBubble(
        text: message.content,
        imageGroupId: message.messageId,
        images: liveAiMessageImages(images),
        removedImages: images.length - liveAiMessageImages(images).length,
        onEdit: onEdit,
      );
    }
    final meta = _AnswerMeta.decode(message.meta);
    final segments = buildAiAnswerSegments(
      steps: AiAgentStepRecord.decodeList(message.steps),
      reasoning: message.reasoning,
      text: message.content,
      showReasoning: showReasoning,
      thinkingMs: meta.thinkingMs ?? 0,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AiAnswerHeader(persona: persona),
          const SizedBox(height: 10),
          if (segments.isNotEmpty)
            AiAnswerSegmentsView(
              keyPrefix: message.messageId,
              segments: segments,
              actions: actions,
            ),
          _AnswerFooter(
            message: message,
            meta: meta,
            showTokens: showTokens,
            actions: actions,
            onCopy: onCopy,
            onSaveAsDiary: onSaveAsDiary,
            onRegenerate: onRegenerate,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

/// 问题气泡：附图（与留言同一种拼贴，点开看图）在上，文字气泡在下，都靠
/// 右；附图被存储管理删掉时下方注明几张已删除。只有图片时没有文字气泡。
class AiQuestionBubble extends StatelessWidget {
  const AiQuestionBubble({
    super.key,
    required this.text,
    this.imageGroupId = '',
    this.images = const <String>[],
    this.removedImages = 0,
    this.onEdit,
  });

  /// 附图拼贴的共享元素标签按它区分（消息的业务 id）。
  final String imageGroupId;

  final String text;

  /// 还在的附图（托管图片路径）。
  final List<String> images;

  /// 已被删掉的附图张数。
  final int removedImages;
  final VoidCallback? onEdit;

  /// 附图拼贴的最大宽度。
  static const double imagesMaxWidth = 280;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const radius = BorderRadius.only(
      topLeft: Radius.circular(20),
      topRight: Radius.circular(20),
      bottomLeft: Radius.circular(20),
      bottomRight: Radius.circular(6),
    );
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (images.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: imagesMaxWidth),
                    child: DiaryCommentImages(
                      commentId: 'ai-$imageGroupId',
                      images: images,
                    ),
                  ),
                if (images.isNotEmpty && text.trim().isNotEmpty)
                  const SizedBox(height: 6),
                if (text.trim().isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: radius,
                      ),
                      // 长按选字，菜单与回答正文同一套（复制、全选、分享）。
                      child: AppSelectionArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Text(
                            text,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colors.onPrimaryContainer,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (removedImages > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4),
                    child: Text(
                      l10n.aiChatImagesRemoved(removedImages),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
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

/// 回答的头部：人设头像与名称。
class AiAnswerHeader extends StatelessWidget {
  const AiAnswerHeader({super.key, required this.persona});

  final AiPersonaInfo persona;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: 26,
            child: Center(
              child: Text(persona.emoji, style: const TextStyle(fontSize: 14)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            persona.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnswerFooter extends StatelessWidget {
  const _AnswerFooter({
    required this.message,
    required this.meta,
    required this.showTokens,
    required this.actions,
    required this.onCopy,
    required this.onSaveAsDiary,
    this.onRegenerate,
    this.onDelete,
  });

  final AiMessageRow message;
  final _AnswerMeta meta;
  final bool showTokens;
  final AiAnswerActions actions;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onSaveAsDiary;
  final VoidCallback? onRegenerate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final citations = AiCitation.decodeList(message.citations);
    final error = aiMessageError(message);
    final hasText = message.content.trim().isNotEmpty;
    final endNote = switch (meta.agentEnd) {
      'stepsExhausted' => l10n.aiAgentStepsExhausted,
      'incomplete' => l10n.aiAgentIncomplete,
      _ => null,
    };
    final footer = <String>[
      if (message.status == AiMessageStatus.stopped) l10n.aiChatStoppedLabel,
      if (meta.thinking case final level?)
        l10n.aiChatMetaThinking(aiThinkingLevelLabel(l10n, level)),
      if (showTokens && meta.input != null && meta.output != null)
        (meta.cached ?? 0) > 0
            ? l10n.aiChatTokensCached(
                aiCompactCount(meta.input!),
                aiCompactCount(meta.cached!),
                aiCompactCount(meta.output!),
              )
            : l10n.aiChatTokens(
                aiCompactCount(meta.input!),
                aiCompactCount(meta.output!),
              ),
      ?meta.model,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (endNote != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
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
        if (message.status != AiMessageStatus.error || hasText) ...<Widget>[
          if (meta.contextEntries != null)
            _CitationList(
              citations: citations,
              contextEntries: meta.contextEntries!,
              onOpen: actions.onOpenSubject,
              storageId: '${message.messageId}:citations',
            ),
          if (footer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                footer.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          Wrap(
            children: <Widget>[
              if (hasText) ...<Widget>[
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
    );
  }
}

/// “参考了 N 篇日记”：点按展开被引用的日记胶囊（点一篇打开）；放进上下文
/// 但没被引用的不列出；一篇都没找到时说“没有找到相关的日记”。
class _CitationList extends StatefulWidget {
  const _CitationList({
    required this.citations,
    required this.contextEntries,
    required this.onOpen,
    required this.storageId,
  });

  final List<AiCitation> citations;
  final int contextEntries;
  final ValueChanged<AiToolSubject> onOpen;
  final String storageId;

  @override
  State<_CitationList> createState() => _CitationListState();
}

class _CitationListState extends State<_CitationList> {
  late bool _expanded = aiReadExpanded(context, widget.storageId);

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
        padding: const EdgeInsets.only(top: 10),
        child: Text(l10n.aiChatNoCitations, style: style),
      );
    }
    final cited = widget.citations;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: cited.isEmpty
                ? null
                : () {
                    setState(() => _expanded = !_expanded);
                    aiWriteExpanded(context, widget.storageId, _expanded);
                  },
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
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: ExpressiveMotion.duration(
                        context,
                        ExpressiveMotion.fast,
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.angleDown,
                        size: 10,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: ExpressiveMotion.durationNonZero(
              context,
              ExpressiveMotion.medium,
            ),
            curve: ExpressiveMotion.effects,
            alignment: Alignment.topLeft,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 2),
                    child: AiSubjectChips(
                      max: 12,
                      subjects: [
                        for (final citation in cited)
                          aiCitationSubject(citation),
                      ],
                      onOpen: widget.onOpen,
                    ),
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
    this.cached,
    this.model,
    this.contextEntries,
    this.agentEnd,
    this.thinking,
    this.thinkingMs,
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
          cached: number('cachedTokens'),
          model: model is String ? model : null,
          contextEntries: number('contextEntries'),
          agentEnd: json['agentEnd'] is String
              ? json['agentEnd'] as String
              : null,
          thinking: AiThinkingLevel.parse(json['thinking']),
          thinkingMs: number('thinkingMs'),
        );
      }
    } on FormatException {
      // 没有就不显示。
    }
    return const _AnswerMeta();
  }

  final int? input;
  final int? output;

  /// 输入里命中提示缓存的部分（服务商不报或没命中时为 null）。
  final int? cached;
  final String? model;

  /// 这一轮放进上下文的篇数；“继续聊聊”带进来的回应等没有检索过的为 null。
  final int? contextEntries;

  /// 智能体没有正常作答的原因（步数用完 / 响应被截断）。
  final String? agentEnd;

  /// 这一轮用的思考强度（自动时不记）与最后一段的思考时长。
  final AiThinkingLevel? thinking;
  final int? thinkingMs;
}
