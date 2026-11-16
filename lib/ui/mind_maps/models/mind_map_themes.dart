import 'package:flutter/painting.dart';
import 'package:meta/meta.dart';

import '../../diaries/models/diary_mood_palette.dart';
import 'mind_map_options.dart';

/// 导图的内置主题（内容配色，见 docs/rules/mind_maps.md）。
///
/// 主题只定义“种子色 + 各层级的形状与填充方式”，明暗两套颜色都在
/// `MindMapPalette` 里由种子经 `ColorScheme.fromSeed(fidelity)` 推出：同一种子
/// 在亮色下取较深的色调、暗色下取较浅的色调，文字色取配套的 on 色，对比度
/// 由 Material 的配色算法保证（测试兜底）。不用渐变、不写死黑白。

/// 节点的填充方式。
enum MindMapFill {
  /// 实色：分支强调色底 + on 色文字。
  solid,

  /// 容器色：分支的浅色容器底 + 容器上的文字色。
  container,

  /// 描边：卡片底色 + 分支色描边。
  outline,

  /// 反色：深底浅字（亮色）/ 浅底深字（暗色），只用于根节点。
  inverse,

  /// 无底色：文字直接在画布上（下划线、纯文字）。
  none,
}

/// 一个层级的节点外观。
@immutable
final class MindMapLevelSpec {
  const MindMapLevelSpec({
    required this.shape,
    required this.fill,
    required this.fontSize,
    required this.weight,
    required this.padding,
  });

  final MindMapNodeShape shape;
  final MindMapFill fill;
  final double fontSize;
  final FontWeight weight;
  final EdgeInsets padding;

  MindMapLevelSpec copyWith({
    MindMapNodeShape? shape,
    MindMapFill? fill,
    double? fontSize,
    FontWeight? weight,
    EdgeInsets? padding,
  }) => MindMapLevelSpec(
    shape: shape ?? this.shape,
    fill: fill ?? this.fill,
    fontSize: fontSize ?? this.fontSize,
    weight: weight ?? this.weight,
    padding: padding ?? this.padding,
  );
}

/// 内置主题。
enum MindMapThemeId {
  follow('follow'),
  rainbow('rainbow'),
  ocean('ocean'),
  forest('forest'),
  sunset('sunset'),
  sakura('sakura'),
  ink('ink'),
  paper('paper'),
  neon('neon'),
  macaron('macaron');

  const MindMapThemeId(this.id);

  final String id;

  static MindMapThemeId resolve(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return MindMapThemeId.follow;
  }
}

/// 根节点的缺省外观。
const MindMapLevelSpec _root = MindMapLevelSpec(
  shape: MindMapNodeShape.rounded,
  fill: MindMapFill.solid,
  fontSize: 20,
  weight: FontWeight.w700,
  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
);

/// 一级主题的缺省外观。
const MindMapLevelSpec _primary = MindMapLevelSpec(
  shape: MindMapNodeShape.rounded,
  fill: MindMapFill.container,
  fontSize: 16,
  weight: FontWeight.w600,
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
);

/// 二级及以下的缺省外观。
const MindMapLevelSpec _secondary = MindMapLevelSpec(
  shape: MindMapNodeShape.underline,
  fill: MindMapFill.none,
  fontSize: 14.5,
  weight: FontWeight.w500,
  padding: EdgeInsets.fromLTRB(4, 4, 4, 6),
);

/// 一套主题。
@immutable
final class MindMapThemeSpec {
  const MindMapThemeSpec({
    required this.id,
    this.seeds = const <int>[],
    this.rootSeed,
    this.monochrome = false,
    this.root = _root,
    this.primary = _primary,
    this.secondary = _secondary,
    this.line = MindMapLineStyle.curve,
    this.rainbow = true,
  });

  final MindMapThemeId id;

  /// 分支种子色（彩虹分支依次取用、循环）；空列表表示跟随应用主题色推出。
  final List<int> seeds;

  /// 根节点的种子色；null 时实色根取应用主色（跟随主题）或第一个种子。
  final int? rootSeed;

  /// 黑白主题：分支一律取中性灰阶，忽略种子。
  final bool monochrome;
  final MindMapLevelSpec root;
  final MindMapLevelSpec primary;
  final MindMapLevelSpec secondary;

  /// 文档没有指定连线时的缺省。
  final MindMapLineStyle line;

  /// 文档没有指定时是否按分支取不同颜色。
  final bool rainbow;

  MindMapLevelSpec level(int depth) => switch (depth) {
    0 => root,
    1 => primary,
    _ => secondary,
  };

  static MindMapThemeSpec of(MindMapThemeId id) => _themes[id]!;
}

