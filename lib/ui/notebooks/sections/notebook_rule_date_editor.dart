import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/expressive_choice_tile.dart';
import '../viewmodels/notebook_rule_labels.dart';
import 'notebook_rule_sheets.dart';

/// 日期规则的编辑面板：五种日期各一个单选项，选中项下方展开它自己的控件
/// （固定区间：日期范围选择器；最近几天：加减按钮 + 数字输入；每年某月：
/// 月份胶囊）。各种类的取值互不影响，来回切换不会丢掉已经填好的值。
///
/// 默认值：固定区间为含今天的最近 7 天，最近几天为 30，月份为本月。
class NotebookDateRuleEditor extends StatefulWidget {
  const NotebookDateRuleEditor({super.key, this.initial, this.now});

  final NotebookDateRule? initial;

  /// 测试注入的“今天”；缺省为当前时刻。
  final DateTime? now;

  @override
  State<NotebookDateRuleEditor> createState() => _NotebookDateRuleEditorState();
}

class _NotebookDateRuleEditorState extends State<NotebookDateRuleEditor> {
  late final DateTime _now = widget.now ?? DateTime.now();
  late NotebookDateKind _kind =
      widget.initial?.kind ?? NotebookDateKind.lastDays;
  late DateTime _from =
      widget.initial?.from ?? DateTime(_now.year, _now.month, _now.day - 6);
  late DateTime _to =
      widget.initial?.to ?? DateTime(_now.year, _now.month, _now.day);
  late int _days = widget.initial?.days ?? 30;
  late int _month = widget.initial?.month ?? _now.month;
  late final TextEditingController _daysText = TextEditingController(
    text: '$_days',
  );

  @override
  void dispose() {
    _daysText.dispose();
    super.dispose();
  }

  NotebookDateRule get _result => switch (_kind) {
    NotebookDateKind.between => NotebookDateRule.between(_from, _to),
    NotebookDateKind.lastDays => NotebookDateRule.lastDays(_days),
    NotebookDateKind.thisYear => const NotebookDateRule.thisYear(),
    NotebookDateKind.monthEveryYear => NotebookDateRule.monthEveryYear(_month),
    NotebookDateKind.dayEveryYear => const NotebookDateRule.dayEveryYear(),
  };

  void _setDays(int value) {
    final days = value.clamp(
      NotebookDateRule.minDays,
      NotebookDateRule.maxDays,
    );
    setState(() => _days = days);
    if (_daysText.text != '$days') {
      _daysText.value = TextEditingValue(
        text: '$days',
        selection: TextSelection.collapsed(offset: '$days'.length),
      );
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _from = DateUtils.dateOnly(picked.start);
      _to = DateUtils.dateOnly(picked.end);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return NotebookRuleSheetFrame(
      title: l10n.notebookRuleTypeDate,
      result: _result,
      children: <Widget>[
        for (final kind in NotebookDateKind.values) ...<Widget>[
          ExpressiveChoiceTile(
            label: notebookDateKindLabel(l10n, kind),
            description: kind == NotebookDateKind.dayEveryYear
                ? l10n.notebookRuleDateTodayHint
                : null,
            selected: _kind == kind,
            onTap: () => setState(() => _kind = kind),
          ),
          // 选中项的控件展开 / 收起，不在一帧内推开下方选项。
          AnimatedSize(
            duration: ExpressiveMotion.durationNonZero(
              context,
              ExpressiveMotion.medium,
            ),
            curve: ExpressiveMotion.effects,
            alignment: Alignment.topCenter,
            child: _kind == kind
                ? _controlsFor(context, kind)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ],
    );
  }

  Widget _controlsFor(BuildContext context, NotebookDateKind kind) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    const padding = EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.xs,
      AppSpacing.l,
      AppSpacing.m,
    );
    switch (kind) {
      case NotebookDateKind.between:
        return Padding(
          padding: padding,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const ValueKey<String>('notebook_rule_date_range'),
              onPressed: () => unawaited(_pickRange()),
              icon: const FaIcon(FontAwesomeIcons.calendarDays, size: 14),
              label: Text(notebookDateRangeLabel(l10n, _from, _to, now: _now)),
            ),
          ),
        );
      case NotebookDateKind.lastDays:
        // 面板为玻璃时加减按钮换成玻璃底色，经典时为 null（原样）。
        final tonal = AppGlassField.tonalButtonStyle(context);
        return Padding(
          padding: padding,
          child: Row(
            children: <Widget>[
              IconButton.filledTonal(
                tooltip: l10n.notebookRuleDaysDecrease,
                style: tonal,
                onPressed: _days > NotebookDateRule.minDays
                    ? () => _setDays(_days - 1)
                    : null,
                icon: const FaIcon(FontAwesomeIcons.minus, size: 14),
              ),
              const SizedBox(width: AppSpacing.s),
              SizedBox(
                width: 72,
                child: TextField(
                  key: const ValueKey<String>('notebook_rule_days'),
                  controller: _daysText,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(isDense: true),
                  onChanged: (String value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      setState(
                        () => _days = parsed.clamp(
                          NotebookDateRule.minDays,
                          NotebookDateRule.maxDays,
                        ),
                      );
                    }
                  },
                  onSubmitted: (_) => _setDays(_days),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              IconButton.filledTonal(
                tooltip: l10n.notebookRuleDaysIncrease,
                style: tonal,
                onPressed: _days < NotebookDateRule.maxDays
                    ? () => _setDays(_days + 1)
                    : null,
                icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
              ),
              const SizedBox(width: AppSpacing.m),
              Flexible(
                child: Text(
                  l10n.notebookRuleSummaryLastDays(_days),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      case NotebookDateKind.monthEveryYear:
        return Padding(
          padding: padding,
          child: Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: <Widget>[
              for (var month = 1; month <= 12; month++)
                notebookRuleOptionChip(
                  context,
                  label: notebookMonthShortName(l10n, month),
                  selected: _month == month,
                  onTap: () => setState(() => _month = month),
                ),
            ],
          ),
        );
      case NotebookDateKind.thisYear:
      case NotebookDateKind.dayEveryYear:
        return const SizedBox(width: double.infinity);
    }
  }
}
