import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 编辑页“符合条件：N 篇”的实时篇数：按草稿规则现算。
///
/// 输入：每次规则变化调用 [update]；输出：[count]（null 表示还没有结果）与
/// [loading]，变化时通知。副作用：订阅数据库的计数查询。
///
/// - 防抖 [debounce]（非动画计时）：连续增删、切换组合方式时只在停下后查询；
///   等待与查询期间保留上一次的篇数，[loading] 为 true，界面经
///   `DelayedLoadingGate` 决定要不要显示等待；
/// - 用 `watchScopedDiaryCount` 订阅而不是读一次：编辑期间别处写了日记（如
///   分屏）也会跟着变；换规则时先取消旧订阅，旧结果不会晚到覆盖新结果；
/// - 空规则不查询，篇数直接为 0（编译结果本就是“不匹配”）；
/// - 口径与智能日记本本身一致：同一个编译器 + 智能范围的私密排除，只算
///   未删除、未归档的日记。
class NotebookRuleCountController extends ChangeNotifier {
  NotebookRuleCountController(this.database);

  /// 改规则后的计数防抖（非动画计时，AGENTS.md §6 允许）。
  static const Duration debounce = Duration(milliseconds: 300);

  /// 草稿规则没有日记本 id，用一个不会与真实 id 相撞的占位（只影响范围对象
  /// 的相等比较，不进 SQL）。
  static const String _draftNotebookId = '_draft_rules_';

  final AppDatabase database;

  Timer? _timer;
  StreamSubscription<int>? _subscription;
  NotebookRuleSet? _rules;
  bool _disposed = false;

  int? _count;
  int? get count => _count;

  bool _loading = false;
  bool get loading => _loading;

  /// 规则变了：防抖后重新订阅。与上次相同的规则不重复查询。
  void update(NotebookRuleSet rules) {
    if (rules == _rules) return;
    _rules = rules;
    _timer?.cancel();
    if (rules.isEmpty) {
      unawaited(_subscription?.cancel());
      _subscription = null;
      _set(count: 0, loading: false);
      return;
    }
    _set(count: _count, loading: true);
    _timer = Timer(debounce, () => _subscribe(rules));
  }

  void _subscribe(NotebookRuleSet rules) {
    unawaited(_subscription?.cancel());
    _subscription = database
        .watchScopedDiaryCount(
          DiarySmartScope(
            notebookId: _draftNotebookId,
            predicate: compileNotebookRules(rules),
          ),
        )
        .listen(
          (int value) => _set(count: value, loading: false),
          onError: (Object error) {
            debugPrint('Counting smart notebook rules failed: $error');
            _set(count: null, loading: false);
          },
        );
  }

  void _set({required int? count, required bool loading}) {
    if (_disposed || (count == _count && loading == _loading)) return;
    _count = count;
    _loading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