final Map<MindMapThemeId, MindMapThemeSpec> _themes =
    <MindMapThemeId, MindMapThemeSpec>{
      MindMapThemeId.follow: const MindMapThemeSpec(
        id: MindMapThemeId.follow,
        rainbow: false,
      ),
      MindMapThemeId.rainbow: const MindMapThemeSpec(
        id: MindMapThemeId.rainbow,
        seeds: kDiaryMoodDefaultColors,
        root: MindMapLevelSpec(
          shape: MindMapNodeShape.rounded,
          fill: MindMapFill.inverse,
          fontSize: 20,
          weight: FontWeight.w700,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        primary: MindMapLevelSpec(
          shape: MindMapNodeShape.rounded,
          fill: MindMapFill.solid,
          fontSize: 16,
          weight: FontWeight.w600,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      MindMapThemeId.ocean: const MindMapThemeSpec(
        id: MindMapThemeId.ocean,
        rootSeed: 0xFF01579B,
        seeds: <int>[
          0xFF0277BD,
          0xFF00838F,
          0xFF26A69A,
          0xFF3949AB,
          0xFF0097A7,
          0xFF1E88E5,
        ],
      ),
      MindMapThemeId.forest: const MindMapThemeSpec(
        id: MindMapThemeId.forest,
        rootSeed: 0xFF1B5E20,
        seeds: <int>[
          0xFF2E7D32,
          0xFF558B2F,
          0xFF00796B,
          0xFF827717,
          0xFF6D4C41,
          0xFF388E3C,
        ],
      ),
      MindMapThemeId.sunset: const MindMapThemeSpec(
        id: MindMapThemeId.sunset,
        rootSeed: 0xFFBF360C,
        seeds: <int>[
          0xFFE65100,
          0xFFD84315,
          0xFFC2185B,
          0xFF8E24AA,
          0xFFF9A825,
          0xFFEF6C00,
        ],
        primary: MindMapLevelSpec(
          shape: MindMapNodeShape.rounded,
          fill: MindMapFill.solid,
          fontSize: 16,
          weight: FontWeight.w600,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      MindMapThemeId.sakura: const MindMapThemeSpec(
        id: MindMapThemeId.sakura,
        rootSeed: 0xFFAD1457,
        seeds: <int>[
          0xFFD81B60,
          0xFFEC407A,
          0xFFAB47BC,
          0xFFF06292,
          0xFF8E24AA,
          0xFFE57373,
        ],
        root: MindMapLevelSpec(
          shape: MindMapNodeShape.pill,
          fill: MindMapFill.solid,
          fontSize: 20,
          weight: FontWeight.w700,
          padding: EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        ),
        primary: MindMapLevelSpec(
          shape: MindMapNodeShape.pill,
          fill: MindMapFill.container,
          fontSize: 16,
          weight: FontWeight.w600,
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
      ),
      MindMapThemeId.ink: const MindMapThemeSpec(
        id: MindMapThemeId.ink,
        monochrome: true,
        rainbow: false,
        root: MindMapLevelSpec(
          shape: MindMapNodeShape.rect,
          fill: MindMapFill.inverse,
          fontSize: 20,
          weight: FontWeight.w700,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        primary: MindMapLevelSpec(
          shape: MindMapNodeShape.rect,
          fill: MindMapFill.outline,
          fontSize: 16,
          weight: FontWeight.w600,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        line: MindMapLineStyle.rounded,
      ),
      MindMapThemeId.paper: const MindMapThemeSpec(
        id: MindMapThemeId.paper,
        rootSeed: 0xFF6D4C41,
        seeds: <int>[
          0xFF6D4C41,
          0xFF5D4037,
          0xFF795548,
          0xFF8D6E63,
          0xFF4E342E,
          0xFF607D8B,
        ],
        rainbow: false,
        root: MindMapLevelSpec(
          shape: MindMapNodeShape.rect,
          fill: MindMapFill.outline,
          fontSize: 20,
          weight: FontWeight.w700,
          padding: EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        ),
        primary: MindMapLevelSpec(
          shape: MindMapNodeShape.underline,
          fill: MindMapFill.none,
          fontSize: 16,
          weight: FontWeight.w600,
          padding: EdgeInsets.fromLTRB(4, 4, 4, 7),
        ),
        secondary: MindMapLevelSpec(
          shape: MindMapNodeShape.plain,
          fill: MindMapFill.none,
          fontSize: 14.5,
          weight: FontWeight.w400,
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        line: MindMapLineStyle.rounded,
      ),
      MindMapThemeId.neon: const MindMapThemeSpec(
        id: MindMapThemeId.neon,
        seeds: <int>[
          0xFF00B8D4,
          0xFFFF4081,
          0xFF64DD17,
          0xFFFFAB00,
          0xFFD500F9,
          0xFF2979FF,
        ],
        root: MindMapLevelSpec(
          shape: MindMapNodeShape.pill,
          fill: MindMapFill.inverse,
          fontSize: 20,
          weight: FontWeight.w800,
          padding: EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        ),
        primary: MindMapLevelSpec(
          shape: MindMapNodeShape.pill,
          fill: MindMapFill.solid,
          fontSize: 16,
          weight: FontWeight.w700,
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
      ),
      MindMapThemeId.macaron: const MindMapThemeSpec(
        id: MindMapThemeId.macaron,
        rootSeed: 0xFF9575CD,
        seeds: <int>[
          0xFFF48FB1,
          0xFF80CBC4,
          0xFFFFCC80,
          0xFFB39DDB,
          0xFF90CAF9,
          0xFFC5E1A5,
        ],
        root: MindMapLevelSpec(
          shape: MindMapNodeShape.pill,
          fill: MindMapFill.container,
          fontSize: 20,
          weight: FontWeight.w700,
          padding: EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        ),
        primary: MindMapLevelSpec(
          shape: MindMapNodeShape.pill,
          fill: MindMapFill.container,
          fontSize: 16,
          weight: FontWeight.w600,
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
        secondary: MindMapLevelSpec(
          shape: MindMapNodeShape.pill,
          fill: MindMapFill.container,
          fontSize: 14,
          weight: FontWeight.w500,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      ),
    };
