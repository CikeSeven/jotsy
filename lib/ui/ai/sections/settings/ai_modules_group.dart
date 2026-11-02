import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../settings/widgets/settings_card_group.dart';
import '../../../settings/widgets/settings_option_tiles.dart';
import '../../../settings/widgets/settings_reveal.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../models/ai_preference_parts.dart';
import '../../models/ai_preferences.dart';
import '../../providers/ai_providers.dart';
import '../../viewmodels/ai_labels.dart';

/// AI 设置页的「功能」分组：每个模块一行开关，开启时在它下方展开从属的
/// 选项（`SettingsReveal`，与所属行合成分组里的同一项，见 DESIGN.md §5.3
/// 的依赖开关规则）。每次拨动立即写入偏好。
class AiModulesGroup extends ConsumerWidget {
  const AiModulesGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final prefs = ref.watch(aiPreferencesProvider);

    void update(AiPreferences Function(AiPreferences p) change) =>
        updateAiPreferences(ref, change);

    Widget module(AiModule module, {List<Widget> options = const []}) {
      final enabled = prefs.isModuleEnabled(module);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SettingsSwitchTile(
            title: aiModuleLabel(l10n, module),
            subtitle: aiModuleSubtitle(l10n, module),
            value: enabled,
            onChanged: (bool value) =>
                update((p) => p.withModule(module, value)),
          ),
          if (options.isNotEmpty)
            SettingsReveal(
              visible: enabled,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final option in options) ...<Widget>[
                    settingsNestedDivider,
                    option,
                  ],
                ],
              ),
            ),
        ],
      );
    }

    return SettingsCardGroup(
      title: l10n.aiGroupFeatures,
      footer: l10n.aiGroupFeaturesFooter,
      children: <Widget>[
        module(AiModule.writing),
        module(
          AiModule.suggest,
          options: <Widget>[
            SettingsSwitchTile(
              nested: true,
              title: l10n.aiOptionTitleButton,
              value: prefs.titleButton,
              onChanged: (bool v) => update((p) => p.copyWith(titleButton: v)),
            ),
            SettingsSwitchTile(
              nested: true,
              title: l10n.aiOptionAutoSuggest,
              subtitle: l10n.aiOptionAutoSuggestSubtitle,
              value: prefs.autoSuggestOnPublish,
              onChanged: (bool v) =>
                  update((p) => p.copyWith(autoSuggestOnPublish: v)),
            ),
          ],
        ),
        module(
          AiModule.reply,
          options: <Widget>[
            SettingsSwitchTile(
              nested: true,
              title: l10n.aiOptionAutoReply,
              subtitle: l10n.aiOptionAutoReplySubtitle,
              value: prefs.autoReply,
              onChanged: (bool v) => update((p) => p.copyWith(autoReply: v)),
            ),
          ],
        ),
        module(
          AiModule.prompts,
          options: <Widget>[
            SettingsSwitchTile(
              nested: true,
              title: l10n.aiOptionPromptsStrip,
              subtitle: l10n.aiOptionPromptsStripSubtitle,
              value: prefs.promptsStrip,
              onChanged: (bool v) => update((p) => p.copyWith(promptsStrip: v)),
            ),
            SettingsSwitchTile(
              nested: true,
              title: l10n.aiOptionPromptsRecent,
              subtitle: l10n.aiOptionPromptsRecentSubtitle,
              value: prefs.promptsUseRecent,
              onChanged: (bool v) =>
                  update((p) => p.copyWith(promptsUseRecent: v)),
            ),
            SettingsChoiceTile(
              nested: true,
              title: l10n.aiOptionPromptStyle,
              child: ExpressiveButtonGroup<AiPromptInsertStyle>(
                minSegmentWidth: 72,
                segments: <ButtonSegment<AiPromptInsertStyle>>[
                  ButtonSegment(
                    value: AiPromptInsertStyle.callout,
                    label: Text(l10n.aiPromptStyleCallout),
                  ),
                  ButtonSegment(
                    value: AiPromptInsertStyle.quote,
                    label: Text(l10n.aiPromptStyleQuote),
                  ),
                  ButtonSegment(
                    value: AiPromptInsertStyle.heading,
                    label: Text(l10n.aiPromptStyleHeading),
                  ),
                ],
                selected: {prefs.promptStyle},
                onSelectionChanged: (Set<AiPromptInsertStyle> value) =>
                    update((p) => p.copyWith(promptStyle: value.single)),
              ),
            ),
          ],
        ),
        module(
          AiModule.recap,
          options: <Widget>[
            SettingsChoiceTile(
              nested: true,
              title: l10n.aiOptionRecapSections,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final section in AiRecapSection.values)
                    FilterChip(
                      label: Text(aiRecapSectionLabel(l10n, section)),
                      selected: prefs.recapSections.contains(section),
                      onSelected: (bool selected) => update((p) {
                        final next = {...p.recapSections};
                        selected ? next.add(section) : next.remove(section);
                        return p.copyWith(recapSections: next);
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
        module(
          AiModule.chat,
          options: <Widget>[
            SettingsChoiceTile(
              nested: true,
              title: l10n.aiOptionRetrieval,
              subtitle: l10n.aiOptionRetrievalSubtitle,
              child: ExpressiveButtonGroup<AiRetrievalMode>(
                minSegmentWidth: 72,
                segments: <ButtonSegment<AiRetrievalMode>>[
                  ButtonSegment(
                    value: AiRetrievalMode.smart,
                    label: Text(l10n.aiRetrievalSmart),
                  ),
                  ButtonSegment(
                    value: AiRetrievalMode.keyword,
                    label: Text(l10n.aiRetrievalKeyword),
                  ),
                  ButtonSegment(
                    value: AiRetrievalMode.recent,
                    label: Text(l10n.aiRetrievalRecent),
                  ),
                ],
                selected: {prefs.retrieval},
                onSelectionChanged: (Set<AiRetrievalMode> value) =>
                    update((p) => p.copyWith(retrieval: value.single)),
              ),
            ),
            _IndexSlider(
              title: l10n.aiOptionRecentDays,
              choices: AiPreferences.recentDaysChoices,
              value: prefs.recentDays,
              label: l10n.aiDays,
              onChanged: (int v) => update((p) => p.copyWith(recentDays: v)),
            ),
            _IndexSlider(
              title: l10n.aiOptionMaxCitations,
              choices: AiPreferences.maxCitationsChoices,
              value: prefs.maxCitations,
              label: l10n.aiEntries,
              onChanged: (int v) => update((p) => p.copyWith(maxCitations: v)),
            ),
            SettingsSwitchTile(
              nested: true,
              title: l10n.aiOptionShowReasoning,
              value: prefs.showReasoning,
              onChanged: (bool v) =>
                  update((p) => p.copyWith(showReasoning: v)),
            ),
            SettingsSwitchTile(
              nested: true,
              title: l10n.aiOptionShowTokens,
              value: prefs.showTokens,
              onChanged: (bool v) => update((p) => p.copyWith(showTokens: v)),
            ),
            SettingsSwitchTile(
              nested: true,
              title: l10n.aiOptionAutoTitle,
              value: prefs.autoTitle,
              onChanged: (bool v) => update((p) => p.copyWith(autoTitle: v)),
            ),
          ],
        ),
        module(
          AiModule.vision,
          options: <Widget>[
            SettingsSliderTile(
              nested: true,
              title: l10n.aiOptionVisionImages,
              value: prefs.visionMaxImages.toDouble(),
              min: 1,
              max: AiPreferences.maxVisionImages.toDouble(),
              divisions: AiPreferences.maxVisionImages - 1,
              valueLabel: (double v) => l10n.aiPhotos(v.round()),
              onChanged: null,
              onChangeEnd: (double v) =>
                  update((p) => p.copyWith(visionMaxImages: v.round())),
            ),
            SettingsChoiceTile(
              nested: true,
              title: l10n.aiOptionVisionSize,
              child: ExpressiveButtonGroup<int>(
                minSegmentWidth: 64,
                segments: <ButtonSegment<int>>[
                  ButtonSegment(
                    value: 512,
                    label: Text(l10n.aiVisionSizeSmall),
                  ),
                  ButtonSegment(
                    value: 1024,
                    label: Text(l10n.aiVisionSizeMedium),
                  ),
                  ButtonSegment(
                    value: 1536,
                    label: Text(l10n.aiVisionSizeLarge),
                  ),
                ],
                selected: {prefs.visionMaxSide},
                onSelectionChanged: (Set<int> value) =>
                    update((p) => p.copyWith(visionMaxSide: value.single)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 在一组离散取值之间选择的从属滑块（拖动中只改本地预览，松手才写入）。
class _IndexSlider extends StatefulWidget {
  const _IndexSlider({
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
  State<_IndexSlider> createState() => _IndexSliderState();
}

class _IndexSliderState extends State<_IndexSlider> {
  double? _dragging;

  int get _index {
    final index = widget.choices.indexOf(widget.value);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSliderTile(
      nested: true,
      title: widget.title,
      value: _dragging ?? _index.toDouble(),
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
