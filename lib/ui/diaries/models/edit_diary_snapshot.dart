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
  }) : selectedTagIds = Set<int>.unmodifiable(selectedTagIds);

  final String title;
  final String contentDocJson;
  final String contentText;
  final String? cover;
  final String metadataJson;
  final Set<int> selectedTagIds;

  /// 发表时间（created_at）；null 表示沿用库中原值。
  final DateTime? createdAt;

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
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    title,
    contentDocJson,
    contentText,
    cover,
    metadataJson,
    Object.hashAll(selectedTagIds.toList()..sort()),
    createdAt,
  );
}
