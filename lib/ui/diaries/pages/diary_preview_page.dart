import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../widgets/image_viewer_hero.dart';
import '../widgets/diary_preview/diary_preview_view.dart';

export '../models/diary_preview_result.dart';

/// 日记预览页（阅读优先）的路由壳层。
///
/// 视觉策略：封面 + 标题 + 轻量元信息 + 正文直出，避免“后台详情卡片”观感，
/// 右上角保留字体与排版、编辑与“更多”（分享、导出、设为纪念日、删除）。
/// 单篇的数据、状态与动作在 [DiaryPreviewView]，版式在 `DiaryPreviewContent`。
/// 删除后以 [DiaryPreviewResult.deleted] 返回，由入口给出撤销提示。
class DiaryPreviewPage extends StatelessWidget {
  const DiaryPreviewPage({
    super.key,
    required this.diaryId,
    this.initialDetail,
    this.coverHero,
  });

  final String diaryId;

  /// 列表封面抓取的画面：头图以它为共享元素落点与占位，页面销毁时释放。
  final ImageViewerHero? coverHero;

  /// 入口已持有的同一篇日记（`diary.diaryId` 必须等于 [diaryId]）；提供时首帧
  /// 直接渲染，详情查询返回后由最新数据接管。
  final DiaryWithTags? initialDetail;

  @override
  Widget build(BuildContext context) {
    return DiaryPreviewView(
      diaryId: diaryId,
      initialDetail: initialDetail,
      coverHero: coverHero,
    );
  }
}
