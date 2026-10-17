import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../widgets/image_viewer_hero.dart';
import '../models/diary_preview_sequence.dart';
import '../widgets/diary_preview/diary_preview_pager.dart';
import '../widgets/diary_preview/diary_preview_view.dart';

export '../models/diary_preview_result.dart';
export '../models/diary_preview_sequence.dart';

/// 日记预览页（阅读优先）的路由壳层。
///
/// 视觉策略：封面 + 标题 + 轻量元信息 + 正文直出，避免“后台详情卡片”观感，
/// 右上角保留字体与排版、编辑与“更多”（分享、导出、设为纪念日、删除）。
/// 单篇的数据、状态与动作在 [DiaryPreviewView]，版式在 `DiaryPreviewContent`。
/// 入口给出 [sequence]（进入时所在列表的顺序）且不止一篇时，可左右滑动切换
/// （[DiaryPreviewPager]）；否则只看这一篇。删除后以
/// [DiaryPreviewResult.deleted] 返回被删的那一篇，由入口给出撤销提示。
class DiaryPreviewPage extends StatelessWidget {
  const DiaryPreviewPage({
    super.key,
    required this.diaryId,
    this.initialDetail,
    this.coverHero,
    this.sequence,
  });

  final String diaryId;

  /// 列表封面抓取的画面：头图以它为共享元素落点与占位，页面销毁时释放。
  final ImageViewerHero? coverHero;

  /// 入口已持有的同一篇日记（`diary.diaryId` 必须等于 [diaryId]）；提供时首帧
  /// 直接渲染，详情查询返回后由最新数据接管。
  final DiaryWithTags? initialDetail;

  /// 左右滑动的顺序；null（单篇入口）时不翻页。
  final DiaryPreviewSequence? sequence;

  @override
  Widget build(BuildContext context) {
    final sequence = this.sequence;
    if (sequence == null || !sequence.canPage) {
      return DiaryPreviewView(
        diaryId: diaryId,
        initialDetail: initialDetail,
        coverHero: coverHero,
      );
    }
    return DiaryPreviewPager(
      sequence: sequence,
      diaryId: diaryId,
      initialDetail: initialDetail,
      coverHero: coverHero,
    );
  }
}
