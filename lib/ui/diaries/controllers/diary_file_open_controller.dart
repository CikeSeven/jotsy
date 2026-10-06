import 'package:flutter/foundation.dart';
import 'package:node_diary/core/services/file_open_service.dart';

/// 管理单个附件的系统打开状态，防止连点重复拉起应用；销毁后不再通知 UI。
class DiaryFileOpenController extends ChangeNotifier {
  DiaryFileOpenController({this.service = const FileOpenService()});

  final FileOpenService service;
  bool _isOpening = false;
  bool _disposed = false;

  bool get isOpening => _isOpening;

  Future<FileOpenFailure?> open(String path) async {
    if (_disposed || _isOpening) return null;
    _isOpening = true;
    notifyListeners();
    try {
      return await service.open(path);
    } finally {
      if (!_disposed) {
        _isOpening = false;
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
