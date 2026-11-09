import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/desktop_exit_guard.dart';
import '../../../core/services/editing_session_registry.dart';

/// 接收快照并串行自动写入；不访问页面或数据库。
///
/// 编辑已有日记（快照为 `EditDiarySnapshot`）与新建草稿（草稿快照 record）
/// 共用：输入防抖合并为一次保存，返回与切入后台时可调用 flush 跳过等待；
/// 桌面关闭窗口时经 DesktopExitGuard 等待同一保存链路，失败则取消关闭。
/// 快照靠 `==` 判断是否已存，类型必须有值相等语义。失败时保留上次成功的
/// 快照，供下一次编辑或返回操作重试，不会把失败内容标为已存。
///
/// 构造即登记为同步的阻塞者（[EditingSessionRegistry.beginEditing]）：页面
/// 握着一份可编辑的内存副本，同步写入后再自动保存会把旧副本写回去。销毁时
/// 注销；还有写入在进行时等它写完再注销，免得同步趁这次写入开始。
///
/// 手动保存（[manual] 为 true，编辑已有日记且设置为手动保存时）：[schedule]
/// 不再写库，只节流比对快照、更新 [unsaved]（顶栏“保存”按钮据此可用）；
/// 写入只经 [flush]（用户点保存、在询问框里选“保存并退出”）。桌面关闭窗口
/// 时有未保存的修改交给 [confirmManualExit] 询问，而不是直接写入。
class DebouncedAutoSaveController<T> {
  DebouncedAutoSaveController({
    required this.debounce,
    required this.readSnapshot,
    required this.writeSnapshot,
    required this.onError,
    bool Function()? manual,
    this.confirmManualExit,
    String editingLabel = 'diary-autosave',
  }) : manual = manual ?? _never,
       _editingLease = EditingSessionRegistry.instance.beginEditing(
         editingLabel,
       ) {
    _exitGuard = DesktopExitGuard(onExit: _onDesktopExit);
  }

  static bool _never() => false;

  /// 手动保存时比对快照的节流窗口：输入期间最多每个窗口比对一次（比对要
  /// 序列化整篇正文），停下后窗口末尾的那次与实际内容一致。不是动画时长。
  static const Duration unsavedCheckInterval = Duration(milliseconds: 250);

  final Duration debounce;
  final T Function() readSnapshot;
  final Future<void> Function(T snapshot) writeSnapshot;
  final void Function(Object error) onError;

  /// 此刻是不是手动保存（每次排程时读，设置中途切换随之生效）。
  final bool Function() manual;

  /// 手动保存时桌面关闭窗口、且有未保存的修改：返回能不能关闭（询问、按
  /// 选择保存或放弃由调用方负责）。null 时直接保存再关闭。
  final Future<bool> Function()? confirmManualExit;

  late final DesktopExitGuard _exitGuard;
  final EditingLease _editingLease;

  /// 手动保存时有没有未保存的修改（节流更新，见 [unsavedCheckInterval]）；
  /// 自动保存时不维护，恒为 false。需要准确结果时用 [hasUnsavedChanges]。
  final ValueNotifier<bool> unsaved = ValueNotifier<bool>(false);

  T? _savedSnapshot;
  bool _initialized = false;
  Timer? _timer;
  Timer? _unsavedCheckTimer;
  Future<bool>? _pendingSave;
  bool _disposed = false;

  void initialize(T snapshot) {
    _savedSnapshot = snapshot;
    _initialized = true;
    _unsavedCheckTimer?.cancel();
    _unsavedCheckTimer = null;
    unsaved.value = false;
  }

  /// 当前内容与上次写入（或初始化）的快照不同。当场读取快照，O(正文长度)。
  bool get hasUnsavedChanges =>
      _initialized && !_disposed && readSnapshot() != _savedSnapshot;

  /// 自动保存：防抖后写入。手动保存：只节流比对，更新 [unsaved]。
  void schedule() {
    if (_disposed || !_initialized) return;
    if (manual()) {
      // 窗口内的后续通知不重排：窗口末尾读到的就是最新内容。
      _unsavedCheckTimer ??= Timer(unsavedCheckInterval, _checkUnsaved);
      return;
    }
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  void _checkUnsaved() {
    _unsavedCheckTimer = null;
    if (_disposed || !_initialized) return;
    unsaved.value = manual() && hasUnsavedChanges;
  }

  /// 只等进行中的写入结束，不发起新的写入；没有写入时为 true。手动保存时
  /// 打开别的页面、分享导出之前用：未保存的修改留在页面里，不悄悄写库。
  Future<bool> settle() {
    if (_disposed) return Future<bool>.value(false);
    return _pendingSave ?? Future<bool>.value(true);
  }

  Future<bool> _onDesktopExit() {
    final confirm = confirmManualExit;
    if (confirm != null && manual() && hasUnsavedChanges) return confirm();
    return flush();
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
      if (snapshot == _savedSnapshot) {
        // 全部落盘：手动保存的“保存”按钮随之停用。
        unsaved.value = false;
        return true;
      }
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
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _unsavedCheckTimer?.cancel();
    unsaved.dispose();
    _exitGuard.dispose();
    final pending = _pendingSave;
    if (pending == null) {
      _editingLease.end();
    } else {
      // 这条派生的 future 无人等待：异常由原调用方处理，这里吞掉，只负责
      // 在写入结束后注销。
      unawaited(
        pending.catchError((Object _) => false).whenComplete(_editingLease.end),
      );
    }
  }
}
