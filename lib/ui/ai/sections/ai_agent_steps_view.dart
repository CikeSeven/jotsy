// 智能体回答里的工具步骤（DESIGN §5.29“智能体步骤”）。
//
// 按顺序：每一步先是模型调用工具前说的话（Markdown），再是这一步的调用组
// ——一张 `AppGlassField` 底色、14 圆角的卡片，每个调用一行：16dp 领域图标 +
// 标题 + 行尾状态（进行中为加载指示，成功 / 失败 / 已停止 / 已中断各有图标），
// 下面一行结果说明；点按以 `AnimatedSize` 展开参数与错误原因。跳转类调用在
// 行下放“前往 某页面”色调按钮。一组超过 3 个调用且不在进行中时默认收起成
// “执行了 N 个操作”。
//
// 状态口径：落库的 executing 在不进行中的消息里按“已中断”显示（绝不重放）。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../models/ai_agent_steps.dart';
import '../tools/ai_destinations.dart';
import '../tools/ai_tool.dart';
import '../tools/ai_tool_registry.dart';
import 'ai_chat_message_view.dart';

class AiAgentStepsView extends StatelessWidget {
  const AiAgentStepsView({
    super.key,
    required this.steps,
    required this.live,
    required this.showReasoning,
    required this.onCitation,
    required this.onOpen,
  });

  final List<AiAgentStepRecord> steps;

  /// 这一轮还在进行：executing 显示为进行中，否则为已中断。
  final bool live;
  final bool showReasoning;
  final ValueChanged<String> onCitation;
  final ValueChanged<AiToolNavigation> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final step in steps) ...<Widget>[
          if (step.text.trim().isNotEmpty ||
              (showReasoning && step.reasoning.trim().isNotEmpty))
            AiChatAnswerBody(
              text: step.text,
              reasoning: showReasoning ? step.reasoning : '',
              onCitation: onCitation,
            ),
          if (step.calls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _CallGroup(calls: step.calls, live: live, onOpen: onOpen),
            ),
        ],
      ],
    );
  }
}

/// 模型正在准备某个工具调用时的一行提示（还没有参数）。
class AiAgentPreparingRow extends StatelessWidget {
  const AiAgentPreparingRow({super.key, required this.tool});

  final String tool;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final known = aiToolByName(tool);
    return Row(
      children: <Widget>[
        const ExpressiveLoadingIndicator(size: 18),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            known == null
                ? l10n.aiAgentPreparing
                : known.label(l10n, const <String, Object?>{}),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _CallGroup extends StatefulWidget {
  const _CallGroup({
    required this.calls,
    required this.live,
    required this.onOpen,
  });

  final List<AiAgentCallRecord> calls;
  final bool live;
  final ValueChanged<AiToolNavigation> onOpen;

  @override
  State<_CallGroup> createState() => _CallGroupState();
}

class _CallGroupState extends State<_CallGroup> {
  late bool _expanded = widget.live || widget.calls.length <= 3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fill = AppGlassField.of(context)?.fill ?? colors.surfaceContainerHigh;
    final expanded = _expanded || widget.live;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: AnimatedSize(
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
        curve: ExpressiveMotion.effects,
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (!expanded)
                _GroupHeader(
                  label: l10n.aiAgentStepsSummary(widget.calls.length),
                  onTap: () => setState(() => _expanded = true),
                )
              else
                for (final call in widget.calls)
                  _CallRow(
                    key: ValueKey<String>(call.id),
                    call: call,
                    live: widget.live,
                    onOpen: widget.onOpen,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: <Widget>[
            FaIcon(
              FontAwesomeIcons.screwdriverWrench,
              size: 14,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            FaIcon(
              FontAwesomeIcons.angleDown,
              size: 14,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _CallRow extends StatefulWidget {
  const _CallRow({
    super.key,
    required this.call,
    required this.live,
    required this.onOpen,
  });

  final AiAgentCallRecord call;
  final bool live;
  final ValueChanged<AiToolNavigation> onOpen;

  @override
  State<_CallRow> createState() => _CallRowState();
}

class _CallRowState extends State<_CallRow> {
  bool _details = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final call = widget.call;
    final tool = aiToolByName(call.tool);
    final label = tool?.label(l10n, call.args) ?? call.tool;
    final running = !call.status.finished && widget.live;
    final (statusIcon, statusColor, statusText) = switch (call.status) {
      AiToolCallStatus.succeeded => (
        FontAwesomeIcons.check,
        colors.primary,
        null,
      ),
      AiToolCallStatus.failed => (
        FontAwesomeIcons.circleExclamation,
        colors.error,
        l10n.aiAgentStepFailed,
      ),
      AiToolCallStatus.rejected || AiToolCallStatus.cancelled => (
        FontAwesomeIcons.ban,
        colors.onSurfaceVariant,
        l10n.aiAgentStepCancelled,
      ),
      _ => (
        FontAwesomeIcons.circleHalfStroke,
        colors.onSurfaceVariant,
        l10n.aiAgentStepInterrupted,
      ),
    };
    final note = call.summary ?? statusText;
    final navigation = call.navigation;
    final destination = navigation == null
        ? null
        : aiDestinationById(navigation.destination);
    final details = <String>[
      if (call.args.isNotEmpty)
        const JsonEncoder.withIndent('  ').convert(call.args),
      ?call.error,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: details.isEmpty
              ? null
              : () => setState(() => _details = !_details),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SizedBox(
                    width: 20,
                    child: FaIcon(
                      _groupIcon(tool?.group),
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: theme.textTheme.bodyMedium,
                        maxLines: _details ? null : 2,
                        overflow: _details ? null : TextOverflow.ellipsis,
                      ),
                      if (!running && note != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            note,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: call.status == AiToolCallStatus.failed
                                  ? colors.error
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: running
                      ? const ExpressiveLoadingIndicator(size: 14)
                      : FaIcon(statusIcon, size: 14, color: statusColor),
                ),
              ],
            ),
          ),
        ),
        if (_details && details.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(42, 0, 14, 8),
            child: SelectableText(
              details.join('\n\n'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: colors.onSurfaceVariant,
              ),
              contextMenuBuilder: appTextContextMenuBuilder,
            ),
          ),
        if (destination != null && call.status == AiToolCallStatus.succeeded)
          Padding(
            padding: const EdgeInsets.fromLTRB(42, 0, 14, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                style: AppGlassField.tonalButtonStyle(context),
                onPressed: () => widget.onOpen(navigation!),
                icon: const FaIcon(FontAwesomeIcons.arrowRight, size: 14),
                label: Text(l10n.aiAgentOpenPage(destination.title(l10n))),
              ),
            ),
          ),
      ],
    );
  }

  static FaIconData _groupIcon(AiToolGroup? group) => switch (group) {
    AiToolGroup.app => FontAwesomeIcons.circleInfo,
    AiToolGroup.diaries => FontAwesomeIcons.bookOpen,
    AiToolGroup.organize => FontAwesomeIcons.tags,
    AiToolGroup.calendar => FontAwesomeIcons.calendarDays,
    AiToolGroup.navigation => FontAwesomeIcons.arrowUpRightFromSquare,
    null => FontAwesomeIcons.screwdriverWrench,
  };
}
