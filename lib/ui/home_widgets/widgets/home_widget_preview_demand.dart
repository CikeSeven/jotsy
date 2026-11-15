import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_widget_providers.dart';

/// 小组件页与工作室共用：页面在的期间让快照为全部种类计算数据
/// （[homeWidgetPreviewDemandProvider]），预览里还没放到桌面上的种类也有
/// 真实数据可画。
///
/// 进出页面时改 provider 要挪到这一帧之后：initState / dispose 发生在构建
/// 期间，Riverpod 不允许此时改 provider。notifier 在 initState 里先取好，
/// dispose 时不再经 ref（页面已卸载）。
mixin HomeWidgetPreviewDemandMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  late final HomeWidgetPreviewDemand _demand;

  @override
  void initState() {
    super.initState();
    _demand = ref.read(homeWidgetPreviewDemandProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => _demand.open());
  }

  @override
  void dispose() {
    final demand = _demand;
    WidgetsBinding.instance.addPostFrameCallback((_) => demand.close());
    super.dispose();
  }
}
