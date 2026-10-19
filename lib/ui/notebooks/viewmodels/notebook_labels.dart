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
