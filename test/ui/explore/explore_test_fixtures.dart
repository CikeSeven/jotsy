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

/// 媒体画廊分页查询的一行（`getGalleryMediaPage`），日期与
/// [createExploreTestDiary] 同一算法。
DiaryMediaContent createExploreTestMediaRow({
  int id = 1,
  String content = '[]',
  String? cover,
}) {
  final diary = createExploreTestDiary(id: id, content: content, cover: cover);
  return DiaryMediaContent(
    diaryId: diary.diaryId,
    cover: diary.cover,
    content: diary.content,
    createdAt: diary.createdAt,
  );
}
