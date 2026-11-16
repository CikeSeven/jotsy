import 'dart:async';

/// 托管媒体目录的写入闸门：让存储管理“立即清理未使用的文件”不会删掉别的
/// 流程刚放进托管目录、还没来得及写库引用的文件。
///
/// 为什么需要：局域网同步（媒体就位在写库事务之前）、同步换键拷贝、HEIC
/// 修复（先转码出 JPEG 再改写引用）与存储管理压缩（先写出新文件再改写引用）
/// 都有一段“文件已在托管目录、库里还没有引用”的窗口，其中同步与 HEIC 修复
/// 在后台进行，随时可能与存储管理页同时发生。自动回收靠按修改时间的宽限期
/// 避开这段窗口；存储管理的删除与清理不留宽限期（用户删掉日记后马上就要能
/// 清掉），改为经这道闸门：
/// - 这些流程把“放文件 → 写库”整段包进 [write]（多个写入者可以同时进行；
///   可重入：已在 [write] 里的嵌套调用直接执行，不会等自己）；
/// - 存储管理的删除与清理经 [exclusive]：先挡住新的写入者，再等已在进行的
///   写入者全部结束（有上限，超时抛 [ManagedMediaWritesPending]、什么都不
///   做），结束后放行排队的写入者。
///
/// 顺序约定（防止互相等待）：两边都必须在 `DataArchiveService.runSerialized`
/// **之外**进入闸门，再在里面排串行队列。写入者持闸门等串行队列、独占者等
/// 写入者结束后才排串行队列，谁都不会反过来等对方持有的东西。
///
/// 进程内的静态状态（与 `DataArchiveService` 的串行队列同一做法）：托管媒体
/// 只在主 isolate 里放进目录，不需要跨 isolate。
abstract final class ManagedMediaWriteGate {
  static int _writers = 0;
  static Completer<void>? _writersIdle;
  static Completer<void>? _exclusive;
  static final Object _zoneKey = Object();

  /// 现在是否有写入者在进行（测试与诊断用）。
  static bool get hasWriters => _writers > 0;

  /// 以写入者身份执行 [action]：有独占者（清理）在进行或排队时先等它结束。
  static Future<T> write<T>(Future<T> Function() action) async {
    if (Zone.current[_zoneKey] == true) return action();
    for (var gate = _exclusive; gate != null; gate = _exclusive) {
      await gate.future;
    }
    _writers++;
    try {
      return await runZoned(
        action,
        zoneValues: <Object, Object>{_zoneKey: true},
      );
    } finally {
      _writers--;
      if (_writers == 0) {
        final idle = _writersIdle;
        _writersIdle = null;
        idle?.complete();
      }
    }
  }

  /// 独占执行 [action]：挡住新的写入者，等已在进行的写入者在 [timeout] 内
  /// 全部结束；等不到时抛 [ManagedMediaWritesPending]、不执行 [action]。
  /// 多个独占者依次执行。
  static Future<T> exclusive<T>(
    Future<T> Function() action, {
    required Duration timeout,
  }) async {
    for (var gate = _exclusive; gate != null; gate = _exclusive) {
      await gate.future;
    }
    final gate = _exclusive = Completer<void>();
    try {
      if (_writers > 0) {
        final idle = _writersIdle ??= Completer<void>();
        await idle.future.timeout(
          timeout,
          onTimeout: () => throw const ManagedMediaWritesPending(),
        );
      }
      return await action();
    } finally {
      _exclusive = null;
      gate.complete();
    }
  }
}

/// [ManagedMediaWriteGate.exclusive] 等不到写入者结束（同步、HEIC 修复还在
/// 放文件或写库）。
class ManagedMediaWritesPending implements Exception {
  const ManagedMediaWritesPending();

  @override
  String toString() => 'ManagedMediaWritesPending';
}
