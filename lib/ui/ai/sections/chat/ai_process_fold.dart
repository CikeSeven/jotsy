// 思考过程折叠块（DESIGN §5.29“思考过程”）：思考、过渡句、只读与失败的
// 工具调用折在一起，只露一枚摘要胶囊。
//
// - 收起：18 圆角胶囊（输入框底色）：左侧 `brain` 14（进行中换加载指示 16）
//   + 摘要 + `angleDown`（展开时旋转）。结束后摘要为“思考了 8 秒 · 调用了
//   3 个工具”，有失败时追加 error 色“1 个未成功”；进行中写当前动作：正在
//   准备的工具、正在执行的工具标题；在思考时，还没调用过工具写“正在思考 ·
//   5 秒”，调用过之后写这一块的累计“思考了 12 秒 · 调用了 3 个工具”（秒数
//   为合并进这一块的各轮思考之和，逐秒刷新）。
// - 展开（`AnimatedSize`，medium + effects）：胶囊下一张 18 圆角的卡，左侧
//   1.5dp `outlineVariant` 竖线串起 24dp 圆形徽标——思考 `lightbulb`、过渡句
//   `quoteLeft`（中性灰）、工具为领域色（失败为 errorContainer）；工具行点按
//   再展开可读详情（`AiToolDetailsView`）。
// - 状态：默认收起；用户展开过就保持（State 挂在调用方给的 key 上）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../widgets/expressive_loading_indicator.dart';
import '../../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../controllers/ai_thinking_clock.dart';
import '../../models/ai_agent_steps.dart';
import '../../tools/ai_destinations.dart';
import '../../tools/ai_tool_registry.dart';
import '../../viewmodels/ai_answer_segments.dart';
import '../../widgets/ai_markdown_view.dart';
import '../../widgets/ai_tint_badge.dart';
import '../../widgets/ai_view_state.dart';
import 'ai_answer_actions.dart';
import 'ai_subject_chips.dart';
import 'ai_tool_details_view.dart';

class AiProcessFold extends StatefulWidget {
  const AiProcessFold({
    super.key,
    required this.segment,
    required this.actions,
    this.live = false,
    this.clock,
    this.status,
    this.storageId,
  });

  final AiProcessSegment segment;
  final AiAnswerActions actions;

  /// 这一块正在进行（进行中一轮的最后一个折叠块）。
  final bool live;

  /// 进行中这一步的思考计时（“正在思考 · N 秒”）。
  final AiThinkingClock? clock;

  /// 进行中的固定状态（检索问答的“正在查找相关的日记…”），优先显示。
  final String? status;

  /// 展开状态在对话存储桶里的标识（`aiReadExpanded`），也是里面工具行的
  /// 前缀；进行中的一轮为 null（不记）。
  final String? storageId;

  @override
  State<AiProcessFold> createState() => _AiProcessFoldState();
}

class _AiProcessFoldState extends State<AiProcessFold> {
  late bool _expanded = aiReadExpanded(context, widget.storageId);
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(AiProcessFold oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  /// 正在思考时每秒刷新一次摘要里的秒数；不思考了就停。
  void _syncTicker() {
    final running = widget.live && (widget.clock?.running ?? false);
    if (running && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (!(widget.live && (widget.clock?.running ?? false))) {
          _ticker?.cancel();
          _ticker = null;
        }
      });
    } else if (!running) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// 这个折叠块到此刻为止的思考总时长（毫秒）：各步已经记下的时长，加上
  /// 这一步计时器的最新读数。分段时记下的“这一步”那部分（`liveThinkingMs`）
  /// 换成计时器现在的值；一步刚收尾、计时器已清零而分段还没重建的那一瞬
  /// 不让数字往回跳。
  int _thinkingMs() {
    final segment = widget.segment;
    final clock = widget.clock;
    if (!widget.live || clock == null) return segment.thinkingMs;
    final current =
        segment.thinkingMs - segment.liveThinkingMs + clock.elapsedMs;
    return current > segment.thinkingMs ? current : segment.thinkingMs;
  }

