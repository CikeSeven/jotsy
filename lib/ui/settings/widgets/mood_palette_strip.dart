import 'package:flutter/material.dart';

/// 心情符号页顶部的心情色谱：十个心情由低落到高兴排成一行，每格铺这种心情
/// 的颜色、中间是它的符号，改颜色或符号时随之更新。
///
/// 只读，读屏跳过（下方每一行都有自己的标签）。格与格之间留缝、各自实色，
/// 不画渐变（AGENTS.md §6）；符号经 FittedBox 随格宽缩小，320dp 宽也放得下。
class MoodPaletteStrip extends StatelessWidget {
  const MoodPaletteStrip({super.key, required this.moods, required this.colors})
    : assert(moods.length == colors.length);

  final List<String> moods;
  final List<Color> colors;

  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outlineVariant;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Row(
          children: <Widget>[
            for (var i = 0; i < moods.length; i += 1) ...<Widget>[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors[i],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: outline, width: 0.8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: FittedBox(
                      child: Text(moods[i], style: theme.textTheme.titleLarge),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
