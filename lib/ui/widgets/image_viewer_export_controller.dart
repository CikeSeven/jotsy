import 'package:flutter/foundation.dart';
import 'package:node_diary/core/services/image_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';

/// 看图页“保存到相册 / 分享当前图片”的业务编排。
///
/// - 输入：当前图片源与本地化文案；
/// - 输出：忙碌态（[isBusy]/[busyLabel]，驱动顶栏按钮禁用与 loading 遮罩）和
///   需要展示的结果提示（方法返回值，null 表示无需提示）；
/// - 副作用：经 [ImageExportService] 写入相册或拉起系统分享。
///
/// 同一时间只允许一个任务：忙碌时的重复触发直接忽略，防止连点并发保存/分享；
/// 页面销毁后不再通知视图。
class ImageViewerExportController extends ChangeNotifier {
  ImageViewerExportController({this.service = const ImageExportService()});

  final ImageExportService service;
  bool _busy = false;
  String _busyLabel = '';
  bool _disposed = false;

  bool get isBusy => _busy;

  /// loading 遮罩文案（保存中 / 分享准备中）。退出忙碌态时保留上一条文案，
  /// 让它随遮罩一起淡出，而不是先变空再消失。
  String get busyLabel => _busyLabel;

  /// 保存到相册；返回成功或失败提示，忙碌中被忽略时返回 null。
  Future<String?> saveToGallery(String source, AppLocalizations l10n) {
    return _run(
      label: l10n.imageViewerSaving,
      task: () => service.saveToGallery(source),
      successHint: l10n.imageViewerSaveSuccess,
      mapError: (error) => switch (error.type) {
        ImageExportErrorType.permissionDenied =>
          l10n.imageViewerGalleryPermissionDenied,
        ImageExportErrorType.downloadFailed => l10n.imageViewerDownloadFailed,
        ImageExportErrorType.invalidSource || ImageExportErrorType.unknown =>
          l10n.imageViewerSaveFailed(error.message),
      },
    );
  }

  /// 分享当前图片；系统分享面板本身就是结果反馈，成功时不再提示，只在失败时
  /// 返回提示。
  Future<String?> share(String source, AppLocalizations l10n) {
    return _run(
      label: l10n.imageViewerSharing,
      task: () => service.shareImage(source),
      successHint: null,
      mapError: (error) => switch (error.type) {
        ImageExportErrorType.downloadFailed => l10n.imageViewerDownloadFailed,
        ImageExportErrorType.invalidSource ||
        ImageExportErrorType.permissionDenied ||
        ImageExportErrorType.unknown => l10n.imageViewerShareFailed(
          error.message,
        ),
      },
    );
  }

  Future<String?> _run({
    required String label,
    required Future<void> Function() task,
    required String? successHint,
    required String Function(ImageExportException error) mapError,
  }) async {
    if (_disposed || _busy) {
      return null;
    }
    _busy = true;
    _busyLabel = label;
    notifyListeners();
    try {
      await task();
      return successHint;
    } on ImageExportException catch (error) {
      return mapError(error);
    } finally {
      if (!_disposed) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
