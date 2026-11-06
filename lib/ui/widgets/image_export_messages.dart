import '../../core/services/image_export_service.dart';
import '../../l10n/app_localizations.dart';

/// 图片存相册失败时给用户的提示（看图页、打赏收款码、日记长图共用）。
///
/// 权限被拒与网络图片下载失败各有一句说明，其余失败带上异常摘要；内存字节
/// 与本地文件不会出现下载失败，同一个映射对它们也成立。
String imageExportErrorMessage(
  AppLocalizations l10n,
  ImageExportException error,
) {
  return switch (error.type) {
    ImageExportErrorType.permissionDenied =>
      l10n.imageViewerGalleryPermissionDenied,
    ImageExportErrorType.downloadFailed => l10n.imageViewerDownloadFailed,
    ImageExportErrorType.invalidSource ||
    ImageExportErrorType.unknown => l10n.imageViewerSaveFailed(error.message),
  };
}
