import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/mind_map/mind_map_blocks.dart';
import '../../../core/services/app_service.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/container_transform/container_transform_route.dart';
import '../../widgets/container_transform/container_transform_source.dart';
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
/// 预览页再点一次“编辑”。编辑页的版式与预览页相同（阅读式编辑），点正文
/// 就地编辑。导图日记没有预览页，不看这个开关，一律直接进编辑页（整页是
/// 导图工作区）。返回值与预览页一致：在预览页或编辑页里删除了某一
/// 篇时为 [DiaryPreviewResult.deleted]，入口据此给出撤销；否则为 null。
///
/// 直接编辑只在这一篇能编辑时生效，其余情况仍推入预览页：
/// - 未解封的时间胶囊：封存页只在预览页里显示，直接编辑会绕过封存；
/// - 日记已不存在或查询失败：交给预览页显示“日记不存在”等状态。
///
/// 入口给出 [initialDetail] 时直接用它判断（同步推入，不多等一帧）；否则先按
/// id 查一次本地库（要看是不是导图日记），查询期间入口页面被卸载则什么都
/// 不打开。查到的数据交给编辑页或预览页首帧渲染，入口抓取的 [coverHero]
/// 交给编辑页头图作共享元素落点；编辑页不左右翻页，[sequence] 只交给预览页。
/// 宽窗口日记页的右栏是页面内的阅读区，选中一篇不算“打开”，不经过这里
/// （Enter 与右栏的“编辑”照常进入编辑页）；导图日记不在右栏阅读，点按卡片
/// 照样经过这里进编辑页。
///
/// 入口给出 [origin]（点按的卡片，见 `ContainerTransformSource`）时预览页 /
/// 编辑页从这张卡片展开成整页、返回时缩回去（[ContainerTransformPageRoute]）；
/// 在里面删除了日记时不缩回（卡片随后会从列表里收起），原地淡出。没有
/// [origin] 的入口照旧按主题转场推入。
Future<DiaryPreviewResult?> openDiaryPage(
  BuildContext context,
  WidgetRef ref, {
  required String diaryId,
  DiaryWithTags? initialDetail,
  ImageViewerHero? coverHero,
  DiaryPreviewSequence? sequence,
  ContainerTransformOrigin? origin,
}) async {
  final detail = initialDetail ?? await _loadDetail(ref, diaryId);
  if (!context.mounted) {
    coverHero?.dispose();
    return null;
  }
  final skipPreview =
      ref.read(diaryPreviewBehaviorProvider).openInEditor ||
      isMindMapDiary(detail);
  if (skipPreview && canOpenDiaryInEditor(detail, now: DateTime.now())) {
    final deleted = await openDiaryEditorFromPreview(
      context,
      ref,
      diaryId,
      initialDetail: detail,
      coverHero: coverHero,
      origin: origin,
    );
    return deleted ? DiaryPreviewResult.deleted(diaryId) : null;
  }
  Widget page(BuildContext context) => DiaryPreviewPage(
    diaryId: diaryId,
    initialDetail: detail,
    coverHero: coverHero,
    sequence: sequence,
  );
  return Navigator.of(context).push<DiaryPreviewResult?>(
    origin == null
        ? MaterialPageRoute<DiaryPreviewResult?>(builder: page)
        : ContainerTransformPageRoute<DiaryPreviewResult?>(
            builder: page,
            origin: origin,
            backdrop: const AppPageBackgroundFill(
              area: AppBackgroundArea.preview,
            ),
            returnsToOrigin: (DiaryPreviewResult? result) => result == null,
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

/// [detail] 是否为导图日记（正文就是一张导图）：导图日记没有预览页，点开
/// 直接进编辑页。宽窗口日记页点按卡片时据此跳过右栏阅读。
bool isMindMapDiary(DiaryWithTags? detail) =>
    detail != null && storedDiaryMindMapPage(detail.diary.content) != null;

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
