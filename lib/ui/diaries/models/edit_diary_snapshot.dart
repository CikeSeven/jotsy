/// 一次编辑保存的不可变快照。正文与标签必须随输入一起捕获，避免异步写入
/// 完成后误把期间的新输入当作已经保存。
class EditDiarySnapshot {
  EditDiarySnapshot({
    required this.title,
    required this.contentDocJson,
    required this.contentText,
    required this.cover,
    required this.metadataJson,
    required Set<int> selectedTagIds,
    required this.createdAt,
    List<String>? notebookIds,
  }) : selectedTagIds = Set<int>.unmodifiable(selectedTagIds),
       notebookIds = notebookIds == null
           ? null
           : List<String>.unmodifiable(notebookIds);

  final String title;
  final String contentDocJson;
  final String contentText;
  final String? cover;
  final String metadataJson;
  final Set<int> selectedTagIds;

  /// 发表时间（created_at）；null 表示沿用库中原值。
  final DateTime? createdAt;

  /// 所在日记本；null 表示用户没改过，保存时不动关联。
  final List<String>? notebookIds;

  @override
  bool operator ==(Object other) =>
      other is EditDiarySnapshot &&
      other.title == title &&
      other.contentDocJson == contentDocJson &&
      other.contentText == contentText &&
      other.cover == cover &&
      other.metadataJson == metadataJson &&
      other.selectedTagIds.length == selectedTagIds.length &&
      other.selectedTagIds.containsAll(selectedTagIds) &&
      other.createdAt == createdAt &&
      _sameIds(other.notebookIds, notebookIds);

  @override
  int get hashCode => Object.hash(
    title,
    contentDocJson,
    contentText,
    cover,
    metadataJson,
    Object.hashAll(selectedTagIds.toList()..sort()),
    createdAt,
    notebookIds == null ? null : Object.hashAll(notebookIds!),
  );

  static bool _sameIds(List<String>? a, List<String>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
