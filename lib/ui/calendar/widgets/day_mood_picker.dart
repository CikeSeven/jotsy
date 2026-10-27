import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import 'day_mood_face.dart';

/// 长按日期面板里的心情一组：由低到高五个心情格，下面写名称。
///
/// 每个心情格与选完后的日期格同样的底色和脸（[DayMoodColors] / [DayMoodFace]），
/// 选之前就看得到这天会变成什么样。当前已选的一格外圈 2dp primary 描边、
/// 名称加粗变色，与日期格“选中”的描边同一形态。只负责挑选，写入由调用方
/// 完成。
class DayMoodPicker extends StatelessWidget {
  const DayMoodPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// 这天已记的心情；没有时为 null。
  final DayMood? selected;
  final ValueChanged<DayMood> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final mood in DayMood.values)
          Expanded(
            child: _DayMoodOption(
              mood: mood,
              selected: mood == selected,
              onTap: () => onSelected(mood),
            ),
          ),
      ],
    );
  }
}

class _DayMoodOption extends StatelessWidget {
  const _DayMoodOption({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  /// 心情格最大边长：手机上五格平分面板宽度后约 60dp，宽面板也不再变大。
  static const double _maxTile = 56;

  final DayMood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = DayMoodColors.of(colorScheme, mood);
    final label = dayMoodLabel(context.l10n, mood);
    final duration = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxTile),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedContainer(
                    duration: duration,
                    curve: ExpressiveMotion.effects,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.primary.withValues(alpha: 0),
                        width: 2,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.tile,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: 0.66,
                        heightFactor: 0.66,
                        child: DayMoodFace(mood: mood, color: colors.onTile),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
