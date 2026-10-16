import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../diaries/viewmodels/diary_card_view_data.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../controllers/anniversary_navigation.dart';
import '../providers/anniversary_providers.dart';

/// 关联日记面板的选择结果；[diaryId] 为 null 表示“不关联”。关闭面板时
/// 返回 null（不是“不关联”），调用方保持原样。
class AnniversaryDiaryPick {
  const AnniversaryDiaryPick(this.diaryId);

  final String? diaryId;
}

/// 选一篇日记关联到纪念日：首项“不关联”，其后是所选日期前后 7 天写下的
/// 日记（未解封的时间胶囊不列出）。只负责选择，写库由调用方完成。
Future<AnniversaryDiaryPick?> showAnniversaryDiaryPicker(
  BuildContext context, {
  required DateTime date,
  String? selectedDiaryId,
}) {
  return showModalBottomSheet<AnniversaryDiaryPick>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) =>
        _DiaryPickerSheet(date: date, selectedDiaryId: selectedDiaryId),
  );
}

class _DiaryPickerSheet extends ConsumerWidget {
  const _DiaryPickerSheet({required this.date, required this.selectedDiaryId});

  final DateTime date;
  final String? selectedDiaryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final candidates = ref.watch(anniversaryDiaryCandidatesProvider(date));
    final diaries = candidates.value
        ?.where((DiaryWithTags diary) => isOpenableDiary(diary))
        .toList(growable: false);

    Widget check(bool selected) => selected
        ? FaIcon(
            FontAwesomeIcons.solidCircleCheck,
            size: 18,
            color: colorScheme.primary,
          )
        : const SizedBox(width: 18);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xs,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.anniversaryFieldLink,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.s,
              ),
              child: Text(
                l10n.anniversaryPickerHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s,
                  0,
                  AppSpacing.s,
                  AppSpacing.l,
                ),
                children: <Widget>[
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: FaIcon(
                      FontAwesomeIcons.linkSlash,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    title: Text(l10n.anniversaryLinkNone),
                    trailing: check(selectedDiaryId == null),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(const AnniversaryDiaryPick(null)),
                  ),
                  if (diaries == null)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: DelayedLoadingIndicator(),
                    )
                  else if (diaries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: Text(
                        l10n.anniversaryPickerEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    for (final diary in diaries)
                      _CandidateTile(
                        diary: diary,
                        trailing: check(diary.diary.diaryId == selectedDiaryId),
                        onTap: () => Navigator.of(
                          context,
                        ).pop(AnniversaryDiaryPick(diary.diary.diaryId)),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.diary,
    required this.trailing,
    required this.onTap,
  });

  final DiaryWithTags diary;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final title = diary.diary.title.trim();
    final preview = DiaryCardViewData.of(diary.diary).previewText;
    final createdAt = diary.diary.createdAt.toLocal();
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title.isEmpty ? (preview.isEmpty ? l10n.autoT0065 : preview) : title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: title.isEmpty ? null : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        DateFormat.MMMEd(l10n.localeName).format(createdAt),
        maxLines: 1,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
