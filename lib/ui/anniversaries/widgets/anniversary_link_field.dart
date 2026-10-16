import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../diaries/viewmodels/diary_card_view_data.dart';
import '../providers/anniversary_providers.dart';
import 'anniversary_diary_picker.dart';

/// 编辑页的“关联日记”一行：显示所关联日记的标题（未关联为“不关联”），点按
/// 打开选择面板。外观与日期行一致（输入框底色与圆角）。
class AnniversaryLinkField extends ConsumerWidget {
  const AnniversaryLinkField({
    super.key,
    required this.date,
    required this.diaryId,
    required this.onChanged,
  });

  final DateTime date;
  final String? diaryId;
  final ValueChanged<String?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final pick = await showAnniversaryDiaryPicker(
      context,
      date: date,
      selectedDiaryId: diaryId,
    );
    if (pick != null) {
      onChanged(pick.diaryId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final diaryId = this.diaryId;
    final String label;
    if (diaryId == null) {
      label = l10n.anniversaryLinkNone;
    } else {
      final diary = ref.watch(anniversaryLinkedDiaryProvider(diaryId)).value;
      if (diary == null) {
        label = l10n.anniversaryLinkMissing;
      } else {
        final title = diary.diary.title.trim();
        final preview = DiaryCardViewData.of(diary.diary).previewText;
        label = title.isNotEmpty
            ? title
            : preview.isNotEmpty
            ? preview
            : l10n.autoT0065;
      }
    }
    return Material(
      color:
          theme.inputDecorationTheme.fillColor ??
          colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadii.input),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _pick(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.m + 2,
          ),
          child: Row(
            children: <Widget>[
              FaIcon(
                diaryId == null
                    ? FontAwesomeIcons.linkSlash
                    : FontAwesomeIcons.bookOpen,
                size: 15,
                color: diaryId == null
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: diaryId == null
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                  ),
                ),
              ),
              FaIcon(
                FontAwesomeIcons.angleRight,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
