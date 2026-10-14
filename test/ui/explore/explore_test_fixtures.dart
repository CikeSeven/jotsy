import 'package:node_diary/core/database/app_database.dart';

Diary createExploreTestDiary({
  int id = 1,
  String content = '[]',
  String? cover,
}) {
  final date = DateTime(2026, 10, 14).subtract(Duration(minutes: id));
  return Diary(
    id: id,
    diaryId: 'diary-$id',
    title: 'Diary $id',
    content: content,
    contentText: '',
    cover: cover,
    metadata: '{}',
    createdAt: date,
    updatedAt: date,
    isArchived: false,
    isPinned: false,
    isDeleted: false,
  );
}
