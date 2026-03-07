import '../../l10n/app_localizations.dart';

/// 统一的“更新时间”展示格式化工具。
///
/// 规则：
/// - < 1 分钟：刚刚
/// - < 1 小时：X 分钟前
/// - < 24 小时：X 小时前
/// - < 7 天：X 天前
/// - >= 7 天：同年显示月日，跨年显示完整日期
class RelativeTimeFormatter {
  const RelativeTimeFormatter._();

  static String formatUpdatedAt({
    required DateTime updatedAt,
    required DateTime now,
    required AppLocalizations l10n,
    int recentDaysThreshold = 7,
  }) {
    final localUpdatedAt = updatedAt.toLocal();
    final localNow = now.toLocal();
    final diff = localNow.difference(localUpdatedAt);

    // 未来时间或极小时间差统一显示“刚刚”。
    if (diff.isNegative || diff.inMinutes < 1) {
      return l10n.timeJustNow;
    }
    if (diff.inHours < 1) {
      return l10n.timeMinutesAgo(diff.inMinutes);
    }
    if (diff.inDays < 1) {
      return l10n.timeHoursAgo(diff.inHours);
    }
    if (diff.inDays < recentDaysThreshold) {
      return l10n.timeDaysAgo(diff.inDays);
    }

    if (localUpdatedAt.year == localNow.year) {
      return l10n.formatMonthDay(localUpdatedAt);
    }
    return l10n.formatFullDate(localUpdatedAt);
  }
}

