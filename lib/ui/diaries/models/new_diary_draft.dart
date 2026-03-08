class NewDiaryDraft {
  const NewDiaryDraft({
    required this.title,
    required this.contentDocJson,
    required this.contentText,
    this.metadataJson = '{}',
    this.selectedTagIds = const <int>{},
  });

  final String title;
  final String contentDocJson;
  final String contentText;
  final String metadataJson;
  final Set<int> selectedTagIds;

  NewDiaryDraft copyWith({
    String? title,
    String? contentDocJson,
    String? contentText,
    String? metadataJson,
    Set<int>? selectedTagIds,
  }) {
    return NewDiaryDraft(
      title: title ?? this.title,
      contentDocJson: contentDocJson ?? this.contentDocJson,
      contentText: contentText ?? this.contentText,
      metadataJson: metadataJson ?? this.metadataJson,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
    );
  }
}
