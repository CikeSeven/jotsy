import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';

/// 日记链接卡片指向的那篇（含归档）；在回收站、已彻底删除或是私密日记时
/// 推送 null——卡片据 `privateDiaryIdsProvider` 区分“私密”与“不存在”，
/// 不在不私密的日记里露出私密日记的标题与摘要。
final diaryLinkDiaryProvider = StreamProvider.autoDispose
    .family<DiaryWithTags?, String>(
      (Ref ref, String diaryId) =>
          ref.watch(appDatabaseProvider).watchActiveDiaryWithTags(diaryId),
    );
