import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../models/home_tab.dart';

/// 一次“切到某个 Tab”的请求。[serial] 每次请求加一，同一个 Tab 连续请求
/// 也能被监听到。
@immutable
class HomeTabRequest {
  const HomeTabRequest(this.serial, this.tab);

  final int serial;
  final HomeTab tab;

  @override
  bool operator ==(Object other) =>
      other is HomeTabRequest && other.serial == serial && other.tab == tab;

  @override
  int get hashCode => Object.hash(serial, tab);
}

/// 首页之外的页面请求切到某个 Tab（预览页里点日记本胶囊：回到首页并在
/// 日记页打开那本；AI 助手的“前往待办 / 日历 / 探索 / 设置”）。
///
/// `HomePage` 监听到变化就切过去；已在该 Tab、或该 Tab 因功能关闭不可见
/// 时什么也不做。调用方负责先回到首页（`popUntil(isFirst)`）。只在内存里，
/// 不需要初始化，测试也无需替换。
class HomeTabRequestNotifier extends Notifier<HomeTabRequest> {
  @override
  HomeTabRequest build() => const HomeTabRequest(0, HomeTab.diaries);

  void request([HomeTab tab = HomeTab.diaries]) =>
      state = HomeTabRequest(state.serial + 1, tab);
}

final homeTabRequestProvider =
    NotifierProvider<HomeTabRequestNotifier, HomeTabRequest>(
      HomeTabRequestNotifier.new,
    );
