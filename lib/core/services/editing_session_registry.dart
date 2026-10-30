import 'dart:async';

import 'package:flutter/foundation.dart';

/// 进程内的编辑会话登记：局域网同步写库前据此判断“现在能不能写”。
///
/// 为什么需要：同步会把对方的数据直接写进本机数据库。手里握着一份可编辑
/// 内存副本的页面（编辑页、发布页、日记本 / 模板 / 纪念日编辑页、留言面板、
/// 拖动中的排序）之后会把这份旧副本写回去，悄无声息地覆盖刚同步来的改动；
/// 撤销提示按删除前的整行恢复，同样会盖掉同步写入。这里登记四类东西：
///
/// - **阻塞者**（[beginEditing]）：登记期间同步不开始，对方的会话请求以忙碌
///   拒绝。持有者负责在页面 / 面板 / 拖动结束时 [EditingLease.end]。
/// - **冲刷者**（[registerFlusher]）：常驻、不能阻塞同步的自动保存（宽窗口
///   右栏的预览页一直开着）。同步开始前 [flushAll] 让它们先把待存内容落盘。
/// - **撤销窗口**（[beginUndoWindow]）：带撤销按钮的提示显示期间计数，同步
///   写入前 [waitForUndoWindows] 等它们关闭（或超时）。
/// - **写入后事件**（[notifyDataReplaced] / [dataReplaced]）：同步写完后发出，
///   界面层据此失效一次性读取的 provider（见 `synced_data_refresh.dart`）。
///
/// 输入：各页面与控制器的登记；输出：计数、事件；副作用：无（不访问数据库）。
///
/// 只依赖 foundation：同步引擎的纯 Dart 测试也会读它，不能要求先初始化
/// 绑定。登记与注销一律同步生效（[isEditing]、[activeEditorCount] 等 getter
/// 总是即时的真值）；两个 [ValueListenable] 的通知推迟到微任务里合并发出——
/// 租约常在 `initState` / `dispose` 里开始和结束，那时框架正在构建或树已
/// 锁定，监听者（如同步页的 `ValueListenableBuilder`）若同步 setState 会触发
/// “构建期间 markNeedsBuild”断言。
class EditingSessionRegistry {
  EditingSessionRegistry._();

  /// 全进程唯一实例。页面与控制器直接用它，测试经 [debugReset] 复位。
  static final EditingSessionRegistry instance = EditingSessionRegistry._();

  final Set<EditingLease> _editors = <EditingLease>{};
  final Set<FlushLease> _flushers = <FlushLease>{};
  final Set<UndoWindowLease> _undoWindows = <UndoWindowLease>{};
  final List<Completer<bool>> _undoWaiters = <Completer<bool>>[];

  final ValueNotifier<int> _activeEditors = ValueNotifier<int>(0);
  final ValueNotifier<int> _openUndoWindows = ValueNotifier<int>(0);
  bool _publishScheduled = false;

  final StreamController<void> _dataReplaced =
      StreamController<void>.broadcast();

  // ---------------------------------------------------------------- 阻塞者

  /// 开始一段阻塞同步的编辑；[label] 只用于诊断（[activeEditorLabels]）。
  EditingLease beginEditing(String label) {
    final lease = EditingLease._(this, label);
    _editors.add(lease);
    _schedulePublish();
    return lease;
  }

  /// 正在编辑的阻塞者个数（微任务里通知，见类注释）。
  ValueListenable<int> get activeEditors => _activeEditors;

  /// 即时值：现在有没有阻塞者。
  bool get isEditing => _editors.isNotEmpty;

  /// 即时值：阻塞者个数。
  int get activeEditorCount => _editors.length;

  /// 当前阻塞者的标签（诊断与日志用，不是界面文案）。
  List<String> get activeEditorLabels =>
      List<String>.unmodifiable(_editors.map((lease) => lease.label));

  void _endEditing(EditingLease lease) {
    // debugReset 之后旧租约已不在集合里：remove 返回 false，不影响新的计数。
    if (_editors.remove(lease)) _schedulePublish();
  }

  // ---------------------------------------------------------------- 冲刷者

  /// 登记一个冲刷回调；同步开始前由 [flushAll] 调用。
  FlushLease registerFlusher(Future<void> Function() flush) {
    final lease = FlushLease._(this, flush);
    _flushers.add(lease);
    return lease;
  }

  /// 即时值：已登记的冲刷者个数。
  int get flusherCount => _flushers.length;

  /// 并行运行全部冲刷回调，等它们都结束；单个回调的异常只记日志、不抛出。
  ///
  /// 为什么不抛：冲刷者自己负责提示失败（待办自动保存经 onSaveError 提示）
  /// 并保留待存状态、之后重试；一个写不进去的预览页不应让其他冲刷者跳过，
  /// 也不应让同步永远开始不了。调用方只需要“已经尽力落盘”的时间点。
  /// 回调期间新登记的冲刷者不在本轮（按调用时的快照运行）。
  Future<void> flushAll() async {
    final flushers = _flushers.toList(growable: false);
    await Future.wait<void>(<Future<void>>[
      for (final lease in flushers) _runFlusher(lease),
    ]);
  }

  Future<void> _runFlusher(FlushLease lease) async {
    try {
      await lease._flush();
    } catch (error, stackTrace) {
      debugPrint('EditingSessionRegistry flush failed: $error\n$stackTrace');
    }
  }

  void _endFlusher(FlushLease lease) => _flushers.remove(lease);

  // -------------------------------------------------------------- 撤销窗口

  /// 开始一个撤销窗口（带撤销按钮的提示显示期间）。
  UndoWindowLease beginUndoWindow() {
    final lease = UndoWindowLease._(this);
    _undoWindows.add(lease);
    _schedulePublish();
    return lease;
  }

