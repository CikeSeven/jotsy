import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_glass_field.dart';
import '../../app_surface/widgets/on_glass.dart';
import '../../calendar/viewmodels/calendar_lunar_day.dart';
import '../../calendar/widgets/calendar_month_grid.dart';
import '../controllers/explore_module_actions.dart';
import '../models/explore_module_config.dart';
import '../models/explore_module_data.dart';
import '../models/explore_module_options.dart';
import '../viewmodels/explore_labels.dart';
import '../widgets/explore_appearance_scope.dart';
import '../widgets/explore_shared_widgets.dart';

/// 今日问候：按时段问候、日期与星期（可带农历、节日与节气）、今天写了
/// 多少，以及每日写作提示与“写日记”按钮。
///
/// 写作提示按一年中的第几天轮换，“换一个”只在本卡内存里往后挪，不落盘；
/// 跨天时回到当天那条。
class ExploreGreetingCard extends StatefulWidget {
  const ExploreGreetingCard({
    super.key,
    required this.config,
    required this.data,
    required this.now,
  });

  final ExploreModuleConfig config;
  final ExploreGreetingData data;
  final DateTime now;

  @override
  State<ExploreGreetingCard> createState() => _ExploreGreetingCardState();
}

class _ExploreGreetingCardState extends State<ExploreGreetingCard> {
  int _promptShift = 0;

  int get _dayOfYear => DateTime.utc(
    widget.now.year,
    widget.now.month,
    widget.now.day,
  ).difference(DateTime.utc(widget.now.year)).inDays;

  @override
  void didUpdateWidget(ExploreGreetingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.now, widget.now)) _promptShift = 0;
  }

  String _dateLine(AppLocalizations l10n) {
    final now = widget.now;
    final parts = <String>[DateFormat.MMMEd(l10n.localeName).format(now)];
    final lunarMode = widget.config.choice(ExploreOptions.greetingLunar);
    if (CalendarMonthGrid.showsLunar(lunarMode, l10n.localeName)) {
      final lunar = CalendarLunarDay.of(now);
      parts.add(lunar.date);
      final special = lunar.festivals.isNotEmpty
          ? lunar.festivals.first
          : lunar.term;
      if (special != null) parts.add(special);
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = ExploreAppearanceScope.of(context);
    final actions = ExploreActionsScope.of(context);
    final data = widget.data;
    final hour = widget.now.hour;
    final prompts = ExploreLabels.prompts(l10n);
    final prompt = prompts[(_dayOfYear + _promptShift) % prompts.length];
    final showPrompt = widget.config.toggle(ExploreOptions.greetingPrompt);
    final showWrite = widget.config.toggle(ExploreOptions.greetingWrite);
    final icon = switch (hour) {
      >= 5 && < 11 => FontAwesomeIcons.mugHot,
      >= 11 && < 18 => FontAwesomeIcons.cloudSun,
      _ => FontAwesomeIcons.moon,
    };
    final wrote = data.todayEntries > 0;
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      ExploreLabels.greeting(l10n, hour),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dateLine(l10n),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: look.accentContainerOf(scheme),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FaIcon(
                  icon,
                  size: 18,
                  color: look.onAccentContainerOf(scheme),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              FaIcon(
                wrote ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.feather,
                size: 13,
                color: wrote ? look.accentOf(scheme) : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  wrote
                      ? l10n.exploreGreetingToday(
                          data.todayEntries,
                          look.formatNumber(data.todayWords, l10n.localeName),
                        )
                      : l10n.exploreGreetingTodayEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (showPrompt) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 4, 10),
              // 玻璃卡片里改为半透明凹槽色，不留一块实色补丁。
              decoration: BoxDecoration(
                color: OnGlass.of(context)
                    ? OnGlass.wellColor(scheme)
                    : theme.brightness == Brightness.light
                    ? scheme.surfaceContainerLow
                    : scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  FaIcon(
                    FontAwesomeIcons.quoteLeft,
                    size: 12,
                    color: look.accentOf(scheme),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      prompt,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.exploreGreetingNextPrompt,
                    onPressed: () => setState(() => _promptShift += 1),
                    visualDensity: VisualDensity.compact,
                    icon: const FaIcon(FontAwesomeIcons.rotateRight, size: 14),
                  ),
                ],
              ),
            ),
          ],
          if (showWrite) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              style: AppGlassField.tonalButtonStyle(context),
              onPressed: actions.createDiary,
              icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 14),
              label: Text(l10n.exploreGreetingWrite),
            ),
          ],
        ],
      ),
    );
  }
}
