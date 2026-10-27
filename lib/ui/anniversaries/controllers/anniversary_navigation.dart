import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diaries/controllers/diary_open_flow.dart';
import '../../diaries/pages/diary_preview_page.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/image_viewer_hero.dart';
import '../models/anniversary_draft.dart';
import '../pages/anniversary_detail_page.dart';
import '../pages/anniversary_edit_page.dart';
import '../pages/anniversary_list_page.dart';
import 'anniversary_edit_controller.dart';

/// 撤销提示的停留时间（非动画计时）；无障碍下也到时关闭。
const Duration _undoDuration = Duration(seconds: 5);

/// 纪念日相关页面的导航入口（日历、列表、详情、日记预览页共用）。
///
/// 提示一律用打开方的 context 经 [HomeHintVisibilityScope.showTrackedSnackBar]
/// 弹出：被关闭的页面已出栈，它所在的位置不再可见。[AppDatabase] 由调用方
/// 传入，用于撤销删除。

Future<void> openAnniversaryList(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const AnniversaryListPage(),
    ),
  );
}

Future<void> openAnniversaryDetail(
  BuildContext context, {
  required String anniversaryId,
  Anniversary? initial,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          AnniversaryDetailPage(anniversaryId: anniversaryId, initial: initial),
    ),
  );
}

/// 打开纪念日编辑页（新建或编辑），关闭后给出提示：新建 → “已添加”（带
/// “查看”进入详情）；删除 → 可撤销的“已删除”。返回编辑页带回的结果。
Future<AnniversaryEditResult?> openAnniversaryEditor(
  BuildContext context, {
  required AppDatabase database,
  required AnniversaryDraft draft,
  Anniversary? editing,
}) async {
  final result = await Navigator.of(context).push<AnniversaryEditResult>(
    MaterialPageRoute<AnniversaryEditResult>(
      builder: (BuildContext context) =>
          AnniversaryEditPage(initialDraft: draft, editing: editing),
    ),
  );
  if (result == null || !context.mounted) {
    return result;
  }
  switch (result) {
    case AnniversaryCreated(:final anniversaryId):
      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: context,
          snackBar: SnackBar(
            content: Text(context.l10n.anniversaryCreated),
            persist: false,
            action: SnackBarAction(
              label: context.l10n.anniversaryView,
              onPressed: () {
                if (context.mounted) {
                  unawaited(
                    openAnniversaryDetail(
                      context,
                      anniversaryId: anniversaryId,
                    ),
                  );
                }
              },
            ),
          ),
        ),
      );
    case AnniversaryDeleted(:final row):
      unawaited(showAnniversaryDeletedUndo(context, database, row));
    case AnniversaryUpdated():
      break;
  }
  return result;
}

/// “已删除纪念日”提示，点撤销把整行原样写回。
Future<void> showAnniversaryDeletedUndo(
  BuildContext context,
  AppDatabase database,
  Anniversary row,
) async {
  var undo = false;
  final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(
      content: Text(context.l10n.anniversaryDeleted),
      duration: _undoDuration,
      persist: false,
      action: SnackBarAction(
        label: context.l10n.commonUndo,
        onPressed: () => undo = true,
      ),
    ),
  );
  if (undo || reason == SnackBarClosedReason.action) {
    await database.restoreAnniversary(row);
  }
}

/// 未解封的时间胶囊不从纪念日打开：入口只显示可看的日记，避免绕过锁。
bool isOpenableDiary(DiaryWithTags diary, {DateTime? now}) {
  return !TimeCapsuleState.fromFields(
    lockedAt: diary.diary.capsuleLockedAt,
    unlockAt: diary.diary.capsuleUnlockAt,
    now: now ?? DateTime.now(),
  ).isLocked;
}

/// 从纪念日打开日记预览（“打开日记时直接编辑”开启时为编辑页，见
/// [openDiaryPage]；首帧用已有的 [diary]，缩略图作共享元素）。在里面删除
/// 日记后给出可撤销的提示，撤销即从回收站恢复。[sequence] 为左右滑动的顺序
/// （历年的日记）；关联的那一篇是单篇入口，不传。
Future<void> openDiaryFromAnniversary(
  BuildContext context,
  WidgetRef ref, {
  required DiaryWithTags diary,
  ImageViewerHero? coverHero,
  DiaryPreviewSequence? sequence,
}) async {
  // 撤销发生在页面返回之后，那时打开方可能已卸载、不能再用 ref：先取好库。
  final database = ref.read(appDatabaseProvider);
  final result = await openDiaryPage(
    context,
    ref,
    diaryId: diary.diary.diaryId,
    initialDetail: diary,
    coverHero: coverHero,
    sequence: sequence,
  );
  // 预览页里可能已滑到别的日记再删除：恢复的是结果里的那一篇。
  final deletedId = result?.diaryId;
  if (deletedId == null || !context.mounted) {
    return;
  }
  final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(
      content: Text(context.l10n.autoT0075),
      duration: _undoDuration,
      persist: false,
      action: SnackBarAction(label: context.l10n.commonUndo, onPressed: () {}),
    ),
  );
  if (reason == SnackBarClosedReason.action) {
    await database.restoreDiary(deletedId, touchUpdatedAt: false);
  }
}