  /// 打开着的撤销窗口个数（微任务里通知，见类注释）。
  ValueListenable<int> get openUndoWindows => _openUndoWindows;

  /// 即时值：打开着的撤销窗口个数。
  int get openUndoWindowCount => _undoWindows.length;

  /// 等撤销窗口全部关闭：在 [timeout] 内归零返回 true，超时返回 false。
  ///
  /// 现在就没有撤销窗口时立即返回 true。按即时计数判断，不等微任务通知。
  Future<bool> waitForUndoWindows({required Duration timeout}) {
    if (_undoWindows.isEmpty) return Future<bool>.value(true);
    final completer = Completer<bool>();
    _undoWaiters.add(completer);
    final timer = Timer(timeout, () {
      if (_undoWaiters.remove(completer)) completer.complete(false);
    });
    return completer.future.whenComplete(timer.cancel);
  }

  void _endUndoWindow(UndoWindowLease lease) {
    if (!_undoWindows.remove(lease)) return;
    _schedulePublish();
    if (_undoWindows.isEmpty) _releaseUndoWaiters();
  }

  void _releaseUndoWaiters() {
    final waiters = _undoWaiters.toList(growable: false);
    _undoWaiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.complete(true);
    }
  }

  // ------------------------------------------------------------ 写入后事件

  /// 同步把对方的数据写进本机数据库之后调用（每次会话写完一次）。
  void notifyDataReplaced() => _dataReplaced.add(null);

  /// [notifyDataReplaced] 的广播流；事件异步送达。
  Stream<void> get dataReplaced => _dataReplaced.stream;

  // ------------------------------------------------------------------ 内部

  /// 合并同一轮同步代码里的多次登记 / 注销，在微任务里一次写入通知值。
  void _schedulePublish() {
    if (_publishScheduled) return;
    _publishScheduled = true;
    scheduleMicrotask(_publish);
  }

  void _publish() {
    _publishScheduled = false;
    _activeEditors.value = _editors.length;
    _openUndoWindows.value = _undoWindows.length;
  }

  /// 清空全部登记，计数立即归零；之前发出的租约之后再 end 也不再生效。
  ///
  /// 等撤销窗口的调用方按“已归零”放行。只供测试在用例之间复位单例。
  @visibleForTesting
  void debugReset() {
    _editors.clear();
    _flushers.clear();
    _undoWindows.clear();
    _releaseUndoWaiters();
    _publishScheduled = false;
    _activeEditors.value = 0;
    _openUndoWindows.value = 0;
  }
}

/// 一段阻塞同步的编辑；[end] 可重复调用，只有第一次生效。
final class EditingLease {
  EditingLease._(this._registry, this.label);

  final EditingSessionRegistry _registry;

  /// 诊断用的来源标签。
  final String label;
  bool _ended = false;

  /// 是否已经结束。
  bool get isEnded => _ended;

  void end() {
    if (_ended) return;
    _ended = true;
    _registry._endEditing(this);
  }
}

/// 一个已登记的冲刷回调；[end] 注销，可重复调用。
final class FlushLease {
  FlushLease._(this._registry, this._flush);

  final EditingSessionRegistry _registry;
  final Future<void> Function() _flush;
  bool _ended = false;

  bool get isEnded => _ended;

  void end() {
    if (_ended) return;
    _ended = true;
    _registry._endFlusher(this);
  }
}

/// 一个撤销窗口；[end] 关闭，可重复调用。
final class UndoWindowLease {
  UndoWindowLease._(this._registry);

  final EditingSessionRegistry _registry;
  bool _ended = false;

  bool get isEnded => _ended;

  void end() {
    if (_ended) return;
    _ended = true;
    _registry._endUndoWindow(this);
  }
}

/// 拖动排序期间的阻塞登记。
///
/// 时序（`SliverReorderableList`）：拿起时 [start]；松手时 `onReorderEnd`
/// 调 [dropped]——落回原位之后不会再有 `onReorderItem`，就此结束；移动了的
/// 在 `onReorderItem` 里经 [holdUntil] 等新顺序写完再结束：写入用的是拖动前
/// 构建的快照，写完之前就让同步开始，同步落地的顺序会被这份旧快照覆盖。
/// 列表取消拖动（指针被取消）时两个回调都不来，租约留到下一次拿起复用或
/// 所属对象 [dispose] 时结束。
class ReorderEditingGuard {
  ReorderEditingGuard(this.label, {EditingSessionRegistry? registry})
    : _registry = registry ?? EditingSessionRegistry.instance;

  /// 诊断用的来源标签。
  final String label;
  final EditingSessionRegistry _registry;
  EditingLease? _lease;
  int? _startIndex;

  /// 拿起第 [index] 行。
  void start(int index) {
    _startIndex = index;
    _lease ??= _registry.beginEditing(label);
  }

  /// 松手，[insertIndex] 为列表未修正的插入位置；落回原位时结束登记。
  void dropped(int insertIndex) {
    final start = _startIndex;
    if (start == null || insertIndex == start || insertIndex == start + 1) {
      end();
    }
  }

  /// 把这次拖动的登记交给 [write]，写完（成功或失败）才结束。
  ///
  /// 交出后立即清空自己的登记：写入期间再拿起一行会另起一份，不会被这次
  /// 写入的结束提前放掉。
  Future<T> holdUntil<T>(Future<T> write) {
    final lease = _lease;
    _lease = null;
    _startIndex = null;
    return write.whenComplete(() => lease?.end());
  }

  /// 结束当前登记（没有移动、或移动后不需要写库时）。
  void end() {
    _startIndex = null;
    _lease?.end();
    _lease = null;
  }

  /// 所属页面销毁时调用。
  void dispose() => end();
}
