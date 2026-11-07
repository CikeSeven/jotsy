import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'query_retention_budget.dart';

/// 自动释放的查询在短暂失去监听后保留结果，避免返回/来回切换时闪出加载态。
const Duration queryIdleRetention = Duration(seconds: 30);

/// 只在最后一个活跃监听者离开后计时，恢复监听即取消；重新离开重新计时。
///
/// 保活链接在构建时取得（Riverpod 禁止在生命周期回调里调用 keepAlive）。
/// 超时只是放开保活，不会释放仍被页面监听的实例；销毁时取消定时器，避免
/// 容器关闭后还有回调。应只用于 autoDispose provider。
/// 返回的回调在结果大小变化时调用，让闲置流的新结果也受合计预算约束。
void Function() retainQueryWhileRecentlyUsed(
  Ref ref, {
  int Function()? estimatedBytes,
}) {
  final link = ref.keepAlive();
  final budget = ref.read(queryRetentionBudgetProvider);
  final key = Object();
  Timer? releaseTimer;
  ref.onCancel(() {
    releaseTimer?.cancel();
    releaseTimer = Timer(queryIdleRetention, () => budget.release(key));
    budget.retain(
      key,
      bytes: estimatedBytes ?? () => 0,
      release: () {
        releaseTimer?.cancel();
        link.close();
      },
    );
  });
  void leaveBudget() {
    releaseTimer?.cancel();
    budget.forget(key);
  }

  ref.onResume(leaveBudget);
  ref.onDispose(leaveBudget);
  return budget.trim;
}
