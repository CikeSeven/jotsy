/// 颜色面板「色系」页的 Material 色板数据：19 个色系，各自的色阶与强调色。
///
/// - 输入：无（Flutter `Colors` 里的 Material 2 色板常量，与旧版取色对话框的
///   Material 色板同一份）；
/// - 输出：每个色系按从浅到深排好的色阶、由颜色反查所在色系，以及色系页的
///   排布（每行几个色阶、占几行）；
/// - 无副作用，不依赖 BuildContext。
///
/// 写进正文的是色阶原值（不透明）：这是一份固定的调色板，用户挑的就是那一格
/// 的颜色；背景色块上写着墨色“A”，深浅搭配在当前主题下是否看得清一目了然。
library;

import 'package:flutter/material.dart'
    show Color, Colors, MaterialAccentColor, MaterialColor, immutable;
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';

/// 一个色系最多几格：10 个色阶 + 4 个强调色；灰色系是 12 个色阶 + 白与黑。
const int kDiaryMaterialMaxShades = 14;

/// 色阶的种类：显示名与分组由它决定。
enum DiaryMaterialShadeKind {
  /// 50–900（灰色系另有 350 / 850）。
  tone,

  /// A100 / A200 / A400 / A700：与色阶之间隔一道竖线。
  accent,

  /// 灰色系两端的纯白与纯黑。
  white,
  black,
}

@immutable
class DiaryMaterialShade {
  const DiaryMaterialShade._(this.color, this.kind, [this.tone = '']);

  final Color color;
  final DiaryMaterialShadeKind kind;

  /// 色阶名（`50`、`900`、`A100`…）；白与黑为空，显示名另取。
  final String tone;
}

/// Material 色系，顺序同旧版 Material 取色器：按色相绕一圈，最后是棕、灰与
/// 蓝灰三个中性色系。
enum DiaryMaterialFamily {
  red(Colors.red, Colors.redAccent),
  pink(Colors.pink, Colors.pinkAccent),
  purple(Colors.purple, Colors.purpleAccent),
  deepPurple(Colors.deepPurple, Colors.deepPurpleAccent),
  indigo(Colors.indigo, Colors.indigoAccent),
  blue(Colors.blue, Colors.blueAccent),
  lightBlue(Colors.lightBlue, Colors.lightBlueAccent),
  cyan(Colors.cyan, Colors.cyanAccent),
  teal(Colors.teal, Colors.tealAccent),
  green(Colors.green, Colors.greenAccent),
  lightGreen(Colors.lightGreen, Colors.lightGreenAccent),
  lime(Colors.lime, Colors.limeAccent),
  yellow(Colors.yellow, Colors.yellowAccent),
  amber(Colors.amber, Colors.amberAccent),
  orange(Colors.orange, Colors.orangeAccent),
  deepOrange(Colors.deepOrange, Colors.deepOrangeAccent),
  brown(Colors.brown),
  grey(Colors.grey),
  blueGrey(Colors.blueGrey);

  const DiaryMaterialFamily(this._primary, [this._accent]);

  final MaterialColor _primary;
  final MaterialAccentColor? _accent;

  /// 色系行里代表这一族的颜色：500 色阶（取纯 [Color]，不带色板）。
  Color get color => _primary[500]!;

  /// 这一族的全部格子，从浅到深，强调色在后（灰色系是白 → 灰 → 黑）。
  List<DiaryMaterialShade> get shades => _shades[index];

  static final List<List<DiaryMaterialShade>> _shades =
      List<List<DiaryMaterialShade>>.unmodifiable(<List<DiaryMaterialShade>>[
        for (final family in values) family._buildShades(),
      ]);

  /// 颜色（ARGB）→ 所在色系；各色系之间没有重复的颜色。
  static final Map<int, DiaryMaterialFamily> _byArgb =
      <int, DiaryMaterialFamily>{
        for (final family in values)
          for (final shade in family.shades) shade.color.toARGB32(): family,
      };

  /// [color] 恰好是某一格（按 ARGB 比较）时返回它所在的色系。
  static DiaryMaterialFamily? of(Color? color) =>
      color == null ? null : _byArgb[color.toARGB32()];

  List<DiaryMaterialShade> _buildShades() {
    DiaryMaterialShade tone(int shade) => DiaryMaterialShade._(
      _primary[shade]!,
      DiaryMaterialShadeKind.tone,
      '$shade',
    );
    if (this == grey) {
      return List<DiaryMaterialShade>.unmodifiable(<DiaryMaterialShade>[
        const DiaryMaterialShade._(Colors.white, DiaryMaterialShadeKind.white),
        for (final shade in const <int>[
          50,
          100,
          200,
          300,
          350,
          400,
          500,
          600,
          700,
          800,
          850,
          900,
        ])
          tone(shade),
        const DiaryMaterialShade._(Colors.black, DiaryMaterialShadeKind.black),
      ]);
    }
    final accent = _accent;
    return List<DiaryMaterialShade>.unmodifiable(<DiaryMaterialShade>[
      for (final shade in const <int>[
        50,
        100,
        200,
        300,
        400,
        500,
        600,
        700,
        800,
        900,
      ])
        tone(shade),
      if (accent != null)
        for (final shade in const <int>[100, 200, 400, 700])
          DiaryMaterialShade._(
            accent[shade]!,
            DiaryMaterialShadeKind.accent,
            'A$shade',
          ),
    ]);
  }
}

/// 色系页的排布：上方色阶（常见手机宽度两行各 7 格，放得下 14 列时一行排完），
/// 隔 [DiaryColorGridLayout.stripGap] 是一行可横向滚动的色系。与色板页同一
/// 套格高，手机宽度下三页等高（128dp），切换页签时面板不跳。
extension DiaryMaterialGridLayout on DiaryColorGridLayout {
  /// 色阶每行几格。
  int get materialColumns => columns >= kDiaryMaterialMaxShades
      ? kDiaryMaterialMaxShades
      : kDiaryMaterialMaxShades ~/ 2;

  int get materialRows => (kDiaryMaterialMaxShades / materialColumns).ceil();

  /// 色阶区的高度。
  double get materialShadesHeight =>
      materialRows * DiaryColorGridLayout.cellHeight;

  /// 色系页总高：色阶 + 间距 + 色系一行。
  double get materialHeight =>
      materialShadesHeight +
      DiaryColorGridLayout.stripGap +
      DiaryColorGridLayout.cellHeight;
}
