import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../widgets/image_viewer_hero.dart';
import '../models/time_capsule.dart';
import '../pages/diary_preview_page.dart';
import '../providers/diary_preview_style_provider.dart';
import 'diary_preview_edit_flow.dart';

/// 点开一篇日记（首页列表、搜索、日历、归档、探索与媒体画廊、纪念日、日记本
/// 目录与统计共用）。
///
/// 默认推入预览页 [DiaryPreviewPage]；阅读行为“打开日记时直接编辑”
/// （`DiaryPreviewBehavior.openInEditor`）开启时改为直接推入编辑页，省去在
/// 预览页再点一次“编辑”。返回值与预览页一致：在预览页或编辑页里删除了某一
/// 篇时为 [DiaryPreviewResult.deleted]，入口据此给出撤销；否则为 null。
///
/// 直接编辑只在这一篇能编辑时生效，其余情况仍推入预览页：
/// - 未解封的时间胶囊：封存页只在预览页里显示，直接编辑会绕过封存；
/// - 日记已不存在或查询失败：交给预览页显示“日记不存在”等状态。
///
/// 入口给出 [initialDetail] 时直接用它判断（同步推入，不多等一帧）；否则先按
/// id 查一次本地库，查询期间入口页面被卸载则什么都不打开。编辑页没有头图共享
/// 元素，也不左右翻页：入口抓取的 [coverHero] 在这里释放，[sequence] 只交给
/// 预览页。宽窗口日记页的右栏是页面内的阅读区，选中一篇不算“打开”，不经过
/// 这里（Enter 与右栏的“编辑”照常进入编辑页）。
Future<DiaryPreviewResult?> openDiaryPage(
  BuildContext context,
  WidgetRef ref, {
  required String diaryId,
  DiaryWithTags? initialDetail,
  ImageViewerHero? coverHero,
  DiaryPreviewSequence? sequence,
}) async {
  if (ref.read(diaryPreviewBehaviorProvider).openInEditor) {
    final detail = initialDetail ?? await _loadDetail(ref, diaryId);
    if (!context.mounted) {
      coverHero?.dispose();
      return null;
    }
    if (canOpenDiaryInEditor(detail, now: DateTime.now())) {
      coverHero?.dispose();
      final deleted = await openDiaryEditorFromPreview(context, ref, diaryId);
      return deleted ? DiaryPreviewResult.deleted(diaryId) : null;
    }
  }
  return Navigator.of(context).push<DiaryPreviewResult?>(
    MaterialPageRoute<DiaryPreviewResult?>(
      builder: (BuildContext context) => DiaryPreviewPage(
        diaryId: diaryId,
        initialDetail: initialDetail,
        coverHero: coverHero,
        sequence: sequence,
      ),
    ),
  );
}

/// 能否跳过预览直接编辑 [detail]：日记存在，且不是未解封的时间胶囊。
bool canOpenDiaryInEditor(DiaryWithTags? detail, {required DateTime now}) {
  if (detail == null) {
    return false;
  }
  return !TimeCapsuleState.fromFields(
    lockedAt: detail.diary.capsuleLockedAt,
    unlockAt: detail.diary.capsuleUnlockAt,
    now: now,
  ).isLocked;
}

/// 入口没有现成数据时按 id 读一次；读取失败按“不存在”处理，回落到预览页。
Future<DiaryWithTags?> _loadDetail(WidgetRef ref, String diaryId) async {
  final db = ref.read(appDatabaseProvider);
  try {
    return await db.getDiaryWithTagsByDiaryId(diaryId);
  } catch (error) {
    debugPrint('Loading diary before opening the editor failed: $error');
    return null;
  }
}
