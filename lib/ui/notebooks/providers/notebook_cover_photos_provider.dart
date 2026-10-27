import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/widgets/diary_image_source.dart';
import '../../explore/controllers/explore_content_extractor.dart';
import '../../widgets/long_image/long_image_policy.dart';

/// “从日记中选封面”面板的图片：[scope] 范围内（父本连同子本，见
/// `notebookStatsScope`）日记用到的图片，按日记时间新→旧。
///
/// 口径与统计页的照片数一致（[AppDatabase.watchScopedMediaContents]：含
/// 归档，不含回收站与未解封的胶囊）；每篇先封面、后正文图片，同一张图只
/// 列一次（见 [notebookCoverPhotoSources]）。
final notebookCoverPhotosProvider = StreamProvider.autoDispose
    .family<List<String>, DiaryListScope>(
      (Ref ref, DiaryListScope scope) => ref
          .watch(appDatabaseProvider)
          .watchScopedMediaContents(scope)
          .map((rows) => notebookCoverPhotoSources(rows)),
    );

/// 把范围内的日记（数据库按时间旧→新返回）整理成可选的封面来源：
///
/// - 倒序遍历，新日记的图片在前；每篇按“封面、正文图片的顺序”；
/// - 去重：同一来源只保留第一次（最新的那篇）出现的位置；
/// - 只留本机文件：应用内置资源（`asset:`）、网络图与内嵌数据不能拷贝成
///   封面，跳过；文件已不存在的（[exists] 判定，默认同步查文件系统）也跳过。
///
/// 同步查文件：数量是“本子里的图片数”，量级小；拷贝前封面服务还会再读一次。
List<String> notebookCoverPhotoSources(
  List<DiaryMediaContent> rows, {
  bool Function(String path)? exists,
}) {
  const extractor = ExploreContentExtractor();
  final check = exists ?? (String path) => File(path).existsSync();
  final seen = <String>{};
  final result = <String>[];
  for (final row in rows.reversed) {
    final sources = extractor.resolveMediaSourcesFrom(
      cover: row.cover,
      content: row.content,
    );
    for (final raw in sources) {
      final source = raw.trim();
      if (source.isEmpty || !seen.add(source)) continue;
      if (source.startsWith(diaryAssetImageScheme) ||
          !isLocalImageSource(source) ||
          source.startsWith('data:')) {
        continue;
      }
      if (!check(source)) continue;
      result.add(source);
    }
  }
  return List<String>.unmodifiable(result);
}
