// 设置 → AI 助手 → 隐私：随正文发送哪些元数据、对话与回顾的范围（排除
// 的日记本与标签、字数上限、是否含归档）、发送前确认的时机、是否允许对
// 私密日记使用单篇功能，以及重置“不再提示”。
//
// 排除的日记本只列可见性为 normal 的本子：私密本子本来就永远不会发送，
// 列出来反而像是“需要手动排除”。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/notebook_payload.dart';
import '../../../../core/services/app_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../../notebooks/providers/notebook_providers.dart';
import '../../../settings/widgets/settings_card_group.dart';
import '../../../settings/widgets/settings_option_tiles.dart';
import '../../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../models/ai_preference_parts.dart';
import '../../models/ai_privacy_options.dart';
import '../../providers/ai_providers.dart';
import '../../widgets/ai_page_scaffold.dart';

class AiPrivacyPage extends ConsumerWidget {
  const AiPrivacyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final privacy = ref.watch(aiPreferencesProvider.select((p) => p.privacy));

    void update(AiPrivacyOptions Function(AiPrivacyOptions p) change) =>
        updateAiPreferences(ref, (p) => p.copyWith(privacy: change(p.privacy)));

    String count(Set<String> values) => values.isEmpty
        ? l10n.aiPrivacyExcludedNone
        : l10n.aiPrivacyExcludedCount(values.length);

    Future<void> pickNotebooks() async {
      final notebooks = await ref.read(notebooksProvider.future);
      if (!context.mounted) return;
      final picked = await _showMultiPicker(
        context,
        title: l10n.aiPrivacyPickNotebooks,
        options: <String, String>{
          for (final notebook in notebooks)
            if (notebook.effectiveVisibility == NotebookVisibility.normal)
              notebook.id: notebook.name,
        },
        selected: privacy.excludedNotebookIds,
      );
      if (picked != null) {
        update((p) => p.copyWith(excludedNotebookIds: picked));
      }
    }

    Future<void> pickTags() async {
      final tags = await ref.read(tagListProvider.future);
      if (!context.mounted) return;
      final picked = await _showMultiPicker(
        context,
        title: l10n.aiPrivacyPickTags,
        options: <String, String>{for (final tag in tags) tag.name: tag.name},
        selected: privacy.excludedTagNames,
      );
      if (picked != null) {
        update((p) => p.copyWith(excludedTagNames: picked));
      }
    }