  /// 进行中的摘要。
  ///
  /// - 检索问答的固定状态优先；
  /// - 模型正在准备、正在执行某个工具时写那个动作（用户要知道它在做什么）；
  /// - 其余（在思考、等下一步）：还没调用过工具时写“正在思考 · N 秒”；
  ///   已经调用过工具时写这个折叠块的累计——“思考了 N 秒 · 调用了 N 个
  ///   工具”，秒数是合并进这一块的各轮思考之和（不是最近这一轮的），与
  ///   结束后的摘要同一口径，连续多轮时数字只增不减。
  (String, String?) _liveSummary(AppLocalizations l10n) {
    if (widget.status case final status?) return (status, null);
    final segment = widget.segment;
    final last = segment.items.lastOrNull;
    if (last is AiPreparingItem) {
      final tool = aiToolByName(last.tool);
      return (
        tool == null
            ? l10n.aiAgentPreparing
            : tool.label(l10n, const <String, Object?>{}),
        null,
      );
    }
    if (last is AiToolItem && !last.call.status.finished) {
      final tool = aiToolByName(last.call.tool);
      return (
        tool?.labelWith(l10n, last.call.args, last.call.subjects) ??
            last.call.tool,
        null,
      );
    }
    final seconds = _thinkingMs() ~/ 1000;
    if (segment.toolCount == 0) {
      return (
        seconds >= 1
            ? l10n.aiProcessThinkingFor(seconds)
            : l10n.aiPanelThinking,
        null,
      );
    }
    final failed = segment.failedCount;
    return (
      <String>[
        if (seconds >= 1)
          l10n.aiProcessThoughtFor(seconds)
        else if (segment.thought)
          l10n.aiProcessThought,
        l10n.aiProcessTools(segment.toolCount),
      ].join(' · '),
      failed > 0 ? l10n.aiProcessFailed(failed) : null,
    );
  }

  /// 结束后的摘要：思考时长、调用个数，失败另起一段（error 色）。
  (String, String?) _summary(AppLocalizations l10n) {
    final segment = widget.segment;
    final parts = <String>[
      if (segment.thinkingMs >= 1000)
        l10n.aiProcessThoughtFor((segment.thinkingMs / 1000).round())
      else if (segment.thought)
        l10n.aiProcessThought,
      if (segment.toolCount > 0) l10n.aiProcessTools(segment.toolCount),
    ];
    final failed = segment.failedCount;
    return (
      parts.isEmpty ? l10n.aiProcessSteps : parts.join(' · '),
      failed > 0 ? l10n.aiProcessFailed(failed) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final glass = AppGlassField.of(context);
    final fill = glass?.fill ?? colors.surfaceContainerHigh;
    final live = widget.live;
    final (summary, failed) = live ? _liveSummary(l10n) : _summary(l10n);
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final canExpand = widget.segment.items.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Material(
          color: fill,
          shape: StadiumBorder(side: glass?.border ?? BorderSide.none),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: canExpand
                ? () {
                    setState(() => _expanded = !_expanded);
                    aiWriteExpanded(context, widget.storageId, _expanded);
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox.square(
                    dimension: 16,
                    child: live
                        ? const ExpressiveLoadingIndicator(size: 16)
                        : Center(
                            child: FaIcon(
                              FontAwesomeIcons.brain,
                              size: 13,
                              color: colors.primary,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: ExpressiveMotion.duration(
                        context,
                        ExpressiveMotion.fast,
                      ),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: AlignmentDirectional.centerStart,
                        children: <Widget>[...previous, ?current],
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(text: summary),
                            if (failed != null)
                              TextSpan(
                                text: ' · $failed',
                                style: TextStyle(color: colors.error),
                              ),
                          ],
                        ),
                        key: ValueKey<String>('$summary$failed'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      ),
                    ),
                  ),
                  if (canExpand) ...<Widget>[
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: ExpressiveMotion.duration(
                        context,
                        ExpressiveMotion.fast,
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.angleDown,
                        size: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
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
          child: !_expanded || !canExpand
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(18),
                      border: glass?.border == null
                          ? null
                          : Border.fromBorderSide(glass!.border!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 14, 4),
                      child: _Timeline(
                        items: widget.segment.items,
                        live: live,
                        actions: widget.actions,
                        storageId: widget.storageId,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// 展开后的时间线：竖线画在徽标后面，徽标的实底盖住它。
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.items,
    required this.live,
    required this.actions,
    this.storageId,
  });

  final List<AiProcessItem> items;
  final bool live;
  final AiAnswerActions actions;
  final String? storageId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: <Widget>[
        if (items.length > 1)
          PositionedDirectional(
            start: 11.25,
            top: 14,
            bottom: 22,
            child: ColoredBox(
              color: colors.outlineVariant,
              child: const SizedBox(width: 1.5),
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (index, item) in items.indexed)
              switch (item) {
                AiThoughtItem(:final text) => _TextItem(
                  key: ValueKey<String>('thought-$index'),
                  icon: FontAwesomeIcons.lightbulb,
                  child: _ThoughtText(text: text),
                ),
                AiNarrationItem(:final text) => _TextItem(
                  key: ValueKey<String>('narration-$index'),
                  icon: FontAwesomeIcons.quoteLeft,
                  child: AiMarkdownView(
                    markdown: text,
                    onCitation: actions.onCitation,
                    bodyStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
                AiToolItem(:final call) => _ToolItem(
                  key: ValueKey<String>('tool-${call.id}'),
                  call: call,
                  live: live,
                  actions: actions,
                  storageId: storageId == null
                      ? null
                      : '$storageId:tool:${call.id}',
                ),
                AiPreparingItem(:final tool) => _PreparingItem(
                  key: ValueKey<String>('preparing-$index'),
                  tool: tool,
                ),
              },
          ],
        ),
      ],
    );
  }
}

/// 时间线的一行：左侧 24dp 徽标，右侧内容。
class _Row extends StatelessWidget {
  const _Row({required this.badge, required this.child});

  final Widget badge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          badge,
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextItem extends StatelessWidget {
  const _TextItem({super.key, required this.icon, required this.child});

  final FaIconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Row(
      badge: AiTintBadge(
        icon: icon,
        tint: AiTint.neutral,
        size: 24,
        circle: true,
      ),
      // 思考与过渡句同样可以长按选字。
      child: AppSelectionArea(child: child),
    );
  }
}

/// 思考文字：灰色小字，超过 6 行先收起，点按展开。
class _ThoughtText extends StatefulWidget {
  const _ThoughtText({required this.text});

  final String text;

  @override
  State<_ThoughtText> createState() => _ThoughtTextState();
}

class _ThoughtTextState extends State<_ThoughtText> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _all = !_all),
      child: AnimatedSize(
        duration: ExpressiveMotion.durationNonZero(
          context,
          ExpressiveMotion.medium,
        ),
        curve: ExpressiveMotion.effects,
        alignment: Alignment.topLeft,
        child: Text(
          widget.text,
          maxLines: _all ? null : 6,
          overflow: _all ? null : TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.55,
          ),
        ),
      ),
    );
  }
}

