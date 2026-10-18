import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../calendar/widgets/calendar_options_controls.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diaries/widgets/publish_panel/publish_mood_energy_sections.dart';
import '../../widgets/expressive_button_group.dart';
import '../controllers/diary_template_editor_controller.dart';
import '../models/diary_template_recommend.dart';
import '../viewmodels/diary_template_labels.dart';
import '../widgets/diary_template_tags_field.dart';

/// 套用时一并设置：标签、心情、精力与时间胶囊。心情、精力直接复用发布面板
/// 的区块（操作的是编辑页私有的元数据草稿），与发布时看到的一致。
class DiaryTemplateEditorPresets extends ConsumerWidget {
  const DiaryTemplateEditorPresets({super.key, required this.controller});

  final DiaryTemplateEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final moodOptions =
        ref.watch(moodOptionsProvider).asData?.value ??
        SettingsService.defaultMoodOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CalendarOptionsFieldLabel(text: l10n.diaryTemplateEditorTags),
        DiaryTemplateTagsField(controller: controller),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.s,
            AppSpacing.xs,
            AppSpacing.l,
          ),
          child: Text(
            l10n.diaryTemplateEditorTagsHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        PublishMoodSection(draft: controller.meta, moodOptions: moodOptions),
        const SizedBox(height: AppSpacing.l),
        PublishEnergySection(draft: controller.meta),
        const SizedBox(height: AppSpacing.l),
        CalendarOptionsFieldLabel(text: l10n.diaryTemplateEditorCapsule),
        ExpressiveButtonGroup<_CapsuleChoice>(
          minSegmentWidth: 72,
          segments: <ButtonSegment<_CapsuleChoice>>[
            for (final choice in _CapsuleChoice.values)
              ButtonSegment<_CapsuleChoice>(
                value: choice,
                label: Text(
                  choice.preset == null
                      ? l10n.diaryTemplateEditorNone
                      : diaryTemplateCapsuleLabel(l10n, choice.preset!),
                ),
              ),
          ],
          selected: <_CapsuleChoice>{_CapsuleChoice.of(controller.capsule)},
          onSelectionChanged: (selection) =>
              controller.capsule = selection.first.preset,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.s,
            AppSpacing.xs,
            0,
          ),
          child: Text(
            l10n.diaryTemplateEditorCapsuleHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

enum _CapsuleChoice {
  none(null),
  week(TimeCapsulePreset.week),
  month(TimeCapsulePreset.month),
  year(TimeCapsulePreset.year);

  const _CapsuleChoice(this.preset);

  final TimeCapsulePreset? preset;

  static _CapsuleChoice of(TimeCapsulePreset? preset) =>
      values.firstWhere((choice) => choice.preset == preset);
}

/// 推荐时间：时段、星期、月初月末三组可多选的条件。
class DiaryTemplateEditorRules extends StatelessWidget {
  const DiaryTemplateEditorRules({super.key, required this.controller});

  final DiaryTemplateEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rules = controller.recommend;
    // 2026-10-19 是周一：按 1–7 依次取当前语言的星期简称。
    final weekdayFormat = DateFormat.E(l10n.localeName);
    String weekdayLabel(int weekday) =>
        weekdayFormat.format(DateTime(2026, 10, 18 + weekday));
    Set<T> toggled<T>(Set<T> set, T value, bool on) =>
        Set<T>.unmodifiable(on ? <T>{...set, value} : set.difference({value}));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            0,
            AppSpacing.xs,
            AppSpacing.m,
          ),
          child: Text(
            l10n.diaryTemplateEditorRecommendHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        CalendarOptionsFieldLabel(text: l10n.diaryTemplateEditorSlots),
        _ChipWrap(
          children: <Widget>[
            for (final slot in DiaryTemplateTimeSlot.values)
              FilterChip(
                label: Text(_slotLabel(l10n, slot)),
                selected: rules.slots.contains(slot),
                onSelected: (on) => controller.recommend = rules.copyWith(
                  slots: toggled(rules.slots, slot, on),
                ),
              ),
          ],
        ),
        CalendarOptionsFieldLabel(text: l10n.diaryTemplateEditorWeekdays),
        _ChipWrap(
          children: <Widget>[
            for (var weekday = 1; weekday <= 7; weekday++)
              FilterChip(
                label: Text(weekdayLabel(weekday)),
                selected: rules.weekdays.contains(weekday),
                onSelected: (on) => controller.recommend = rules.copyWith(
                  weekdays: toggled(rules.weekdays, weekday, on),
                ),
              ),
          ],
        ),
        CalendarOptionsFieldLabel(text: l10n.diaryTemplateEditorMonth),
        _ChipWrap(
          children: <Widget>[
            for (final phase in DiaryTemplateMonthPhase.values)
              FilterChip(
                label: Text(
                  phase == DiaryTemplateMonthPhase.start
                      ? l10n.diaryTemplateMonthStart
                      : l10n.diaryTemplateMonthEnd,
                ),
                selected: rules.monthPhases.contains(phase),
                onSelected: (on) => controller.recommend = rules.copyWith(
                  monthPhases: toggled(rules.monthPhases, phase, on),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _slotLabel(AppLocalizations l10n, DiaryTemplateTimeSlot slot) =>
      switch (slot) {
        DiaryTemplateTimeSlot.morning => l10n.diaryTemplateSlotMorning,
        DiaryTemplateTimeSlot.afternoon => l10n.diaryTemplateSlotAfternoon,
        DiaryTemplateTimeSlot.evening => l10n.diaryTemplateSlotEvening,
        DiaryTemplateTimeSlot.night => l10n.diaryTemplateSlotNight,
      };
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: Wrap(
        spacing: AppSpacing.s,
        runSpacing: AppSpacing.s,
        children: children,
      ),
    );
  }
}
