import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/diary_template.dart';
import '../viewmodels/diary_template_accent.dart';

/// 模板图标对应的 FontAwesome 图标。
FaIconData diaryTemplateIconData(DiaryTemplateIcon icon) => switch (icon) {
  DiaryTemplateIcon.penNib => FontAwesomeIcons.penNib,
  DiaryTemplateIcon.sun => FontAwesomeIcons.sun,
  DiaryTemplateIcon.moon => FontAwesomeIcons.moon,
  DiaryTemplateIcon.cloudMoon => FontAwesomeIcons.cloudMoon,
  DiaryTemplateIcon.heart => FontAwesomeIcons.heart,
  DiaryTemplateIcon.handHoldingHeart => FontAwesomeIcons.handHoldingHeart,
  DiaryTemplateIcon.circleQuestion => FontAwesomeIcons.circleQuestion,
  DiaryTemplateIcon.calendarWeek => FontAwesomeIcons.calendarWeek,
  DiaryTemplateIcon.calendarDays => FontAwesomeIcons.calendarDays,
  DiaryTemplateIcon.calendarCheck => FontAwesomeIcons.calendarCheck,
  DiaryTemplateIcon.faceSmile => FontAwesomeIcons.faceSmile,
  DiaryTemplateIcon.brain => FontAwesomeIcons.brain,
  DiaryTemplateIcon.plane => FontAwesomeIcons.plane,
  DiaryTemplateIcon.mountainSun => FontAwesomeIcons.mountainSun,
  DiaryTemplateIcon.personHiking => FontAwesomeIcons.personHiking,
  DiaryTemplateIcon.bookOpen => FontAwesomeIcons.bookOpen,
  DiaryTemplateIcon.film => FontAwesomeIcons.film,
  DiaryTemplateIcon.personRunning => FontAwesomeIcons.personRunning,
  DiaryTemplateIcon.dumbbell => FontAwesomeIcons.dumbbell,
  DiaryTemplateIcon.briefcase => FontAwesomeIcons.briefcase,
  DiaryTemplateIcon.envelope => FontAwesomeIcons.envelope,
  DiaryTemplateIcon.lightbulb => FontAwesomeIcons.lightbulb,
  DiaryTemplateIcon.mugHot => FontAwesomeIcons.mugHot,
  DiaryTemplateIcon.seedling => FontAwesomeIcons.seedling,
  DiaryTemplateIcon.feather => FontAwesomeIcons.feather,
  DiaryTemplateIcon.listCheck => FontAwesomeIcons.listCheck,
  DiaryTemplateIcon.clipboardList => FontAwesomeIcons.clipboardList,
  DiaryTemplateIcon.star => FontAwesomeIcons.star,
};

/// 模板图标徽章：强调色换算出的容器色圆底 + 图标（见
/// [diaryTemplateAccentColors]）。
class DiaryTemplateIconBadge extends StatelessWidget {
  const DiaryTemplateIconBadge({
    super.key,
    required this.icon,
    required this.accent,
    this.size = 40,
  });

  final DiaryTemplateIcon icon;
  final int? accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = diaryTemplateAccentColors(
      accent,
      Theme.of(context).colorScheme,
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.container,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: FaIcon(
              diaryTemplateIconData(icon),
              size: size * 0.42,
              color: colors.onContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// “推荐”“已隐藏”这类微胶囊：primary 低透明度底 + primary 小字。
class DiaryTemplateBadge extends StatelessWidget {
  const DiaryTemplateBadge({
    super.key,
    required this.label,
    this.muted = false,
  });

  final String label;

  /// 弱化（已隐藏）：用 onSurfaceVariant 代替 primary。
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = muted
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
