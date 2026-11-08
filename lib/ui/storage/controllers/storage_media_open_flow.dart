import 'package:flutter/material.dart';

import '../../../core/services/app_platform.dart';
import '../../../core/services/file_open_service.dart';
import '../../../core/services/storage/storage_usage_models.dart';
import '../pages/storage_video_preview_page.dart';
import '../viewmodels/storage_media_view.dart';

/// 在存储管理里打开一个不是图片的媒体（图片经 `openImageViewer`）：
///
/// - 视频在能内嵌播放的平台（[AppPlatform.supportsInlineVideo]）进视频预览页
///   [StorageVideoPreviewPage]，其余平台交给系统应用；
/// - 录音、附件交给系统应用打开。
///
/// 打码的项不应走到这里（调用方不提供入口）。
Future<void> openStorageMedia(
  BuildContext context,
  StorageMediaItemView item,
) async {
  if (item.entry.kind == DiaryBlockMediaKind.video &&
      AppPlatform.supportsInlineVideo) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => StorageVideoPreviewPage(item: item),
      ),
    );
    return;
  }
  await const FileOpenService().open(item.entry.path);
}
