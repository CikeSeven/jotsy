import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../../widgets/expressive_button_group.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../../widgets/list_item_presence.dart';
import '../controllers/notebook_editor_controller.dart';
import '../controllers/notebook_rule_count_controller.dart';
import '../viewmodels/notebook_rule_labels.dart';
import 'notebook_rule_sheets.dart';

/// 智能日记本的规则编辑区（编辑页里类型为“智能”时出现，新建与编辑都有）。
///
/// 自上而下：组合方式（全部满足 | 任一满足）、实时篇数“符合条件：N 篇”
/// （或没有条件时的保存说明）、还没有条件时的“从示例开始”胶囊、条件行、
/// “添加条件”（到上限时换成说明）。
///
/// - 规则草稿在 [NotebookEditorController]，这里只组合界面并打开面板；
/// - 实时篇数由 [NotebookRuleCountController] 防抖后订阅，等待超过 300ms 才
///   经 [DelayedLoadingGate] 显示指示器，期间保留上一次的篇数；
/// - 条件没有 id，行的 key 由这里按增删同步维护：移除时先让那一行经
///   [ListItemPresence] 收起，动画结束后才从草稿里删掉；新加的行从 0 展开。
class NotebookEditorRulesSection extends ConsumerStatefulWidget {
  const NotebookEditorRulesSection({super.key, required this.controller});

  final NotebookEditorController controller;

  @override
  ConsumerState<NotebookEditorRulesSection> createState() =>
      _NotebookEditorRulesSectionState();
}

