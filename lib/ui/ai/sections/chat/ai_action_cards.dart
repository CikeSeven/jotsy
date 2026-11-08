// 回答里露在外面的卡片（DESIGN §5.29“卡片”）：前往、改动、确认。
//
// 三种卡片同一外壳 [_CardShell]：20 圆角，`AppGlassField` 底与描边（经典为
// `surfaceContainerLow` + 0.8dp `outlineVariant`），左侧 40–44dp 领域色徽标
// 带出色彩，文字只用主题语义色。
//
// - 前往：整卡可点。标题是具体名称——日记标题（无标题用日期）、日记本名、
//   待办标题、“搜索「…」”、页面名；名称渲染时实时读（改名后跟着变，旧
//   记录也能显示），读不到时用执行时记下的名称；目标已删除 / 功能已关闭时
//   副标题写明、箭头禁用、徽标转灰。副标题为类别与要点（“日记 · 11月3日
//   周一”“日记本 · 23 篇”“待办 · 11月9日截止”“设置 › 外观”）。
// - 改动：一组相邻的改动一张卡；多于一项时卡头写“做了 N 项改动”与“全部
//   撤销”。每行：领域色徽标 + 具体标题 + 结果说明 + 对象胶囊 + 行尾“撤销”
//   （已撤销的行降为灰色、徽标换 `rotateLeft`），点行展开可读详情。
// - 确认：删除类为低不透明度的 errorContainer 底 + error 描边，其余为
//   primaryContainer 底；要点逐行，右下灰色“取消”与填充按钮“删除 / 执行”。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../diaries/providers/diary_link_providers.dart';
import '../../../notebooks/providers/notebook_providers.dart';
import '../../../settings/providers/app_features_provider.dart';
import '../../../todos/providers/todo_providers.dart';
import '../../../widgets/expressive_loading_indicator.dart';
import '../../models/ai_agent_steps.dart';
import '../../providers/ai_providers.dart';
import '../../tools/ai_destinations.dart';
import '../../tools/ai_tool.dart';
import '../../tools/ai_tool_registry.dart';
import '../../viewmodels/ai_tool_facts.dart';
import '../../widgets/ai_tint_badge.dart';
import '../../widgets/ai_view_state.dart';
import 'ai_answer_actions.dart';
import 'ai_subject_chips.dart';
import 'ai_tool_details_view.dart';

/// 三种卡片共用的外壳。
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.color, this.side, this.onTap});

  final Widget child;
  final Color? color;
  final BorderSide? side;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final glass = AppGlassField.of(context);
    return Material(
      color: color ?? glass?.fill ?? colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side:
            side ??
            glass?.border ??
            BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.6),
              width: 0.8,
            ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? child : InkWell(onTap: onTap, child: child),
    );
  }
}

// ---------------------------------------------------------------- 前往

class AiDestinationCard extends ConsumerWidget {
  const AiDestinationCard({
    super.key,
    required this.call,
    required this.actions,
  });

