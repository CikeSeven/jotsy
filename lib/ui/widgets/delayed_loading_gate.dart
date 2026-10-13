import 'dart:async';

import 'package:flutter/widgets.dart';

/// 延迟显示 loading 的门控。
///
/// 输入：[loading] 为数据层真实加载态；输出：仅当加载持续超过 [delay] 时，
/// [builder] 才收到 `showLoading == true`。加载结束立即回到 false。
///
/// 用途：family provider 换 key、本地数据库查询等通常在几毫秒内返回，
/// 若每次都立刻渲染指示器/遮罩，用户看到的只是“闪一下”。慢查询仍会在
/// [delay] 后得到明确的等待反馈。
class DelayedLoadingGate extends StatefulWidget {
  const DelayedLoadingGate({
    super.key,
    required this.loading,
    required this.builder,
    this.delay = defaultDelay,
  });

  static const Duration defaultDelay = Duration(milliseconds: 300);

  final bool loading;
  final Duration delay;
  final Widget Function(BuildContext context, bool showLoading) builder;

  @override
  State<DelayedLoadingGate> createState() => _DelayedLoadingGateState();
}

class _DelayedLoadingGateState extends State<DelayedLoadingGate> {
  Timer? _timer;
  bool _showLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.loading) {
      _scheduleShow();
    }
  }

  @override
  void didUpdateWidget(covariant DelayedLoadingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading == oldWidget.loading) {
      return;
    }
    if (widget.loading) {
      _scheduleShow();
      return;
    }
    // 加载结束：取消待触发的计时器，并在本次 build 中直接隐藏。
    _timer?.cancel();
    _timer = null;
    _showLoading = false;
  }

  void _scheduleShow() {
    _timer?.cancel();
    _timer = Timer(widget.delay, () {
      _timer = null;
      if (mounted && widget.loading) {
        setState(() => _showLoading = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _showLoading);
}
