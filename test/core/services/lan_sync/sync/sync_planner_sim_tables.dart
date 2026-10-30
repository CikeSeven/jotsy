// 收敛模拟的内存“数据库”表：只保留同步会读写的列（本地 id、业务 id、
// 规范记录里的字段、位置与排序）。

class SimDiary {
  SimDiary(this.id, this.localId);

  final String id;
  final int localId;
  String title = '';
  Object? body;
  Object? metadata = <String, Object?>{};
  int createdAt = 0;
  int updatedAt = 0;
  bool pinned = false;
  bool archived = false;
  int? archivedAt;
  bool deleted = false;
  int? deletedAt;
  int? unlockAt;
  Set<int> tagIds = <int>{};
}

class SimTag {
  SimTag(this.localId, this.name, this.color);

  final int localId;
  String name;
  int color;
}

class SimNotebook {
  SimNotebook(this.id, this.localId);

  final String id;
  final int localId;
  String name = '';
  String kind = 'manual';
  String visibility = 'normal';
  List<String> chapters = <String>[];
  String? parentId;
  int sortOrder = 0;
  int createdAt = 0;
  int updatedAt = 0;
}

class SimMember {
  SimMember(this.chapterId, this.addedAt, this.position);

  String? chapterId;
  int addedAt;
  int position;
}

class SimComment {
  SimComment(this.diaryId, this.content, this.createdAt, this.editedAt);

  String diaryId;
  String content;
  int createdAt;
  int? editedAt;
}

class SimAnniversary {
  SimAnniversary(this.title, this.linkedDiaryId, this.updatedAt);

  String title;
  String? linkedDiaryId;
  int updatedAt;
}
