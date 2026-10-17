import 'package:flutter/material.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/widgets/value_listenable_selector.dart';

import '../energy_battery_indicator.dart';
import 'publish_panel_tile.dart';

/// 心情：固定 5 列两行的表情选择，再点一次取消。只随草稿的心情重建。
class PublishMoodSection extends StatelessWidget {
  const PublishMoodSection({
    super.key,
    required this.draft,
    required this.moodOptions,
  });

  final DiaryMetaDraftController draft;
  final List<String> moodOptions;

  static const int _columns = 5;
  static const double _spacing = 8;

  @override
  Widget build(BuildContext context) {
    final options = moodOptions.isEmpty
        ? SettingsService.defaultMoodOptions
        : SettingsService.normalizeMoodOptions(moodOptions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.autoT0116,
          style: PublishPanelTile.titleStyle(context),
        ),
        const SizedBox(height: 8),
        ValueListenableSelector<DiaryMetaDraft, String?>(
          valueListenable: draft,
          selector: (value) => value.moodEmoji,
          builder: (context, mood, _) => LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final itemWidth =
                  (constraints.maxWidth - _spacing * (_columns - 1)) / _columns;
              // 固定 5 列，两行排布，不允许横向滚动。
              return Wrap(
                spacing: _spacing,
                children: <Widget>[
                  for (final emoji in options)
                    SizedBox(
                      width: itemWidth,
                      child: ChoiceChip(
                        showCheckmark: false,
                        side: BorderSide.none,
                        elevation: 0,
                        pressElevation: 0,
                        shadowColor: Colors.transparent,
                        shape: const StadiumBorder(),
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(
                            emoji,
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(height: 1),
                          ),
                        ),
                        selected: mood == emoji,
                        onSelected: (selected) =>
                            draft.setMood(selected ? emoji : null),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 精力：开关决定是否记录；打开后用 1–5 整档滑块调节。
///
/// 关闭再打开时恢复上一次的值（[_lastLevel]，默认 4），而不是总回到 4。
/// 只随草稿的精力重建。
class PublishEnergySection extends StatefulWidget {
  const PublishEnergySection({super.key, required this.draft});

  final DiaryMetaDraftController draft;

  @override
  State<PublishEnergySection> createState() => _PublishEnergySectionState();
}

class _PublishEnergySectionState extends State<PublishEnergySection> {
  double _lastLevel = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ValueListenableSelector<DiaryMetaDraft, double?>(
      valueListenable: widget.draft,
      selector: (value) => value.energyLevel,
      builder: (context, level, _) {
        if (level != null) _lastLevel = level;
        final enabled = level != null;
        final value = EnergyBatteryIndicator.normalizeValue(
          level ?? _lastLevel,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Text(
                        l10n.autoT0175,
                        style: PublishPanelTile.titleStyle(context),
                      ),
                      const SizedBox(width: 8),
                      if (enabled) ...<Widget>[
                        EnergyBatteryIndicator(value: value, iconSize: 22),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            EnergyBatteryIndicator.descriptionForValue(
                              value,
                              l10n,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ] else
                        Flexible(
                          child: Text(
                            l10n.diaryEnergyUnrecorded,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: l10n.diaryEnergySwitchTooltip,
                  child: Switch(
                    value: enabled,
                    onChanged: (on) =>
                        widget.draft.setEnergy(on ? _lastLevel : null),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              // 减少动画时用 1ms 近似瞬时：0 时长的 AnimatedSize 会在自身
              // performLayout 内重新标脏而触发断言（见 ExpressiveMotion.durationNonZero）。
              duration: ExpressiveMotion.durationNonZero(
                context,
                ExpressiveMotion.fast,
              ),
              curve: ExpressiveMotion.effects,
              alignment: Alignment.topCenter,
              child: enabled
                  ? Slider(
                      value: value,
                      min: 1,
                      max: 5,
                      // 精力是五格电量：整档 1–5 与文案一一对应。旧版连续值照常
                      // 显示，拖动后吸附到整档。
                      divisions: 4,
                      label: EnergyBatteryIndicator.formatValue(value),
                      onChanged: widget.draft.setEnergy,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}
