import 'package:flutter/foundation.dart';
import 'package:node_diary/core/services/video_export_service.dart';

/// 内嵌与全屏视图共享导出状态，阻止重复弹窗/保存，销毁后不再通知视图。
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