  final AiAgentCallRecord call;
  final AiAnswerActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final navigation = call.navigation!;
    final destination = aiDestinationById(navigation.destination);
    if (destination == null) return const SizedBox.shrink();
    final env = AiToolEnv(
      features: ref.watch(appFeaturesProvider),
      prefs: ref.watch(aiPreferencesProvider),
    );
    final target = _resolve(context, ref, destination, navigation);
    final available = destination.isAvailable(env) && !target.missing;
    final subtitle = !destination.isAvailable(env)
        ? l10n.aiCardFeatureOff
        : target.missing
        ? l10n.aiCardMissing
        : target.subtitle;
    return _CardShell(
      onTap: available ? () => actions.onOpenPage(navigation) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: <Widget>[
            AiTintBadge(
              icon: destination.icon,
              tint: destination.tint,
              size: 44,
              muted: !available,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    target.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: available ? null : colors.onSurfaceVariant,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: l10n.aiAgentOpenPage(target.title),
              style: AppGlassField.tonalButtonStyle(context),
              onPressed: available
                  ? () => actions.onOpenPage(navigation)
                  : null,
              icon: const FaIcon(FontAwesomeIcons.arrowRight, size: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// 卡片的标题与副标题：具体对象实时读，读不到用快照。
  _Target _resolve(
    BuildContext context,
    WidgetRef ref,
    AiDestination destination,
    AiToolNavigation navigation,
  ) {
    final l10n = context.l10n;
    final snapshot = call.subjects.firstOrNull;
    final page = destination.title(l10n);
    String kind(String key) => aiToolArgLabel(l10n, key);
    String param(String key) => '${navigation.params[key] ?? ''}';
    final dateFormat = DateFormat.MMMEd(l10n.localeName);
    switch (destination.kind) {
      case AiDestinationKind.diary:
        final live = ref.watch(diaryLinkDiaryProvider(param('diary_id')));
        final diary = live.value?.diary;
        final missing = live.hasValue && diary == null;
        final title = diary == null
            ? (snapshot == null ? page : aiSubjectName(l10n, snapshot))
            : (diary.title.trim().isEmpty
                  ? DateFormat.yMMMd(l10n.localeName).format(diary.createdAt)
                  : diary.title.trim());
        final date = diary?.createdAt ?? snapshot?.date;
        return _Target(
          title: title,
          subtitle: [
            kind('kind_diary'),
            if (date != null) dateFormat.format(date),
          ].join(' · '),
          missing: missing,
        );
      case AiDestinationKind.notebook:
        final id = param('notebook_id');
        final tree = ref.watch(notebookTreeProvider);
        final notebook = tree?[id];
        final int? count;
        if (notebook == null) {
          count = null;
        } else if (notebook.isSmart || notebook.hasChildren) {
          count = ref.watch(computedNotebookCountProvider(id)).value;
        } else {
          count = ref.watch(notebookEntryCountsProvider).value?[id] ?? 0;
        }
        return _Target(
          title: notebook?.name ?? snapshot?.title ?? page,
          subtitle: [
            kind('kind_notebook'),
            if (count != null) l10n.aiCardEntries(count),
          ].join(' · '),
          missing: tree != null && notebook == null,
        );
      case AiDestinationKind.todo:
        final live = ref.watch(todoProvider(param('todo_id')));
        final todo = live.value;
        final due = todo?.dueDate == null
            ? snapshot?.date
            : DateTime.tryParse(todo!.dueDate!);
        return _Target(
          title: todo?.title ?? snapshot?.title ?? page,
          subtitle: [
            kind('kind_todo'),
            if (todo?.completedAt != null)
              l10n.aiCardTodoDone
            else if (due != null)
              l10n.aiCardTodoDue(dateFormat.format(due)),
          ].join(' · '),
          missing: live.hasValue && todo == null,
        );
      case AiDestinationKind.search:
        final query = param('query').trim();
        return _Target(
          title: query.isEmpty ? page : l10n.aiCardSearchFor(query),
          subtitle: query.isEmpty ? '' : page,
        );
      case AiDestinationKind.tab || AiDestinationKind.page:
        return _Target(
          title: page,
          subtitle: switch (destination.section) {
            AiDestinationSection.home => l10n.aiCardSectionHome,
            AiDestinationSection.settings => l10n.navSettings,
            AiDestinationSection.none => '',
          },
        );
    }
  }
}

class _Target {
  const _Target({
    required this.title,
    required this.subtitle,
    this.missing = false,
  });

  final String title;
  final String subtitle;
  final bool missing;
}

// ---------------------------------------------------------------- 改动

class AiChangeGroupCard extends StatelessWidget {
  const AiChangeGroupCard({
    super.key,
    required this.calls,
    required this.live,
    required this.actions,
    this.storagePrefix,
  });

  final List<AiAgentCallRecord> calls;
  final bool live;
  final AiAnswerActions actions;

  /// 行展开状态在对话存储桶里的前缀（这条回答的 id）；进行中为 null。
  final String? storagePrefix;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final undo = actions.onUndo;
    final undoable = {
      for (final call in calls)
        if (call.canUndo) call.id,
    };
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (calls.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 2),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.aiChangeGroupTitle(calls.length),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (undo != null && undoable.length > 1)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => undo(undoable),
                        icon: const FaIcon(
                          FontAwesomeIcons.rotateLeft,
                          size: 12,
                        ),
                        label: Text(l10n.aiChangeUndoAll),
                      ),
                  ],
                ),
              ),
            for (final (index, call) in calls.indexed) ...<Widget>[
              if (index > 0)
                Divider(
                  height: 1,
                  indent: 66,
                  endIndent: 16,
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
              _ChangeRow(
                key: ValueKey<String>(call.id),
                call: call,
                live: live,
                actions: actions,
                storageId: storagePrefix == null
                    ? null
                    : '$storagePrefix:change:${call.id}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangeRow extends StatefulWidget {
  const _ChangeRow({
    super.key,
    required this.call,
    required this.live,
    required this.actions,
    this.storageId,
  });

  final AiAgentCallRecord call;
  final bool live;
  final AiAnswerActions actions;
  final String? storageId;

  @override
  State<_ChangeRow> createState() => _ChangeRowState();
}

class _ChangeRowState extends State<_ChangeRow> {
  late bool _details = aiReadExpanded(context, widget.storageId);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final call = widget.call;
    final tool = aiToolByName(call.tool);
    final running = widget.live && !call.status.finished;
    final declined =
        call.status == AiToolCallStatus.rejected ||
        call.status == AiToolCallStatus.cancelled ||
        (!running && call.status == AiToolCallStatus.executing);
    final muted = call.undone || declined;
    final note = call.undone
        ? l10n.aiAgentStepUndone
        : switch (call.status) {
            AiToolCallStatus.rejected ||
            AiToolCallStatus.cancelled => l10n.aiAgentStepCancelled,
            AiToolCallStatus.executing when !running =>
              l10n.aiAgentStepInterrupted,
            _ => call.summary,
          };
    final chips = [
      for (final subject in call.subjects)
        if (!subject.input) subject,
    ];
    final undo = widget.actions.onUndo;
    final expandable = AiToolDetailsView.hasDetails(l10n, call);
    return InkWell(
      onTap: expandable
          ? () {
              setState(() => _details = !_details);
              aiWriteExpanded(context, widget.storageId, _details);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AiTintBadge(
              icon: call.undone
                  ? FontAwesomeIcons.rotateLeft
                  : aiGroupIcon(tool?.group),
              tint: aiGroupTint(tool?.group),
              size: 40,
              muted: muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    tool?.labelWith(l10n, call.args, call.subjects) ??
                        call.tool,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: muted ? colors.onSurfaceVariant : null,
                    ),
                  ),
                  if (note != null && note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        note,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (!_details && chips.isNotEmpty && !muted) ...<Widget>[
                    const SizedBox(height: 8),
                    AiSubjectChips(
                      subjects: chips,
                      more: call.moreSubjects,
                      max: 3,
                      onOpen: widget.actions.onOpenSubject,
                    ),
                  ],
                  AnimatedSize(
                    duration: ExpressiveMotion.durationNonZero(
                      context,
                      ExpressiveMotion.medium,
                    ),
                    curve: ExpressiveMotion.effects,
                    alignment: Alignment.topLeft,
                    child: !_details
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: AiToolDetailsView(
                              call: call,
                              onOpenSubject: widget.actions.onOpenSubject,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (running)
              const Padding(
                padding: EdgeInsets.all(10),
                child: ExpressiveLoadingIndicator(size: 18),
              )
            else if (call.canUndo && undo != null)
              FilledButton.tonal(
                style:
                    AppGlassField.tonalButtonStyle(context)?.merge(
                      FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ) ??
                    FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                onPressed: () => undo({call.id}),
                child: Text(l10n.aiAgentUndo),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 确认

class AiConfirmCard extends StatelessWidget {
  const AiConfirmCard({super.key, required this.call, required this.actions});

  final AiAgentCallRecord call;
  final AiAnswerActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tool = aiToolByName(call.tool);
    final destructive = tool?.effect == AiToolEffect.destructive;
    final decide = actions.onDecide;
    final lines = call.preview?.lines ?? const <String>[];
    final accent = destructive ? colors.error : colors.primary;
    return _CardShell(
      color: (destructive ? colors.errorContainer : colors.primaryContainer)
          .withValues(alpha: 0.45),
      side: BorderSide(color: accent.withValues(alpha: 0.6), width: 1),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AiTintBadge(
                  icon: destructive
                      ? FontAwesomeIcons.trashCan
                      : FontAwesomeIcons.circleQuestion,
                  tint: AiTint.primary,
                  danger: destructive,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        destructive
                            ? l10n.aiAgentConfirmDelete
                            : l10n.aiAgentConfirmChange,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tool?.labelWith(l10n, call.args, call.subjects) ??
                            call.tool,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      for (final line in lines)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const SizedBox.square(dimension: 4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  line,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onSurfaceVariant,
                  ),
                  onPressed: decide == null
                      ? null
                      : () => decide(call.id, false),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: destructive
                        ? colors.onError
                        : colors.onPrimary,
                  ),
                  onPressed: decide == null
                      ? null
                      : () => decide(call.id, true),
                  child: Text(
                    destructive ? l10n.aiAgentDelete : l10n.aiAgentProceed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
