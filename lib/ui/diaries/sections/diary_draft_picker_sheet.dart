import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../viewmodels/diary_draft_list_item.dart';
import '../widgets/diary_draft_tile.dart';

/// 草稿选择面板的结果：续写某一份、打开草稿箱，或新建空白。
sealed class DiaryDraftPick {
  const DiaryDraftPick();
}

/// 新建空白日记；已有草稿都留在草稿箱。
final class DiaryDraftPickBlank extends DiaryDraftPick {
  const DiaryDraftPickBlank();
}

/// 续写 [draftId] 这一份草稿。
final class DiaryDraftPickDraft extends DiaryDraftPick {
  const DiaryDraftPickDraft(this.draftId);

  final String draftId;
}

/// 打开草稿箱页查看与管理全部草稿。
final class DiaryDraftPickAll extends DiaryDraftPick {
  const DiaryDraftPickAll();
}

/// 已有草稿时点“新建”弹出的面板：最近编辑的几份草稿（点按即续写）、
/// “查看全部草稿”与“新建空白”。只负责挑选，打开哪个页面由
/// `runDiaryCreateEntryFlow` 决定；下滑或点空白处关闭返回 null，什么也不做。
///
/// [recent] 已按最近编辑排序、最多 [maxRecent] 份；[total] 为草稿总数。
Future<DiaryDraftPick?> showDiaryDraftPickerSheet(
  BuildContext context, {
  required List<DiaryDraftListItem> recent,
  required int total,
}) {
  return showModalBottomSheet<DiaryDraftPick>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) {
      return _DiaryDraftPickerBody(recent: recent, total: total);
    },
  );
}

/// 面板里最多列出的草稿份数；更多的在草稿箱里。
const int maxRecentDraftsInPicker = 3;

class _DiaryDraftPickerBody extends StatelessWidget {
  const _DiaryDraftPickerBody({required this.recent, required this.total});

  final List<DiaryDraftListItem> recent;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final navigator = Navigator.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                0,
                AppSpacing.xs,
                AppSpacing.m,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.diaryDraftPickerTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            for (final item in recent) ...<Widget>[
              DiaryDraftTile(
                key: ValueKey<String>('draft_pick_${item.draftId}'),
                item: item,
                compact: true,
                onTap: () => navigator.pop(DiaryDraftPickDraft(item.draftId)),
              ),
              const SizedBox(height: AppSpacing.s),
            ],
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
              ),
              leading: FaIcon(
                FontAwesomeIcons.filePen,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              title: Text(l10n.diaryDraftPickerViewAll(total)),
              trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
              onTap: () => navigator.pop(const DiaryDraftPickAll()),
            ),
            const SizedBox(height: AppSpacing.s),
            FilledButton.icon(
              onPressed: () => navigator.pop(const DiaryDraftPickBlank()),
              icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
              label: Text(l10n.diaryDraftPickerNewBlank),
            ),
          ],
        ),
      ),
    );
  }
}
