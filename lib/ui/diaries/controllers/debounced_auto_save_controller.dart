import 'dart:async';

import '../../../core/services/desktop_exit_guard.dart';

/// 接收快照并串行自动写入；不访问页面或数据库。
///
/// 编辑已有日记（快照为 `EditDiarySnapshot`）与新建草稿（草稿快照 record）
/// 共用：输入防抖合并为一次保存，返回与切入后台时可调用 flush 跳过等待；
/// 桌面关闭窗口时经 DesktopExitGuard 等待同一保存链路，失败则取消关闭。
/// 快照靠 `==` 判断是否已存，类型必须有值相等语义。失败时保留上次成功的
/// 快照，供下一次编辑或返回操作重试，不会把失败内容标为已存。
class DebouncedAutoSaveController<T> {
  DebouncedAutoSaveController({
    required this.debounce,
    required this.readSnapshot,
    required this.writeSnapshot,
    required this.onError,
  }) {
    _exitGuard = DesktopExitGuard(onExit: flush);
  }

  final Duration debounce;
  final T Function() readSnapshot;
  final Future<void> Function(T snapshot) writeSnapshot;
  final void Function(Object error) onError;
  late final DesktopExitGuard _exitGuard;

  T? _savedSnapshot;
  bool _initialized = false;
  Timer? _timer;
  Future<bool>? _pendingSave;
  bool _disposed = false;

  void initialize(T snapshot) {
    _savedSnapshot = snapshot;
    _initialized = true;
  }

  void schedule() {
    if (_disposed || !_initialized) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  /// 多次返回/生命周期通知共用同一任务，避免并发写入使旧内容覆盖新内容。
  ///
  /// 快照在调用当帧同步读取（`_savePending` 第一个 await 之前），页面在
  /// dispose 开头调用后即可释放输入控制器，已读出的快照照常写完。
  Future<bool> flush() {
    _timer?.cancel();
    if (_disposed) return Future<bool>.value(false);
    if (!_initialized) return Future<bool>.value(true);
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

  /// 停止自动保存，并等进行中的写入结束后再返回。
  ///
  /// 新建日记发布后用它收尾：先确保没有晚到的写入，再删除草稿，否则防抖
  /// 窗口里已开始的写入可能在删除之后落盘，把已发布的草稿重新写回去。
  Future<void> close() async {
    final pending = _pendingSave;
    dispose();
    if (pending != null) await pending;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _exitGuard.dispose();
  }
}
