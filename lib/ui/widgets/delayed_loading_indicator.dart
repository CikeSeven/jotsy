import 'package:flutter/material.dart';

import '../../app/theme/expressive_motion.dart';
import 'delayed_loading_gate.dart';
import 'expressive_entrance.dart';
import 'expressive_loading_indicator.dart';

/// 页面首屏等待：等待超过 [DelayedLoadingGate.defaultDelay] 才淡入居中的
/// [ExpressiveLoadingIndicator]，在此之前保持空白。
///
/// 只放在 `AsyncValue.when(loading: …)` 这类“仅等待期间才被构建”的分支里：
/// 挂载即开始计时，数据就绪后整个分支被替换，计时器随 dispose 取消，所以门控
/// 输入恒为 true。
///
/// 为什么不直接画指示器：预览、编辑、归档、回收站等页面的数据来自本地库，
/// 通常在路由转场的头一两帧内就返回，立即画出的指示器只会在页面滑入途中闪一
/// 下（DESIGN.md §4.3“加载反馈防闪”）。慢查询仍会在 300ms 后得到明确反馈，
/// 指示器本身也淡入，不会“啪”地冒出来。
class DelayedLoadingIndicator extends StatelessWidget {
  const DelayedLoadingIndicator({
    super.key,
    this.size = 40,
    this.semanticLabel,
  });

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return DelayedLoadingGate(
      loading: true,
      builder: (BuildContext context, bool showLoading) {
        if (!showLoading) {
          return const SizedBox.shrink();
        }
        return Center(
          child: ExpressiveEntrance(
            offset: Offset.zero,
            duration: ExpressiveMotion.fast,
            child: ExpressiveLoadingIndicator(
              size: size,
              semanticLabel: semanticLabel,
            ),
          ),
        );
      },
    );
  }
}
