import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一个 ProviderContainer 内所有闲置查询共用的预算。活动查询不登记，不能
/// 因预算而释放当前页面；恢复监听时移出，下一次闲置重新排到 LRU 末尾。
/// 文本字节是保守估计，不包含数据库、图片与活动页面的资源。
class QueryRetentionBudget {
  QueryRetentionBudget({
    this.maxEntries = 12,
    this.maxBytes = 32 * 1024 * 1024,
  });

  final int maxEntries;
  final int maxBytes;
  final _idle = <Object, ({int Function() bytes, void Function() release})>{};

  int get idleEntries => _idle.length;
  int get retainedBytes =>
      _idle.values.fold(0, (total, entry) => total + entry.bytes());

  void retain(
    Object key, {
    required int Function() bytes,
    required void Function() release,
  }) {
    _idle.remove(key);
    _idle[key] = (bytes: bytes, release: release);
    trim();
  }

  void forget(Object key) => _idle.remove(key);

  void release(Object key) => _idle.remove(key)?.release();

  /// 闲置中的流仍可能推送新结果；大小变化后也检查，不能只在离开页面时限额。
  void trim() {
    while (_idle.isNotEmpty &&
        (_idle.length > maxEntries || retainedBytes > maxBytes)) {
      release(_idle.keys.first);
    }
  }
}

final queryRetentionBudgetProvider = Provider<QueryRetentionBudget>(
  (ref) => QueryRetentionBudget(),
);
