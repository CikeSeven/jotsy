import 'dart:async';

import '../models/edit_diary_snapshot.dart';

/// 接收编辑快照并串行自动写入；不访问页面或数据库。
///
/// 输入防抖合并为一次保存，返回与切入后台时可调用 flush 跳过等待。失败时
/// 保留上次成功的快照，供下一次编辑或返回操作重试，不会把失败内容标为已存。
class EditDiaryAutoSaveController {
  EditDiaryAutoSaveController({
    required this.readSnapshot,
    required this.writeSnapshot,
    required this.onError,
  });

  final EditDiarySnapshot Function() readSnapshot;
  final Future<void> Function(EditDiarySnapshot snapshot) writeSnapshot;
  final void Function(Object error) onError;

  static const _debounce = Duration(milliseconds: 500);
  EditDiarySnapshot? _savedSnapshot;
  Timer? _timer;
  Future<bool>? _pendingSave;
  bool _disposed = false;

  void initialize(EditDiarySnapshot snapshot) {
    _savedSnapshot = snapshot;
  }

  void schedule() {
    if (_disposed || _savedSnapshot == null) return;
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(flush()));
  }

  /// 多次返回/生命周期通知共用同一任务，避免并发写入使旧内容覆盖新内容。
  Future<bool> flush() {
    _timer?.cancel();
    if (_disposed) return Future<bool>.value(false);
    if (_savedSnapshot == null) return Future<bool>.value(true);
    return _pendingSave ??= _savePending().whenComplete(() {
      _pendingSave = null;
    });
  }

  Future<bool> _savePending() async {
    while (!_disposed) {
      final snapshot = readSnapshot();
      if (snapshot == _savedSnapshot) return true;
      try {
        await writeSnapshot(snapshot);
      } catch (error) {
        if (!_disposed) onError(error);
        return false;
      }
      _savedSnapshot = snapshot;
      // 写入期间仍允许继续编辑。只确认本次提交的快照，再读取最新内容，
      // 直到全部落盘才允许退出，不能在 await 后把当前编辑器直接标记为已存。
    }
    return false;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
