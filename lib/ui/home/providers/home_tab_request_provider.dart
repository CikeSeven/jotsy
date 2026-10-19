import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 首页之外的页面请求切回“日记”Tab（例如预览页里点日记本胶囊：回到首页
/// 并在日记页打开那本）。
///
/// 状态是请求的序号：每次 [request] 加一，`HomePage` 监听到变化就切到日记
/// Tab；已在日记 Tab 时什么也不做。只在内存里，不需要初始化，测试也无需
/// 替换。
class HomeDiariesTabRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state = state + 1;
}

final homeDiariesTabRequestProvider =
    NotifierProvider<HomeDiariesTabRequestNotifier, int>(
      HomeDiariesTabRequestNotifier.new,
    );
