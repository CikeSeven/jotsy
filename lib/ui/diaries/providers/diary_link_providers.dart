import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../core/services/app_service.dart';

/// 日记链接卡片指向的那篇（含归档）；在回收站、已彻底删除或是私密日记时
/// 推送 null——卡片据 `privateDiaryIdsProvider` 区分“私密”与“不存在”，
/// 不在不私密的日记里露出私密日记的标题与摘要。
final diaryLinkDiaryProvider = StreamProvider.autoDispose
    .family<DiaryWithTags?, String>(
      (Ref ref, String diaryId) =>
          ref.watch(appDatabaseProvider).watchActiveDiaryWithTags(diaryId),
    );

/// 提到 [DiaryLinkTarget] 的日记（反向链接，口径见
/// `AppDatabase.watchDiaryBacklinks`），随写入更新：日记本头部与全部反向
/// 链接面板。
final diaryBacklinksProvider = StreamProvider.autoDispose
    .family<List<DiaryBacklink>, DiaryLinkTarget>(
      (Ref ref, DiaryLinkTarget target) =>
          ref.watch(appDatabaseProvider).watchDiaryBacklinks(target),
    );

/// 预览页的反向链接：打开时读一次（预览页的正文、所在日记本同样只读一次，
/// 页面里不多挂一条数据库订阅）。
final diaryPreviewBacklinksProvider = FutureProvider.autoDispose
    .family<List<DiaryBacklink>, DiaryLinkTarget>(
      (Ref ref, DiaryLinkTarget target) =>
          ref.watch(appDatabaseProvider).getDiaryBacklinks(target),
    );
