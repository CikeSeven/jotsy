import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'diary_editor_styles.dart';

/// 行首标记（列表圆点、序号、待办复选框）的几何：与正文首行对齐所需的
/// 高度、字形中心与行距，以及按正文字号等比换算的设计尺寸。列宽同时是
/// 子块缩进（见 `diaryTextBlockConfiguration`）。

/// 字形视觉中心在基线上方的高度（em）。实测 HarmonyOS Sans SC 的汉字墨迹
/// 中心为 0.36–0.39em、拉丁大写字母为 0.365em，取 0.37em 兼顾中英文；
/// 其他中文字体的字面框同为基线下 0.12em 至上 0.88em，中心相近。
const double _kGlyphCenterEm = 0.37;

/// 行首标记的几何，由正文样式按编辑器的行高规则（[kDiaryTextHeightBehavior]）
/// 实测得出，保证与上游 `AppFlowyRichText` 的首行完全一致。
///
/// 为什么不按“字号 × 行距”居中：上游不给首行上方加行距
/// （`applyHeightToFirstAscent: false`），单行文字只有字体自然高度，基线
/// 贴近顶部；按“字号 × 行距”算出的格子比文字高，标记居中后整体偏低约
/// 3dp，还会把列表行撑得比普通段落高。
@immutable
class DiaryMarkerMetrics {
  const DiaryMarkerMetrics({
    required this.em,
    required this.lineExtent,
    required this.glyphCenter,
    required this.halfLeading,
    required this.scaler,
  });

  /// 用与正文相同的样式、缩放与行高规则排一行汉字，读出首行高度与基线。
  /// 用汉字测量：正文以中文为主，用户字体缺字时汉字回落到的字体同样决定
  /// 首行的高度。
  factory DiaryMarkerMetrics.measure(TextStyle body, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: '中', style: body),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      textHeightBehavior: kDiaryTextHeightBehavior,
      maxLines: 1,
    )..layout();
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final em = scaler.scale(body.fontSize ?? 16);
    final metrics = DiaryMarkerMetrics(
      em: em,
      lineExtent: painter.height,
      glyphCenter: baseline - em * _kGlyphCenterEm,
      halfLeading: math.max(0, (em * (body.height ?? 0) - painter.height) / 2),
      scaler: scaler,
    );
    painter.dispose();
    return metrics;
  }

  /// 缩放后的正文字号。
  final double em;

  /// 单行文字的高度，即标记格的高度。
  final double lineExtent;

  /// 首行字形中心到文字顶部的距离。
  final double glyphCenter;

  /// 单行文字比一个整行（字号 × 行距）少掉的半个行距，即上游在首行上方、
  /// 末行下方各裁掉的部分；行距小于字体自然高度时为 0。
  final double halfLeading;

  /// 正文实际使用的字体缩放（[diaryEditorTextScaler]），序号沿用它。
  final TextScaler scaler;

  /// 把 16sp 正文下的设计尺寸按当前字号等比换算。
  double dp(double value) => value * em / 16;

  /// 行首标记列宽（16sp 时 28dp）：无序、有序与待办共用，三种列表的正文
  /// 起点对齐；子块缩进同为这个宽度，嵌套的标记落在上一级的正文起点下。
  double get width => dp(_kColumnWidth);

  /// 不排版、只按正文字号算出的列宽（同 [width]），供只需要子块缩进的
  /// 段落把手层使用。
  static double columnWidth(double fontSize, TextScaler scaler) =>
      _kColumnWidth * scaler.scale(fontSize) / 16;

  static const double _kColumnWidth = 28;
}
