class NewDiaryDraft {
  static const Object _coverNotChanged = Object();

  const NewDiaryDraft({
    required this.title,
    required this.contentDocJson,
    required this.contentText,
    this.cover,
    this.metadataJson = '{}',
    this.selectedTagIds = const <int>{},
  });

  final String title;
  final String contentDocJson;
  final String contentText;
  final String? cover;
  final String metadataJson;
  final Set<int> selectedTagIds;

  NewDiaryDraft copyWith({
    String? title,
    String? contentDocJson,
    String? contentText,
    Object? cover = _coverNotChanged,
    String? metadataJson,
    Set<int>? selectedTagIds,
  }) {
    return NewDiaryDraft(
      title: title ?? this.title,
      contentDocJson: contentDocJson ?? this.contentDocJson,
      contentText: contentText ?? this.contentText,
      // `cover` 需要支持“显式置空”，因此不能用 `??` 合并。
      cover: identical(cover, _coverNotChanged) ? this.cover : cover as String?,
      metadataJson: metadataJson ?? this.metadataJson,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
    );
  }
}
