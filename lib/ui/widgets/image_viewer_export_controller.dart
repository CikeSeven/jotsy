import 'package:flutter/foundation.dart';
import 'package:node_diary/core/services/app_platform.dart';
import 'package:node_diary/core/services/image_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_share_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_share_target.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_share_messages.dart';

/// 看图页“保存到相册 / 分享当前图片”的业务编排。
///
/// - 输入：当前图片源、分享目标与本地化文案；
/// - 输出：忙碌态（[isBusy]/[busyLabel]，驱动 loading 遮罩，忙碌时看图页不再
///   弹出长按面板）和需要展示的结果提示（方法返回值，null 表示无需提示）；
/// - 副作用：经 [ImageExportService] 写入相册（桌面没有相册，弹出“另存为…”
///   对话框写到用户选的位置）；分享与日记分享同一条链路
///   （[DiaryShareController]：图片先暂存到缓存 `diary_share/`，指定应用经原生
///   通道按包名拉起，“更多应用”经系统分享面板），不把日记原图路径直接交出去。
///
/// 同一时间只允许一个任务：忙碌时的重复触发直接忽略，防止连点并发保存/分享；
/// 页面销毁后不再通知视图。
class ImageViewerExportController extends ChangeNotifier {
  ImageViewerExportController({
    this.service = const ImageExportService(),
    DiaryShareController? share,
  }) : _share = share ?? DiaryShareController();

  final ImageExportService service;
  final DiaryShareController _share;
  bool _busy = false;
  String _busyLabel = '';
  bool _disposed = false;

  bool get isBusy => _busy;

  /// loading 遮罩文案（保存中 / 分享准备中）。退出忙碌态时保留上一条文案，
  /// 让它随遮罩一起淡出，而不是先变空再消失。
  String get busyLabel => _busyLabel;

  /// 已安装、能接收分享的应用目标（不含始终可用的“更多应用”）。
  Future<Set<DiaryShareTarget>> availableTargets() => _share.availableTargets();

  /// 保存到相册；返回成功或失败提示，忙碌中被忽略时返回 null。
  ///
  /// 桌面（[AppPlatform.savesImagesToGallery] 为 false）改为“另存为…”：
  /// 成功提示带上保存路径，用户取消对话框时不提示（返回 null）。
  Future<String?> saveToGallery(String source, AppLocalizations l10n) {
    return _run(
      label: l10n.imageViewerSaving,
      task: () async {
        try {
          if (!AppPlatform.savesImagesToGallery) {
            final path = await service.saveToFile(
              source,
              dialogTitle: l10n.desktopSaveImageDialogTitle,
            );
            return path == null ? null : l10n.desktopSavedTo(path);
          }
          await service.saveToGallery(source);
          return l10n.imageViewerSaveSuccess;
        } on ImageExportException catch (error) {
          return switch (error.type) {
            ImageExportErrorType.permissionDenied =>
              l10n.imageViewerGalleryPermissionDenied,
            ImageExportErrorType.downloadFailed =>
              l10n.imageViewerDownloadFailed,
            ImageExportErrorType.invalidSource ||
            ImageExportErrorType.unknown => l10n.imageViewerSaveFailed(
              error.message,
            ),
          };
        }
      },
    );
  }

  /// 把当前图片分享到 [target]（[DiaryShareTarget.system] 即“更多应用”）。
  ///
  /// 目标应用或系统分享面板本身就是结果反馈，顺利交出时不提示，只在失败时
  /// 返回提示；忙碌中被忽略时同样返回 null。
  Future<String?> shareTo(
    DiaryShareTarget target,
    String source,
    AppLocalizations l10n,
  ) {
    return _run(
      label: l10n.imageViewerSharing,
      task: () async {
        try {
          final result = await _share.share(
            target,
            text: '',
            images: <String>[source],
            chooserTitle: l10n.diaryShareTargetsSection,
          );
          return switch (result.outcome) {
            DiaryShareOutcome.shared || DiaryShareOutcome.copied => null,
            DiaryShareOutcome.appUnavailable => l10n.diaryShareAppUnavailable(
              diaryShareTargetLabel(l10n, target),
            ),
            // 唯一的一张图读不到：网络图片多半是下载失败，本地图片是原文件
            // 已不在（暂存时逐张吞掉了具体原因）。
            DiaryShareOutcome.nothingToShare =>
              ImageExportService.isRemoteSource(source)
                  ? l10n.imageViewerDownloadFailed
                  : l10n.imageViewerImageUnreadable,
          };
        } catch (error) {
          // 原生通道、暂存目录或系统分享的异常都落到这里，转成提示而不是让
          // 看图页的异步回调抛出未处理异常。
          return l10n.imageViewerShareFailed(error.toString());
        }
      },
    );
  }

  Future<String?> _run({
    required String label,
    required Future<String?> Function() task,
  }) async {
    if (_disposed || _busy) {
      return null;
    }
    _busy = true;
    _busyLabel = label;
    notifyListeners();
    try {
      return await task();
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
