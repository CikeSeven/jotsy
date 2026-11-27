import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 快速新建待办时预先带上的字段（来自当前视图、日历选中日或日记）。
@immutable
class TodoQuickAddPreset {
  const TodoQuickAddPreset({
    this.listId,
    this.dueDate,
    this.priority = TodoPriority.none,
    this.title = '',
    this.linkedDiaryId,
    this.tags = const <String>[],
    this.sectionId,
  });

  final String? listId;
  final DateTime? dueDate;
  final TodoPriority priority;
  final String title;
  final String? linkedDiaryId;

  /// 预先带上的标签（在标签视图里新建时为这个标签）。
  final List<String> tags;

  /// 预先放进的分区（点分区标题上的“+”时）；只在清单仍是 [listId] 时生效。
  final String? sectionId;

  /// 同样的预填，放进清单 [listId] 的分区 [sectionId]。
  TodoQuickAddPreset withSection(String listId, String sectionId) =>
      TodoQuickAddPreset(
        listId: listId,
        dueDate: dueDate,
        priority: priority,
        title: title,
        linkedDiaryId: linkedDiaryId,
        tags: tags,
        sectionId: sectionId,
      );
}
