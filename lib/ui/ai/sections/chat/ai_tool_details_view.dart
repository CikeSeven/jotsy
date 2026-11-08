// 一个工具调用的可读详情（点工具行展开，替代以前的 JSON）：
//
// - 条件：`aiToolFacts` 给出的“标签 — 值”，标签 72 宽的灰字列 + 值；长文本
//   为左侧 2dp 竖线的引用块（最多 4 行，点按展开全文）；颜色参数在值前画
//   12dp 色块；
// - 结果：结果说明 + 结果对象胶囊（参数指向的对象已写进条件，不重复）；
// - 失败：error 色的友好说明，下面可展开的“技术信息”（回传模型的原始英文
//   错误，等宽小字，可选中）。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../models/ai_agent_steps.dart';
import '../../models/ai_tool_subject.dart';
import '../../viewmodels/ai_tool_facts.dart';
import 'ai_subject_chips.dart';

class AiToolDetailsView extends StatelessWidget {
  const AiToolDetailsView({
    super.key,
    required this.call,
    required this.onOpenSubject,
  });

  final AiAgentCallRecord call;
  final ValueChanged<AiToolSubject> onOpenSubject;

  /// 这次调用有没有可以展开的详情。
  static bool hasDetails(AppLocalizations l10n, AiAgentCallRecord call) =>
      call.error != null ||
      call.subjects.isNotEmpty ||
      aiToolFacts(l10n, call).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final facts = aiToolFacts(l10n, call);
    final results = [
      for (final subject in call.subjects)
        if (!subject.input) subject,
    ];
    final failed = call.status == AiToolCallStatus.failed;
    final heading = theme.textTheme.labelMedium?.copyWith(
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (facts.isNotEmpty) ...<Widget>[
          Text(l10n.aiToolDetailsInputs, style: heading),
          const SizedBox(height: 6),
          for (final fact in facts) _FactRow(fact: fact),
        ],
        if (!failed && (results.isNotEmpty || call.moreSubjects > 0)) ...[
          if (facts.isNotEmpty) const SizedBox(height: 8),
          Text(l10n.aiToolDetailsResult, style: heading),
          const SizedBox(height: 6),
          AiSubjectChips(
            subjects: results,
            more: call.moreSubjects,
            onOpen: onOpenSubject,
          ),
        ],
        if (failed) ...<Widget>[
          if (facts.isNotEmpty) const SizedBox(height: 8),
          Text(
            call.summary ?? l10n.aiToolDetailsFailed,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
          ),
          if (call.error case final error?) _TechnicalInfo(text: error),
        ],
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.fact});

  final AiToolFact fact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurface,
      height: 1.45,
    );
    if (fact.long) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(fact.label, style: labelStyle),
            const SizedBox(height: 4),
            _QuoteBlock(text: fact.value, style: valueStyle),
          ],
        ),
      );
    }
    final swatch = fact.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 76, child: Text(fact.label, style: labelStyle)),
          if (swatch != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // 用户（经 AI）给的颜色值，属于数据而不是界面配色。
                  color: Color(swatch),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outlineVariant, width: 0.8),
                ),
                child: const SizedBox.square(dimension: 12),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(fact.value, style: valueStyle)),
        ],
      ),
    );
  }
}

/// 长文本：左侧竖线的引用块，先收起到 4 行，点按展开全文。
class _QuoteBlock extends StatefulWidget {
  const _QuoteBlock({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  State<_QuoteBlock> createState() => _QuoteBlockState();
}

class _QuoteBlockState extends State<_QuoteBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: colors.outlineVariant, width: 2),
          ),
        ),
        child: AnimatedSize(
          duration: ExpressiveMotion.durationNonZero(
            context,
            ExpressiveMotion.medium,
          ),
          curve: ExpressiveMotion.effects,
          alignment: Alignment.topLeft,
          child: Text(
            widget.text.trim(),
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: widget.style,
          ),
        ),
      ),
    );
  }
}

/// 失败时的“技术信息”：默认收起，展开为可选中的等宽小字。
class _TechnicalInfo extends StatefulWidget {
  const _TechnicalInfo({required this.text});

  final String text;

  @override
  State<_TechnicalInfo> createState() => _TechnicalInfoState();
}

class _TechnicalInfoState extends State<_TechnicalInfo> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  context.l10n.aiToolDetailsTechnical,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: ExpressiveMotion.duration(
                    context,
                    ExpressiveMotion.fast,
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.angleDown,
                    size: 9,
                    color: colors.onSurfaceVariant,
                  ),
                ),
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
          child: !_open
              ? const SizedBox(width: double.infinity)
              : SelectableText(
                  widget.text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                  contextMenuBuilder: appTextContextMenuBuilder,
                ),
        ),
      ],
    );
  }
}
