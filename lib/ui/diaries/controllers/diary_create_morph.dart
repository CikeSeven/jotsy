import '../../widgets/container_transform/morph_landing.dart';
import '../widgets/diary_card/diary_card.dart' show diaryCardTransitionTag;

/// 新建日记的整页收放（`MorphPageRoute`）在日记页上的起点与落点。
///
/// - 展开：从首页的新建按钮（悬浮 FAB、悬浮底栏旁的方块按钮或宽窗口侧栏
///   的按钮，露在屏上的那一个，标签 [createButton]）展开成编辑页；
/// - 收回（编辑页 / 发布页返回时按结果决定，见 [editorLanding] 与
///   [publishLanding]）：
///   - 发表了：落进日记列表里的新卡片，列表同时让位；
///   - 写了东西没发表（存进草稿箱）：落进顶栏草稿箱的份数角标，角标随后
///     +1；角标不在屏上（刊头已滑走）时退而回到新建按钮；
///   - 什么也没写：回到新建按钮。
abstract final class DiaryCreateMorph {
  /// 首页的新建按钮。
  static const Object createButton = _MorphTag('create_button');

  /// 首页顶栏草稿箱按钮上的份数角标。
  static const Object draftsBadge = _MorphTag('drafts_badge');

  /// 列表里某篇日记卡片的落点标签（与卡片展开同一标签）。
  static Object cardTag(String diaryId) => diaryCardTransitionTag(diaryId);

  /// 新建编辑页返回时的候选落点：[result] 为新日记 id 时（返回时直接发表）
  /// 落进列表；否则 [keepsDraft]（有内容、会留在草稿箱里）时落进草稿箱，
  /// 都没有时回到新建按钮。
  static List<MorphLanding> editorLanding({
    required Object? result,
    required bool keepsDraft,
  }) {
    if (result is String) {
      return <MorphLanding>[MorphLiveLanding(cardTag(result))];
    }
    return <MorphLanding>[
      if (keepsDraft) const MorphAnchorLanding(draftsBadge),
      const MorphAnchorLanding(createButton),
    ];
  }

  /// 发布页返回时的候选落点：带回新日记 id（已发表）时落进列表；发表失败
  /// 退回编辑页时没有候选，照主题转场退场。
  static List<MorphLanding> publishLanding(Object? result) => result is String
      ? <MorphLanding>[MorphLiveLanding(cardTag(result))]
      : const <MorphLanding>[];
}

/// 落点标签：按名字比较，热重载后仍相等。
class _MorphTag {
  const _MorphTag(this.name);

  final String name;

  @override
  bool operator ==(Object other) => other is _MorphTag && other.name == name;

  @override
  int get hashCode => Object.hash(_MorphTag, name);

  @override
  String toString() => 'DiaryCreateMorph.$name';
}
