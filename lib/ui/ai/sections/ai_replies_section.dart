// 预览页正文末尾的“AI 回应”区（DESIGN.md §5.29），在留言区之后。
//
// 内容：标题“AI 回应 · N”、已保存的回应（人设头像与名称、时间、Markdown
// 正文，长的先收起）、进行中的回应（流式文字，可停止；失败给原因与重试）、
// 末尾一行“＋ 让 AI 回应…”（先选人设）。每条回应的 ⋮ 菜单：复制、重新
// 生成、存为留言（留言功能开着时）、删除（可撤销）。
//
// 数据：已保存的经 `aiRepliesProvider`，进行中的经 `aiReplyJobsProvider`
// （常驻，离开页面再回来进度还在）。分享长图期间由调用方不显示本区。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/providers/diary_comments_provider.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../../widgets/expressive_menu/expressive_menu_button.dart';
import '../../widgets/expressive_menu/expressive_menu_item.dart';
import '../controllers/ai_reply_flow.dart';
import '../controllers/ai_stream_run.dart';
import '../models/ai_built_ins.dart';
import '../models/ai_preference_parts.dart';
import '../pages/settings/ai_personas_page.dart';
import '../providers/ai_providers.dart';
import '../providers/ai_records_providers.dart';
import '../widgets/ai_error_view.dart';
import '../widgets/ai_markdown_view.dart';
import '../widgets/ai_persona_avatar.dart';

class AiRepliesSection extends ConsumerWidget {
  const AiRepliesSection({
    super.key,
    required this.diaryId,
    required this.textColor,
    this.onContinueChat,
  });

  final String diaryId;

  /// 预览页样式的正文色。
  final Color textColor;

  /// “继续聊聊”：以这篇为固定上下文、接着这条回应打开对话；对话模块关闭
  /// 时为 null。
  final ValueChanged<AiResultRow>? onContinueChat;

