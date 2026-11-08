import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/controllers/publish_diary_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';

/// 不经发布页直接发表一份新日记（新建页“返回时直接发表”，#196），返回新
/// 日记 id；写库失败时把异常抛给调用方。
///
/// 与发布页写的是同一篇：同样经 [PublishDiaryController.submit] 写库（标题、
/// 正文、面板草稿、发表时间、所选日记本与章节），功能管理里关掉的时间胶囊
/// 与日记本同样忽略；解封时间已过的胶囊与发布页一样去掉、按普通日记发表。
/// 发布页之后的“面板改动自动保存”在这里用不到，写完即释放。
///
/// 删除草稿、触觉、AI 回应与路由由调用方负责（见
/// `EditDiaryCreateLeaveFlow`）。
Future<String> publishNewDiaryDirectly({
  required AppDatabase database,
  required NewDiaryDraft draft,
  required bool timeCapsulesEnabled,
  required bool notebooksEnabled,
}) async {
  final meta = DiaryMetaDraftController(
    DiaryMetaDraft.fromNewDiaryDraft(draft),
  );
  final publisher = PublishDiaryController(
    initialDraft: draft,
    meta: meta,
    timeCapsulesEnabled: () => timeCapsulesEnabled,
    notebooksEnabled: () => notebooksEnabled,
  );
  try {
    if (publisher.validate() == PublishValidation.capsuleUnlockPassed) {
      meta.setCapsule(null);
    }
    return await publisher.submit(database);
  } finally {
    publisher.dispose();
    meta.dispose();
  }
}