class _ToolItem extends StatefulWidget {
  const _ToolItem({
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
  State<_ToolItem> createState() => _ToolItemState();
}

class _ToolItemState extends State<_ToolItem> {
  late bool _details = aiReadExpanded(context, widget.storageId);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final call = widget.call;
    final tool = aiToolByName(call.tool);
    final running = widget.live && !call.status.finished;
    final failed = call.status == AiToolCallStatus.failed;
    final stopped =
        !running &&
        (call.status == AiToolCallStatus.cancelled ||
            call.status == AiToolCallStatus.executing);
    final note = failed
        ? (call.summary ?? l10n.aiAgentStepFailed)
        : stopped
        ? (call.status == AiToolCallStatus.cancelled
              ? l10n.aiAgentStepCancelled
              : l10n.aiAgentStepInterrupted)
        : call.summary;
    final results = [
      for (final subject in call.subjects)
        if (!subject.input) subject,
    ];
    final expandable = AiToolDetailsView.hasDetails(l10n, call);
    return _Row(
      badge: AiTintBadge(
        icon: failed
            ? FontAwesomeIcons.circleExclamation
            : aiGroupIcon(tool?.group),
        tint: aiGroupTint(tool?.group),
        size: 24,
        circle: true,
        danger: failed,
        muted: stopped,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: expandable
                ? () {
                    setState(() => _details = !_details);
                    aiWriteExpanded(context, widget.storageId, _details);
                  }
                : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        tool?.labelWith(l10n, call.args, call.subjects) ??
                            call.tool,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (note != null && note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            note,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: failed
                                  ? colors.error
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (running)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: ExpressiveLoadingIndicator(size: 14),
                  )
                else if (expandable)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AnimatedRotation(
                      turns: _details ? 0.25 : 0,
                      duration: ExpressiveMotion.duration(
                        context,
                        ExpressiveMotion.fast,
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.angleRight,
                        size: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!_details && results.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            AiSubjectChips(
              subjects: results,
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
                    padding: const EdgeInsets.only(top: 8),
                    child: AiToolDetailsView(
                      call: call,
                      onOpenSubject: widget.actions.onOpenSubject,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PreparingItem extends StatelessWidget {
  const _PreparingItem({super.key, required this.tool});

  final String tool;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final known = aiToolByName(tool);
    return _Row(
      badge: const SizedBox.square(
        dimension: 24,
        child: Center(child: ExpressiveLoadingIndicator(size: 16)),
      ),
      child: Text(
        known == null
            ? l10n.aiAgentPreparing
            : known.label(l10n, const <String, Object?>{}),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