  Future<void> _ask(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final prefs = ref.read(aiPreferencesProvider);
    final picked = await showAiPersonaPicker(
      context,
      personas: aiPersonas(l10n, prefs),
      selectedId: aiPersonaFor(l10n, prefs, AiPersonaUse.reply).id,
      title: l10n.aiReplyPickPersona,
    );
    if (picked == null || !context.mounted) return;
    await requestAiReply(context, ref, diaryId: diaryId, personaId: picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rows = ref.watch(aiRepliesProvider(diaryId)).value ?? const [];
    final job = ref.watch(aiReplyJobsProvider.select((jobs) => jobs[diaryId]));
    final count = rows.length;
    return AnimatedSize(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.effects,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (count > 0 || job != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l10n.aiRepliesHeading(count),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          for (final row in rows)
            _ReplyCard(
              key: ValueKey<String>(row.resultId),
              row: row,
              textColor: textColor,
              onRegenerate: () => unawaited(
                requestAiReply(
                  context,
                  ref,
                  diaryId: diaryId,
                  personaId: row.personaId,
                ),
              ),
              onContinueChat: onContinueChat,
            ),
          if (job != null) _JobCard(job: job, textColor: textColor),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: job?.run.running ?? false ? null : () => _ask(context, ref),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 36,
                    child: FaIcon(
                      FontAwesomeIcons.wandMagicSparkles,
                      size: 14,
                      color: colors.primary,
                    ),
                  ),
                  Text(
                    l10n.aiReplyAsk,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.emoji,
    required this.name,
    required this.textColor,
    this.time,
    this.trailing,
  });

  final String emoji;
  final String name;
  final Color textColor;
  final String? time;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        AiPersonaAvatar(emoji: emoji, size: 28),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (time != null) ...<Widget>[
          const SizedBox(width: 8),
          Text(
            time!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor.withValues(alpha: 0.6),
            ),
          ),
        ],
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class _ReplyCard extends ConsumerStatefulWidget {
  const _ReplyCard({
    super.key,
    required this.row,
    required this.textColor,
    required this.onRegenerate,
    this.onContinueChat,
  });

  final AiResultRow row;
  final Color textColor;
  final VoidCallback onRegenerate;
  final ValueChanged<AiResultRow>? onContinueChat;

  @override
  ConsumerState<_ReplyCard> createState() => _ReplyCardState();
}

class _ReplyCardState extends ConsumerState<_ReplyCard> {
  /// 超过这么多字先收起（按字符粗估，回应通常几百字）。
  static const int _foldChars = 360;
  static const double _foldHeight = 180;

  bool _expanded = false;

  Future<void> _saveAsComment() async {
    final l10n = context.l10n;
    final text = widget.row.content.trim();
    final content = text.length > kDiaryCommentMaxLength
        ? text.substring(0, kDiaryCommentMaxLength)
        : text;
    await ref
        .read(appDatabaseProvider)
        .addDiaryComment(diaryId: widget.row.diaryId!, content: content);
    if (!mounted) return;
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(l10n.aiReplySavedAsComment)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final row = widget.row;
    final prefs = ref.watch(aiPreferencesProvider);
    final persona = aiReplyPersonaOf(l10n, prefs, row);
    final comments = ref.watch(diaryCommentsEnabledProvider);
    final long = row.content.length > _foldChars;
    final body = theme.textTheme.bodyMedium?.copyWith(
      color: widget.textColor,
      height: 1.6,
    );
    final markdown = AiMarkdownView(markdown: row.content, bodyStyle: body);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Header(
            emoji: persona.emoji,
            name: persona.name,
            textColor: widget.textColor,
            time: l10n.formatDateTimeMinute(row.createdAt),
            trailing: ExpressiveMenuButton(
              tooltip: persona.name,
              icon: FaIcon(
                FontAwesomeIcons.ellipsis,
                size: 14,
                color: widget.textColor.withValues(alpha: 0.6),
              ),
              items: <Widget>[
                ExpressiveMenuItem(
                  leadingIcon: const FaIcon(FontAwesomeIcons.copy),
                  onPressed: () => unawaited(
                    Clipboard.setData(ClipboardData(text: row.content)),
                  ),
                  child: Text(l10n.aiPanelCopy),
                ),
                ExpressiveMenuItem(
                  leadingIcon: const FaIcon(FontAwesomeIcons.arrowsRotate),
                  onPressed: widget.onRegenerate,
                  child: Text(l10n.aiReplyRegenerate),
                ),
                if (comments && row.diaryId != null)
                  ExpressiveMenuItem(
                    leadingIcon: const FaIcon(FontAwesomeIcons.comment),
                    onPressed: () => unawaited(_saveAsComment()),
                    child: Text(l10n.aiReplySaveAsComment),
                  ),
                ExpressiveMenuItem(
                  leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
                  destructive: true,
                  onPressed: () => unawaited(deleteAiReply(context, ref, row)),
                  child: Text(l10n.commonDelete),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (long && !_expanded)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: _foldHeight),
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        maxHeight: double.infinity,
                        child: markdown,
                      ),
                    ),
                  )
                else
                  markdown,
                Wrap(
                  spacing: 4,
                  children: <Widget>[
                    if (long)
                      TextButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        child: Text(
                          _expanded ? l10n.aiReplyCollapse : l10n.aiReplyExpand,
                        ),
                      ),
                    if (widget.onContinueChat != null)
                      TextButton.icon(
                        onPressed: () => widget.onContinueChat!(widget.row),
                        icon: const FaIcon(FontAwesomeIcons.comments, size: 12),
                        label: Text(l10n.aiReplyContinueChat),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.primary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.job, required this.textColor});

  final AiReplyJob job;
  final Color textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium?.copyWith(
      color: textColor,
      height: 1.6,
    );
    final jobs = ref.read(aiReplyJobsProvider.notifier);
    void retry() {
      jobs.dismiss(job.diaryId);
      unawaited(
        requestAiReply(
          context,
          ref,
          diaryId: job.diaryId,
          personaId: job.persona.id,
        ),
      );
    }

    return ListenableBuilder(
      listenable: job.run,
      builder: (BuildContext context, Widget? child) {
        final run = job.run;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Header(
                emoji: job.persona.emoji,
                name: job.persona.name,
                textColor: textColor,
                trailing: run.running
                    ? TextButton(
                        onPressed: () => jobs.stop(job.diaryId),
                        child: Text(l10n.aiPanelStop),
                      )
                    : TextButton(
                        onPressed: () => jobs.dismiss(job.diaryId),
                        child: Text(l10n.aiReplyDismiss),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 36, top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (run.hasText)
                      AiMarkdownView(
                        markdown: aiCleanOutput(run.text),
                        bodyStyle: body,
                      )
                    else if (run.running)
                      Row(
                        children: <Widget>[
                          const ExpressiveLoadingIndicator(size: 20),
                          const SizedBox(width: 10),
                          Text(
                            l10n.aiReplyWriting,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: textColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    if (run.status == AiRunStatus.failed && run.error != null)
                      AiErrorView(error: run.error!, onRetry: retry),
                    if (run.status == AiRunStatus.stopped)
                      TextButton(
                        onPressed: retry,
                        child: Text(l10n.aiReplyStopped),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
