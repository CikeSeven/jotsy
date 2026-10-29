/// 提示块（`callout`）的底色档位与配色，编辑器、预览与各导出格式共用这一份。
///
/// - 输入：块 `data.tone` 的原值（认不出或缺省按 [DiaryCalloutTone.neutral]）；
/// - 输出：明暗两套的底色与强调色（左侧色条、面板色点）；编辑器经
///   [DiaryCalloutTone.background] 按当前主题取底色，导出（纸面恒为白底）只取
///   浅色一套 [DiaryCalloutTone.paperBackground] / [DiaryCalloutTone.paperAccent]；
/// - 无副作用，不依赖 BuildContext。
///
/// 与代码块配色同理，这是内容配色而不是界面硬编码：浅色底配墨色字、深色底
/// 配浅色字，各档底色在对应主题的正文色下对比度都在 4.5:1 以上（测试兜底）。
/// 中性档在编辑器里跟随主题的 `surfaceContainerHigh`，不用固定色，换主题色
/// 时与卡片、面板同一层次。
library;

import 'package:flutter/material.dart' show Brightness, Color, ColorScheme;
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';

/// 深色主题下的底色：强调色以这个不透明度叠在 `surfaceContainer` 上，
/// 保证浅色正文在任何种子色下都看得清。
const double kDiaryCalloutDarkTint = 0.22;

enum DiaryCalloutTone {
  neutral(
    kDiaryCalloutToneDefault,
    paperBackground: Color(0xFFF1F3F4),
    paperAccent: Color(0xFF9AA0A6),
    darkAccent: Color(0xFFBDC1C6),
  ),
  yellow(
    kDiaryCalloutToneYellow,
    paperBackground: Color(0xFFFFF4D6),
    paperAccent: Color(0xFFF2B200),
    darkAccent: Color(0xFFFFD54F),
  ),
  green(
    kDiaryCalloutToneGreen,
    paperBackground: Color(0xFFE6F4EA),
    paperAccent: Color(0xFF34A853),
    darkAccent: Color(0xFF81C995),
  ),
  blue(
    kDiaryCalloutToneBlue,
    paperBackground: Color(0xFFE8F0FE),
    paperAccent: Color(0xFF4285F4),
    darkAccent: Color(0xFF8AB4F8),
  ),
  red(
    kDiaryCalloutToneRed,
    paperBackground: Color(0xFFFCE8E6),
    paperAccent: Color(0xFFEA4335),
    darkAccent: Color(0xFFF28B82),
  ),
  purple(
    kDiaryCalloutTonePurple,
    paperBackground: Color(0xFFF3E8FD),
    paperAccent: Color(0xFFA142F4),
    darkAccent: Color(0xFFC58AF9),
  );

  const DiaryCalloutTone(
    this.id, {
    required this.paperBackground,
    required this.paperAccent,
    required this.darkAccent,
  });

  /// 写进 `data.tone` 的值（与 [kDiaryCalloutTones] 一一对应）。
  final String id;

  /// 浅色主题与导出纸面上的底色。
  final Color paperBackground;

  /// 浅色主题与导出纸面上的强调色（色条、色点）。
  final Color paperAccent;

  /// 深色主题下的强调色；底色由它按 [kDiaryCalloutDarkTint] 叠出。
  final Color darkAccent;

  /// 由块数据里的原值解析；缺省与认不出的值按中性档。
  static DiaryCalloutTone fromId(Object? raw) {
    for (final tone in values) {
      if (tone.id == raw) return tone;
    }
    return neutral;
  }

  /// 当前主题下的底色。中性档跟随主题层次；其余档浅色用纸面底色，深色把
  /// 强调色淡淡叠在 `surfaceContainer` 上。
  Color background(ColorScheme scheme) {
    if (this == neutral) return scheme.surfaceContainerHigh;
    return scheme.brightness == Brightness.dark
        ? Color.alphaBlend(
            darkAccent.withValues(alpha: kDiaryCalloutDarkTint),
            scheme.surfaceContainer,
          )
        : paperBackground;
  }

  /// 当前主题下的强调色。
  Color accent(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark ? darkAccent : paperAccent;
}
