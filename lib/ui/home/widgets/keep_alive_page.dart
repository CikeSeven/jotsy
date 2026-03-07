import 'package:flutter/material.dart';

/// 用于避免切页时销毁页面，保留列表滚动位置和页面局部状态。
class KeepAlivePage extends StatefulWidget {
  const KeepAlivePage({super.key, required this.child});
  final Widget child;
  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage> 
    with AutomaticKeepAliveClientMixin<KeepAlivePage>{
      @override
      bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}