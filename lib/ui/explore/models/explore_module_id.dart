// 探索页卡片的身份与分组。持久化存的是枚举名（`Enum.name`），重命名枚举值
// 等同于改存储格式：旧值会被当作认不出的卡片原样保留，而新名字的卡片补到
// 末尾。

/// 卡片所属的分组（编辑页里的小标）。
enum ExploreModuleGroup { recall, stats, life, linked }

/// 探索页的一张卡片。
enum ExploreModuleId {
  greeting,
  onThisDay,
  randomMemory,
  recap,
  milestones,
  overview,
  heatmap,
  rhythm,
  habits,
  moodTrend,
  moodShare,
  energy,
  tags,
  media,
  places,
  weather,
  anniversaries,
  capsules,
  notebooks,
  drafts,
  comments;

  /// 按枚举名查找；认不出时为 null。
  static ExploreModuleId? byName(Object? raw) {
    if (raw is! String) return null;
    for (final id in values) {
      if (id.name == raw) return id;
    }
    return null;
  }
}

/// 宽窗口下卡片占的宽度：[auto] 取这张卡的默认（见 `ExploreModuleSpec`），
/// [full] 占整行，[half] 占一列。窄窗口一律单列，不看它。
enum ExploreModuleSpan { auto, full, half }
