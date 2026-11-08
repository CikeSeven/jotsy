// AI 对话里卡片与时间线的“领域色”（DESIGN §5.29）：只取主题的语义容器色，
// 明暗主题自动适配，不写死任何颜色、不用渐变。
//
// - 日记 `primaryContainer`；
// - 日记本、标签（整理）`tertiaryContainer`；
// - 待办、纪念日、日历 `secondaryContainer`；
// - 应用与设置 `surfaceContainerHighest`（中性）。
//
// [AiTintBadge] 是卡片与时间线左侧的圆角方块 / 圆形徽标：容器色底 + 对应
// on 色图标；[muted]（已撤销、已取消、目标不存在）时退成中性灰，[danger]
// （失败）为 `errorContainer`。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/ai_tool_subject.dart';
import '../tools/ai_destinations.dart';
import '../tools/ai_tool.dart';

/// 色调的底色与前景色。
({Color fill, Color on}) aiTintColors(ColorScheme colors, AiTint tint) =>
    switch (tint) {
      AiTint.primary => (
        fill: colors.primaryContainer,
        on: colors.onPrimaryContainer,
      ),
      AiTint.secondary => (
        fill: colors.secondaryContainer,
        on: colors.onSecondaryContainer,
      ),
      AiTint.tertiary => (
        fill: colors.tertiaryContainer,
        on: colors.onTertiaryContainer,
      ),
      AiTint.neutral => (
        fill: colors.surfaceContainerHighest,
        on: colors.onSurfaceVariant,
      ),
    };

AiTint aiGroupTint(AiToolGroup? group) => switch (group) {
  AiToolGroup.diaries => AiTint.primary,
  AiToolGroup.organize => AiTint.tertiary,
  AiToolGroup.calendar => AiTint.secondary,
  AiToolGroup.navigation => AiTint.primary,
  AiToolGroup.app || AiToolGroup.settings || null => AiTint.neutral,
};

FaIconData aiGroupIcon(AiToolGroup? group) => switch (group) {
  AiToolGroup.app => FontAwesomeIcons.circleInfo,
  AiToolGroup.diaries => FontAwesomeIcons.bookOpen,
  AiToolGroup.organize => FontAwesomeIcons.tags,
  AiToolGroup.calendar => FontAwesomeIcons.calendarDays,
  AiToolGroup.settings => FontAwesomeIcons.sliders,
  AiToolGroup.navigation => FontAwesomeIcons.arrowUpRightFromSquare,
  null => FontAwesomeIcons.screwdriverWrench,
};

AiTint aiSubjectTint(AiSubjectKind kind) => switch (kind) {
  AiSubjectKind.diary => AiTint.primary,
  AiSubjectKind.notebook || AiSubjectKind.tag => AiTint.tertiary,
  AiSubjectKind.todo ||
  AiSubjectKind.anniversary ||
  AiSubjectKind.day => AiTint.secondary,
};

FaIconData aiSubjectIcon(AiSubjectKind kind) => switch (kind) {
  AiSubjectKind.diary => FontAwesomeIcons.bookOpen,
  AiSubjectKind.notebook => FontAwesomeIcons.book,
  AiSubjectKind.tag => FontAwesomeIcons.hashtag,
  AiSubjectKind.todo => FontAwesomeIcons.squareCheck,
  AiSubjectKind.anniversary => FontAwesomeIcons.cakeCandles,
  AiSubjectKind.day => FontAwesomeIcons.calendarDay,
};

/// 领域色徽标：[size] 见方，[circle] 为圆形（时间线），否则为
/// `size × 0.32` 圆角的方块（卡片）。
class AiTintBadge extends StatelessWidget {
  const AiTintBadge({
    super.key,
    required this.icon,
    required this.tint,
    this.size = 40,
    this.circle = false,
    this.muted = false,
    this.danger = false,
  });

  final FaIconData icon;
  final AiTint tint;
  final double size;
  final bool circle;
  final bool muted;

  /// 失败：`errorContainer` 底（优先于 [muted]）。
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = danger
        ? (fill: colors.errorContainer, on: colors.onErrorContainer)
        : aiTintColors(colors, muted ? AiTint.neutral : tint);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.fill,
          borderRadius: BorderRadius.circular(circle ? size / 2 : size * 0.32),
        ),
        child: Center(
          child: FaIcon(icon, size: size * 0.4, color: palette.on),
        ),
      ),
    );
  }
}
