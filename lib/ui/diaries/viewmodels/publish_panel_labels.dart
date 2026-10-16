import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:path/path.dart' as path;

/// 面板上封面行的文案：网络图显示完整 URL，本地图只显示文件名，避免路径
/// 过长挤占面板。无封面返回 null。
String? diaryCoverLabel(String? cover) {
  if (cover == null) {
    return null;
  }
  final uri = Uri.tryParse(cover);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return cover;
  }
  return path.basename(cover);
}

/// 解封时刻的显示文本。“只按日期”的胶囊在当天零点解封，只显示日期，不
/// 显示一个用户没选过的 00:00。
String capsuleUnlockText(AppLocalizations l10n, TimeCapsuleSchedule schedule) {
  final unlockAt = schedule.normalizedUnlockAt;
  return schedule.precision == TimeCapsulePrecision.date
      ? l10n.formatFullDate(unlockAt)
      : l10n.formatDateTimeMinute(unlockAt);
}

/// 时间胶囊行的文案。
String timeCapsuleLabel(AppLocalizations l10n, TimeCapsuleSchedule? schedule) {
  if (schedule == null) {
    return l10n.timeCapsuleUnset;
  }
  return l10n.timeCapsuleSet(capsuleUnlockText(l10n, schedule));
}
