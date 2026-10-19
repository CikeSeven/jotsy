import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations_gen.dart';
import 'notebook_view.dart';

/// 书架角标对应的状态：上锁优先于隐藏，再是智能（一个本子只显示一个角标）。
enum NotebookBadge { locked, hidden, smart }

NotebookBadge? notebookBadgeFor(
  NotebookKind kind,
  NotebookVisibility visibility,
) {
  if (kind == NotebookKind.manual) {
    return switch (visibility) {
      NotebookVisibility.locked => NotebookBadge.locked,
      NotebookVisibility.hidden => NotebookBadge.hidden,
      NotebookVisibility.normal => null,
    };
  }
  return NotebookBadge.smart;
}

String notebookBadgeLabel(AppLocalizations l10n, NotebookBadge badge) =>
    switch (badge) {
      NotebookBadge.locked => l10n.notebookStateLocked,
      NotebookBadge.hidden => l10n.notebookStateHidden,
      NotebookBadge.smart => l10n.notebookStateSmart,
    };

/// 管理页行副标题：“23 篇 · 置顶 · 上锁”。[count] 为 null（智能本暂不统计）
/// 时不写篇数；什么都没有时为空字符串。
String notebookRowSubtitle(
  AppLocalizations l10n,
  NotebookView notebook,
  int? count,
) {
  final badge = notebookBadgeFor(notebook.kind, notebook.visibility);
  return <String>[
    if (count != null) l10n.notebookEntryCount(count),
    if (notebook.isPinned) l10n.notebookStatePinned,
    if (badge != null) notebookBadgeLabel(l10n, badge),
    if (notebook.isClosed) l10n.notebookStateClosed,
  ].join(' · ');
}

String notebookSortLabel(AppLocalizations l10n, NotebookSort sort) =>
    switch (sort) {
      NotebookSort.createdDesc => l10n.notebookSortCreatedDesc,
      NotebookSort.createdAsc => l10n.notebookSortCreatedAsc,
      NotebookSort.updatedDesc => l10n.notebookSortUpdatedDesc,
      NotebookSort.book => l10n.notebookSortBook,
    };

/// 排序选项下的说明，没有说明的为 null。
String? notebookSortDescription(AppLocalizations l10n, NotebookSort sort) =>
    switch (sort) {
      NotebookSort.createdAsc => l10n.notebookSortCreatedAscHint,
      NotebookSort.book => l10n.notebookSortBookHint,
      _ => null,
    };

String notebookVisibilityLabel(
  AppLocalizations l10n,
  NotebookVisibility visibility,
) => switch (visibility) {
  NotebookVisibility.normal => l10n.notebookPrivacyNormal,
  NotebookVisibility.hidden => l10n.notebookPrivacyHidden,
  NotebookVisibility.locked => l10n.notebookPrivacyLocked,
};

String? notebookVisibilityDescription(
  AppLocalizations l10n,
  NotebookVisibility visibility,
) => switch (visibility) {
  NotebookVisibility.normal => null,
  NotebookVisibility.hidden => l10n.notebookPrivacyHiddenHint,
  NotebookVisibility.locked => l10n.notebookPrivacyLockedHint,
};

/// 写作目标周期的按钮文字：每天 / 每周 / 每月。
String notebookGoalPeriodLabel(
  AppLocalizations l10n,
  NotebookGoalPeriod period,
) => switch (period) {
  NotebookGoalPeriod.day => l10n.notebookGoalPeriodDay,
  NotebookGoalPeriod.week => l10n.notebookGoalPeriodWeek,
  NotebookGoalPeriod.month => l10n.notebookGoalPeriodMonth,
};

/// 目标原话：“每周写 3 篇”。
String notebookGoalSummary(
  AppLocalizations l10n,
  NotebookGoalPeriod period,
  int target,
) => switch (period) {
  NotebookGoalPeriod.day => l10n.notebookGoalSummaryDay(target),
  NotebookGoalPeriod.week => l10n.notebookGoalSummaryWeek(target),
  NotebookGoalPeriod.month => l10n.notebookGoalSummaryMonth(target),
};

/// 当前周期的进度：“本周 2 / 3 篇”，已达成时“本周已完成 ✓”。
String notebookGoalProgressLabel(
  AppLocalizations l10n,
  NotebookGoalPeriod period, {
  required int current,
  required int target,
}) {
  if (current >= target) {
    return switch (period) {
      NotebookGoalPeriod.day => l10n.notebookGoalMetDay,
      NotebookGoalPeriod.week => l10n.notebookGoalMetWeek,
      NotebookGoalPeriod.month => l10n.notebookGoalMetMonth,
    };
  }
  return switch (period) {
    NotebookGoalPeriod.day => l10n.notebookGoalProgressDay(current, target),
    NotebookGoalPeriod.week => l10n.notebookGoalProgressWeek(current, target),
    NotebookGoalPeriod.month => l10n.notebookGoalProgressMonth(current, target),
  };
}

/// 连续达成：“连续达成 4 周”；为 0 时 null（不写）。
String? notebookGoalStreakLabel(
  AppLocalizations l10n,
  NotebookGoalPeriod period,
  int streak,
) {
  if (streak <= 0) return null;
  return switch (period) {
    NotebookGoalPeriod.day => l10n.notebookGoalStreakDay(streak),
    NotebookGoalPeriod.week => l10n.notebookGoalStreakWeek(streak),
    NotebookGoalPeriod.month => l10n.notebookGoalStreakMonth(streak),
  };
}

/// 头部卡片的目标行：“本周 2 / 3 篇 · 连续达成 4 周”。
String notebookGoalLine(
  AppLocalizations l10n,
  NotebookGoalPeriod period, {
  required int current,
  required int target,
  required int streak,
}) {
  final streakLabel = notebookGoalStreakLabel(l10n, period, streak);
  return <String>[
    notebookGoalProgressLabel(l10n, period, current: current, target: target),
    ?streakLabel,
  ].join(' · ');
}