class _NotebookEditorRulesSectionState
    extends ConsumerState<NotebookEditorRulesSection> {
  late final NotebookRuleCountController _count = NotebookRuleCountController(
    ref.read(appDatabaseProvider),
  );

  /// 与 `controller.rules.rules` 一一对应的行 key。
  final List<int> _rowKeys = <int>[];
  final Set<int> _appearing = <int>{};
  final Set<int> _removing = <int>{};
  int _nextKey = 0;

  NotebookEditorController get _editor => widget.controller;

  @override
  void initState() {
    super.initState();
    _rowKeys.addAll(<int>[
      for (var i = 0; i < _editor.rules.rules.length; i++) _nextKey++,
    ]);
    _count.update(_editor.rules);
    _editor.addListener(_onEditorChanged);
  }

  @override
  void dispose() {
    _editor.removeListener(_onEditorChanged);
    _count.dispose();
    super.dispose();
  }

  /// 规则变化：同步行 key（新加的在末尾）并刷新实时篇数。
  void _onEditorChanged() {
    final length = _editor.rules.rules.length;
    while (_rowKeys.length < length) {
      final key = _nextKey++;
      _rowKeys.add(key);
      _appearing.add(key);
    }
    _count.update(_editor.rules);
  }

  Future<void> _add() async {
    final type = await showNotebookRuleTypeSheet(context);
    if (type == null || !mounted) return;
    final rule = await showNotebookRuleEditorSheet(context, type: type);
    if (rule != null && mounted) _editor.addRule(rule);
  }

  Future<void> _edit(int index) async {
    final rule = _editor.rules.rules[index];
    final type = notebookRuleTypeOf(rule);
    // 认不出的规则无从编辑，只能移除。
    if (type == null) return;
    final key = _rowKeys[index];
    final edited = await showNotebookRuleEditorSheet(
      context,
      type: type,
      initial: rule,
    );
    if (edited == null || !mounted) return;
    // 面板打开期间这一行可能已被移除，按 key 重新定位。
    final current = _rowKeys.indexOf(key);
    if (current >= 0) _editor.replaceRule(current, edited);
  }

  Future<void> _remove(int key) async {
    if (!_removing.add(key)) return;
    setState(() {});
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (duration > Duration.zero) await Future<void>.delayed(duration);
    if (!mounted) return;
    final index = _rowKeys.indexOf(key);
    _removing.remove(key);
    _appearing.remove(key);
    if (index < 0) return;
    _rowKeys.removeAt(index);
    _editor.removeRuleAt(index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rules = _editor.rules;
    final now = DateTime.now();
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    return SettingsCardGroup(
      title: l10n.notebookRulesTitle,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ExpressiveButtonGroup<NotebookRuleMatch>(
                minSegmentWidth: 104,
                segments: <ButtonSegment<NotebookRuleMatch>>[
                  ButtonSegment<NotebookRuleMatch>(
                    value: NotebookRuleMatch.all,
                    label: Text(l10n.notebookRulesMatchAll),
                  ),
                  ButtonSegment<NotebookRuleMatch>(
                    value: NotebookRuleMatch.any,
                    label: Text(l10n.notebookRulesMatchAny),
                  ),
                ],
                selected: <NotebookRuleMatch>{rules.match},
                onSelectionChanged: (value) => _editor.ruleMatch = value.single,
              ),
              const SizedBox(height: AppSpacing.m),
              _buildCountLine(context, l10n, rules),
              if (rules.isEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.l),
                Text(
                  l10n.notebookRulesExamples,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  children: <Widget>[
                    for (final example in notebookRuleExamples(l10n, now: now))
                      ActionChip(
                        avatar: FaIcon(
                          notebookRuleTypeIcon(
                            notebookRuleTypeOf(example.rule),
                          ),
                          size: 14,
                          color: scheme.primary,
                        ),
                        label: Text(example.label),
                        onPressed: () => _editor.applyExample(
                          example.rule,
                          name: example.name,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        for (var i = 0; i < rules.rules.length && i < _rowKeys.length; i++)
          ListItemPresence(
            key: ValueKey<String>('notebook_rule_row_${_rowKeys[i]}'),
            visible: !_removing.contains(_rowKeys[i]),
            appearing: _appearing.contains(_rowKeys[i]),
            duration: duration,
            child: _buildRuleRow(context, l10n, rules.rules[i], i, now),
          ),
        if (_editor.canAddRule)
          ListTile(
            key: const ValueKey<String>('notebook_rule_add'),
            titleAlignment: ListTileTitleAlignment.center,
            leading: FaIcon(
              FontAwesomeIcons.plus,
              size: 16,
              color: scheme.primary,
            ),
            title: Text(
              l10n.notebookRuleAdd,
              style: TextStyle(color: scheme.primary),
            ),
            onTap: () => unawaited(_add()),
          )
        else
          ListTile(
            titleAlignment: ListTileTitleAlignment.center,
            leading: FaIcon(
              FontAwesomeIcons.circleInfo,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(
              l10n.notebookRulesLimit(NotebookRuleSet.maxRules),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  /// “符合条件：N 篇”；没有条件时为保存说明。查询超过 300ms 时在数字旁
  /// 显示小号指示器。
  Widget _buildCountLine(
    BuildContext context,
    AppLocalizations l10n,
    NotebookRuleSet rules,
  ) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    if (rules.isEmpty) {
      return Text(
        l10n.notebookRulesNeedOne,
        key: const ValueKey<String>('notebook_rules_need_one'),
        style: style,
      );
    }
    return ListenableBuilder(
      listenable: _count,
      builder: (BuildContext context, Widget? child) {
        final count = _count.count;
        return DelayedLoadingGate(
          loading: _count.loading,
          builder: (BuildContext context, bool showLoading) => Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  count == null ? '' : l10n.notebookRulesMatchCount(count),
                  key: const ValueKey<String>('notebook_rules_count'),
                  style: style,
                ),
              ),
              if (showLoading) ...<Widget>[
                const SizedBox(width: AppSpacing.s),
                const ExpressiveLoadingIndicator(size: 16),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRuleRow(
    BuildContext context,
    AppLocalizations l10n,
    NotebookRule rule,
    int index,
    DateTime now,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final type = notebookRuleTypeOf(rule);
    final key = _rowKeys[index];
    return ListTile(
      titleAlignment: ListTileTitleAlignment.center,
      leading: FaIcon(
        notebookRuleTypeIcon(type),
        size: 16,
        color: type == null ? scheme.onSurfaceVariant : scheme.primary,
      ),
      title: Text(
        notebookRuleSummary(l10n, rule, now: now),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: type == null ? null : () => unawaited(_edit(index)),
      trailing: IconButton(
        tooltip: l10n.notebookRuleRemove,
        onPressed: () => unawaited(_remove(key)),
        icon: FaIcon(
          FontAwesomeIcons.xmark,
          size: 14,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
