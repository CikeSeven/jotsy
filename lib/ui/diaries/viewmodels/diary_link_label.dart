import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../models/time_capsule.dart';
import 'diary_card_view_data.dart';

/// 链接到这篇日记时写进正文的文字（行内链接）与卡片的标题快照。
///
/// 依次取：标题；摘要的前 [kDiaryLinkLabelPreviewLength] 个字（超出加省略号）；
/// “某月某日的日记”。未解封的时间胶囊不取摘要——正文还没到能看的时候，
/// 链接文字会留在另一篇日记里。
String diaryLinkLabel(
  AppLocalizations l10n,
  Diary diary, {
  required DateTime now,
}) {
  final title = diary.title.trim();
  if (title.isNotEmpty) return title;
  final sealed = TimeCapsuleState.fromFields(
    lockedAt: diary.capsuleLockedAt,
    unlockAt: diary.capsuleUnlockAt,
    now: now,
  ).isLocked;
  if (!sealed) {
    final preview = DiaryCardViewData.of(diary).previewText.trim();
    if (preview.isNotEmpty) {
      final runes = preview.runes;
      return runes.length <= kDiaryLinkLabelPreviewLength
          ? preview
          : '${String.fromCharCodes(runes.take(kDiaryLinkLabelPreviewLength))}…';
    }
  }
  return l10n.diaryLinkUntitled(
    DateFormat.MMMd(l10n.localeName).format(diary.createdAt),
  );
}

/// 没有标题时摘要取用的字数。
const int kDiaryLinkLabelPreviewLength = 20;
