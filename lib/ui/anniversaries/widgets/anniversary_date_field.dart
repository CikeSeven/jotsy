import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../viewmodels/anniversary_rule.dart';

/// 编辑页的日期选择行：点按打开系统日期选择器。
///
/// 显示公历日期与星期，下方附农历日期（中文界面总是显示；英文界面只在
/// 选了农历每年时显示，那时农历才决定以后落在哪天）。外观与输入框同一套
/// 填充底色与圆角，视觉上是一个“输入框”。
class AnniversaryDateField extends StatelessWidget {
  const AnniversaryDateField({
    super.key,
    required this.date,
    required this.onChanged,
    this.showLunar = true,
  });

  static final DateTime firstDate = DateTime(1900);
  static final DateTime lastDate = DateTime(2100, 12, 31);

  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final bool showLunar;

  Future<void> _pick(BuildContext context) async {
    final l10n = context.l10n;
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: Localizations.localeOf(context),
      helpText: l10n.anniversaryFieldDate,
      cancelText: l10n.commonCancel,
      confirmText: l10n.commonConfirm,
    );
    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // 底色取主题的输入框填充：“控件”为玻璃时主题已换成玻璃底色
    // （AppGlassControlsTheme）；描边同理补上玻璃描边，与旁边的输入框一致。
    final fill =
        theme.inputDecorationTheme.fillColor ??
        colorScheme.surfaceContainerHighest;
    final glassBorder = AppGlassField.of(context)?.border;
    final lunar = LunarYmd.of(date);
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        side: glassBorder ?? BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _pick(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.m,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      DateFormat.yMMMEd(l10n.localeName).format(date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (showLunar)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          l10n.anniversaryLunarYearDate(
                            lunar.yearName,
                            lunar.monthDayName,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              FaIcon(
                FontAwesomeIcons.calendarDays,
                size: 16,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
