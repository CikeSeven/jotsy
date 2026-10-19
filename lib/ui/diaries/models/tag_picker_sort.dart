/// 发布面板标签子页的排序方式；枚举名即持久化值（设置项与备份中的
/// `tagPickerSortRaw`）。
enum TagPickerSort {
  /// 默认排序：用户在“标签管理”里拖出的顺序（`tagListProvider` 的顺序）。
  custom,

  /// 按字母：汉字按拼音归入 A–Z，列表右侧出现字母索引条。
  alphabetical;

  /// 未设置或认不出的值回到默认排序。
  static TagPickerSort fromName(String? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return custom;
  }
}