    return AiPageScaffold(
      title: l10n.aiPrivacyTitle,
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.aiPrivacySendGroup,
          footer: l10n.aiPrivacySendFooter,
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.aiPrivacyDate,
              value: privacy.sendDate,
              onChanged: (bool v) => update((p) => p.copyWith(sendDate: v)),
            ),
            SettingsSwitchTile(
              title: l10n.aiPrivacyMood,
              value: privacy.sendMood,
              onChanged: (bool v) => update((p) => p.copyWith(sendMood: v)),
            ),
            SettingsSwitchTile(
              title: l10n.aiPrivacyTags,
              value: privacy.sendTags,
              onChanged: (bool v) => update((p) => p.copyWith(sendTags: v)),
            ),
            SettingsSwitchTile(
              title: l10n.aiPrivacyWeather,
              value: privacy.sendWeather,
              onChanged: (bool v) => update((p) => p.copyWith(sendWeather: v)),
            ),
            SettingsSwitchTile(
              title: l10n.aiPrivacyLocation,
              value: privacy.sendLocation,
              onChanged: (bool v) => update((p) => p.copyWith(sendLocation: v)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          title: l10n.aiPrivacyScopeGroup,
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.aiPrivacyIncludeArchived,
              value: privacy.includeArchived,
              onChanged: (bool v) =>
                  update((p) => p.copyWith(includeArchived: v)),
            ),
            AiNavTile(
              icon: FontAwesomeIcons.book,
              title: l10n.aiPrivacyExcludedNotebooks,
              subtitle: count(privacy.excludedNotebookIds),
              onTap: pickNotebooks,
            ),
            AiNavTile(
              icon: FontAwesomeIcons.tags,
              title: l10n.aiPrivacyExcludedTags,
              subtitle: count(privacy.excludedTagNames),
              onTap: pickTags,
            ),
            _ChoiceSlider(
              title: l10n.aiPrivacyBudget,
              choices: AiPrivacyOptions.contextBudgetChoices,
              value: privacy.contextBudget,
              label: l10n.aiWords,
              onChanged: (int v) => update((p) => p.copyWith(contextBudget: v)),
            ),
            _ChoiceSlider(
              title: l10n.aiPrivacyPerDiary,
              choices: AiPrivacyOptions.perDiaryLimitChoices,
              value: privacy.perDiaryLimit,
              label: l10n.aiWords,
              onChanged: (int v) => update((p) => p.copyWith(perDiaryLimit: v)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          title: l10n.aiPrivacyConfirmGroup,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.aiPrivacyConfirmGroup,
              subtitle: l10n.aiPrivacyConfirmSubtitle,
              child: ExpressiveButtonGroup<AiConfirmMode>(
                minSegmentWidth: 88,
                segments: <ButtonSegment<AiConfirmMode>>[
                  ButtonSegment(
                    value: AiConfirmMode.firstTime,
                    label: Text(l10n.aiConfirmFirstTime),
                  ),
                  ButtonSegment(
                    value: AiConfirmMode.multiDiary,
                    label: Text(l10n.aiConfirmMultiDiary),
                  ),
                  ButtonSegment(
                    value: AiConfirmMode.always,
                    label: Text(l10n.aiConfirmAlways),
                  ),
                ],
                selected: {privacy.confirm},
                onSelectionChanged: (Set<AiConfirmMode> value) =>
                    update((p) => p.copyWith(confirm: value.single)),
              ),
            ),
            SettingsSwitchTile(
              title: l10n.aiPrivacyAllowPrivate,
              subtitle: l10n.aiPrivacyAllowPrivateSubtitle,
              value: privacy.allowPrivate,
              onChanged: (bool v) => update((p) => p.copyWith(allowPrivate: v)),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              title: Text(l10n.aiPrivacyResetHosts),
              subtitle: Text(l10n.aiPrivacyResetHostsSubtitle),
              onTap: () async {
                await updateAiLocalConfig(
                  ref,
                  (c) => c.copyWith(acknowledgedHosts: const <String>{}),
                );
                if (!context.mounted) return;
                await HomeHintVisibilityScope.showTrackedSnackBar(
                  context: context,
                  snackBar: SnackBar(
                    content: Text(l10n.aiPrivacyResetHostsDone),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// 在离散取值之间选择（拖动中只改本地预览，松手才写入）。
class _ChoiceSlider extends StatefulWidget {
  const _ChoiceSlider({
    required this.title,
    required this.choices,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final List<int> choices;
  final int value;
  final String Function(int value) label;
  final ValueChanged<int> onChanged;

  @override
  State<_ChoiceSlider> createState() => _ChoiceSliderState();
}

class _ChoiceSliderState extends State<_ChoiceSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final index = widget.choices.indexOf(widget.value);
    return SettingsSliderTile(
      title: widget.title,
      value: _dragging ?? (index < 0 ? 0 : index).toDouble(),
      min: 0,
      max: (widget.choices.length - 1).toDouble(),
      divisions: widget.choices.length - 1,
      valueLabel: (double v) => widget.label(widget.choices[v.round()]),
      onChanged: (double v) => setState(() => _dragging = v),
      onChangeEnd: (double v) {
        setState(() => _dragging = null);
        widget.onChanged(widget.choices[v.round()]);
      },
    );
  }
}

/// 多选面板：[options] 为 值 → 显示名；返回新的选中集合，关掉为 null。
Future<Set<String>?> _showMultiPicker(
  BuildContext context, {
  required String title,
  required Map<String, String> options,
  required Set<String> selected,
}) {
  return showAppModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (BuildContext sheetContext) =>
        _MultiPicker(title: title, options: options, initial: selected),
  );
}

class _MultiPicker extends StatefulWidget {
  const _MultiPicker({
    required this.title,
    required this.options,
    required this.initial,
  });

  final String title;
  final Map<String, String> options;
  final Set<String> initial;

  @override
  State<_MultiPicker> createState() => _MultiPickerState();
}

class _MultiPickerState extends State<_MultiPicker> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              widget.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: widget.options.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.aiPrivacyPickEmpty,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final entry in widget.options.entries)
                        CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          value: _selected.contains(entry.key),
                          title: Text(entry.value),
                          onChanged: (bool? value) => setState(() {
                            value == true
                                ? _selected.add(entry.key)
                                : _selected.remove(entry.key);
                          }),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              child: Text(l10n.commonConfirm),
            ),
          ),
        ],
      ),
    );
  }
}
