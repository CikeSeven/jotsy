import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

/// 日历的 Expressive 双行页头。月份控制单独成行，避免窄屏或英文标题
/// 与居中的月份导航重叠。仅组合 UI，月份切换与选日仍由调用方负责。
class CalendarHeader extends StatelessWidget {
  const CalendarHeader({
    super.key,
    required this.title,
    required this.onJumpToToday,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onPickDate,
  });

  static const double contentHeight = 112;

  final String title;
  final VoidCallback onJumpToToday;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top,
            16,
            0,
          ),
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.autoT0183,
                        style: theme.textTheme.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: l10n.autoT0180,
                      onPressed: onJumpToToday,
                      icon: const FaIcon(
                        FontAwesomeIcons.calendarDay,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: l10n.autoT0184,
                      onPressed: onPreviousMonth,
                      icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: onPickDate,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.autoT0185,
                      onPressed: onNextMonth,
                      icon: const FaIcon(FontAwesomeIcons.angleRight, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
