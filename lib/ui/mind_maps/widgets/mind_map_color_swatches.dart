import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/diary_mood_palette.dart';
import '../viewmodels/mind_map_palette.dart';

/// 主题自定义颜色可选的种子色（与心情色同一组十个色相 + 一个中性灰）。
/// 整条样式（主题样式面板）与局部样式（格式条）共用；显示与写入都经
/// [MindMapPalette.custom] 按明暗换算。
const List<int> kMindMapColorSeeds = <int>[
  ...kDiaryMoodDefaultColors,
  0xFF757575,
];

/// 一个色块：[seed] 为 null 时是“默认”（斜线）；选中时描主色边并打勾。
/// 颜色经 [preview] 换算后画强调色。
class MindMapColorSwatch extends StatelessWidget {
  const MindMapColorSwatch({
    super.key,
    required this.seed,
    required this.active,
    required this.preview,
    required this.onTap,
    this.size = 34,
  });

  final Color? seed;
  final bool active;
  final MindMapBranchColors Function(Color seed) preview;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final seed = this.seed;
    final colors = seed == null ? null : preview(seed);
    return Semantics(
      button: true,
      selected: active,
      label: seed == null
          ? context.l10n.mindMapColorDefault
          : '#${seed.toARGB32().toRadixString(16).toUpperCase()}',
      child: InkResponse(
        onTap: onTap,
        radius: size * 0.65,
        child: AnimatedContainer(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colors?.accent ?? scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? scheme.primary : scheme.outlineVariant,
              width: active ? 2.5 : 1,
            ),
          ),
          child: colors == null
              ? Center(
                  child: FaIcon(
                    FontAwesomeIcons.slash,
                    size: size * 0.35,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : active
              ? Center(
                  child: FaIcon(
                    FontAwesomeIcons.check,
                    size: size * 0.38,
                    color: colors.onAccent,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// 一组色块（自动换行）：首个是“默认”，其余为 [kMindMapColorSeeds]。
/// [selected] 为当前取值（null 为默认），点了经 [onPick] 交回（默认为 null）。
class MindMapColorSwatches extends StatelessWidget {
  const MindMapColorSwatches({
    super.key,
    required this.selected,
    required this.preview,
    required this.onPick,
  });

  final Color? selected;
  final MindMapBranchColors Function(Color seed) preview;
  final ValueChanged<Color?> onPick;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: <Widget>[
      MindMapColorSwatch(
        seed: null,
        active: selected == null,
        preview: preview,
        onTap: () => onPick(null),
      ),
      for (final value in kMindMapColorSeeds)
        MindMapColorSwatch(
          seed: Color(value),
          active: selected?.toARGB32() == value,
          preview: preview,
          onTap: () => onPick(Color(value)),
        ),
    ],
  );
}
