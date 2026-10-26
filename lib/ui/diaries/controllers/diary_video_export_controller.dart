import 'package:flutter/foundation.dart';
import 'package:node_diary/core/services/video_export_service.dart';

/// 内嵌与全屏视图共享导出状态，阻止重复弹窗/保存，销毁后不再通知视图。
/// 手机经二次确认后存进相册（[beginConfirmation] → [export]）；桌面没有相册，
/// 经 [saveAs] 弹出“另存为…”对话框。
class DiaryVideoExportController extends ChangeNotifier {
  DiaryVideoExportController({this.service = const VideoExportService()});

  final VideoExportService service;
  bool _confirming = false;
  bool _exporting = false;
  bool _disposed = false;

  bool get isBusy => _confirming || _exporting;
  bool get isExporting => _exporting;

  bool beginConfirmation() {
    if (_disposed || isBusy) return false;
    _confirming = true;
    notifyListeners();
    return true;
  }

  void cancelConfirmation() {
    if (_disposed) return;
    _confirming = false;
    notifyListeners();
  }

  Future<VideoExportFailure?> export(String source) async {
    if (_disposed || !_confirming || _exporting) {
      return VideoExportFailure.failed;
    }
    _confirming = false;
    _exporting = true;
    notifyListeners();
    try {
      await service.saveToGallery(source);
      return null;
    } on VideoExportException catch (error) {
      return error.type;
    } catch (_) {
      return VideoExportFailure.failed;
    } finally {
      if (!_disposed) {
        _exporting = false;
        notifyListeners();
      }
    }
  }

  /// 桌面端“另存为…”：不经二次确认（保存对话框本身就是确认），直接弹出
  /// 对话框并复制视频。返回保存路径与失败原因：两者都为 null 表示用户取消了
  /// 对话框或正忙（不提示）。
  Future<({String? path, VideoExportFailure? failure})> saveAs(
    String source, {
    required String fileName,
    required String dialogTitle,
  }) async {
    if (_disposed || isBusy) return (path: null, failure: null);
    _exporting = true;
    notifyListeners();
    try {
      final path = await service.saveToFile(
        source,
        fileName: fileName,
        dialogTitle: dialogTitle,
      );
      return (path: path, failure: null);
    } on VideoExportException catch (error) {
      return (path: null, failure: error.type);
    } catch (_) {
      return (path: null, failure: VideoExportFailure.failed);
    } finally {
      if (!_disposed) {
        _exporting = false;
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
