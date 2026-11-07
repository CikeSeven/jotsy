import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../models/explore_computation_input.dart';
import '../models/explore_module_data.dart';
import '../viewmodels/explore_entry.dart';

/// worker 返回计算结果和逐篇解析缓存；Isolate.exit 将所有权交还给 UI，
/// 下次只修改标签或一篇正文时仍能复用，其余条目不用重新解析、统计字数。
typedef ExploreComputationResult = ({
  ExploreData data,
  ExploreEntryCache cache,
});
typedef ExploreComputationRunner =
    Future<ExploreComputationResult> Function(
      ExploreComputationInput input,
      ExploreEntryCache cache,
    );

Future<ExploreComputationResult> _compute(
  (ExploreComputationInput, ExploreEntryCache) message,
) async {
  // isolate 不继承 intl 的日期符号缓存；“那年今日”在非中文下会格式化日期。
  await initializeDateFormatting(message.$1.l10n.localeName);
  return (data: message.$1.build(message.$2), cache: message.$2);
}

Future<ExploreComputationResult> _runWorker(
  ExploreComputationInput input,
  ExploreEntryCache cache,
) => compute(_compute, (input, cache), debugLabel: 'explore.compute');

/// 探索计算会话：输入概览和筛选配置，输出当前配置的聚合结果/错误。
/// 不做 IO，也不持有页面、provider 或数据库。
///
/// 一次最多运行一个 worker，只保留最新的待处理输入。范围快速切换或数据库
/// 连续推送时，不并发复制多份全库，也不让晚到的旧统计覆盖新配置。输入一变
/// 就撤下旧结果（私密/删除过滤后的旧日记不能在计算期间继续显示）。销毁后
/// 只等已启动任务结束释放资源，不通知已卸载的页面。
class ExploreComputationController extends ChangeNotifier {
  ExploreComputationController({ExploreComputationRunner? runner})
    : _runner = runner ?? _runWorker;

  final ExploreComputationRunner _runner;
  ExploreEntryCache _cache = ExploreEntryCache();
  ExploreComputationInput? _input;
  ExploreComputationInput? _pending;
  ExploreData? _data;
  Object? _error;
  bool _running = false;
  bool _disposed = false;

  Object? get error => _error;

  /// 在 build 中调用：同步结果直接返回，异步完成才通知，不在构建期间通知。
  ExploreData? resolve(ExploreComputationInput input) {
    if (_input?.sameAs(input) ?? false) return _data;
    _input = input;
    _data = null;
    _error = null;
    if (!_running && !input.needsWorker) {
      return _data = input.build(_cache);
    }
    _pending = input;
    if (!_running) unawaited(_drain());
    return null;
  }

  Future<void> _drain() async {
    _running = true;
    while (!_disposed && _pending != null) {
      final input = _pending!;
      _pending = null;
      try {
        final result = await _runner(input, _cache);
        if (_disposed) break;
        _cache = result.cache;
        if (identical(input, _input)) _data = result.data;
      } catch (error) {
        if (_disposed) break;
        if (identical(input, _input)) _error = error;
      }
      if (identical(input, _input) && !_disposed) notifyListeners();
    }
    _running = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _input = null;
    _pending = null;
    _data = null;
    _cache = ExploreEntryCache();
    super.dispose();
  }
}
