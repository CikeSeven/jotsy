import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../widgets/rich_text/inline_rich_text_controller.dart';

/// 当前正在编辑的主题文字输入框（格式条读它），以及格式条所在区域的焦点
/// 与颜色面板的高度。
///
/// 输入框在 initState 时 [attach]、dispose 时 [detach]：两者都可能发生在
/// 构建或卸载树的途中，此时不能同步通知（监听者会在锁住的树里 setState），
/// 所以字段立即改、通知放进微任务。[current] 在 [detach] 后立即为 null，
/// 格式条不会读到已经释放的控制器。
class MindMapTextSession extends ChangeNotifier {
  /// 格式条（含颜色面板）区域的焦点：颜色面板里的颜色代码输入框拿走焦点时
  /// [toolbarFocus] 有焦点，主题输入框不因失焦而结束编辑（见
  /// [keepsEditing]）。只作祖先节点，本身不接收焦点。
  final FocusNode toolbarFocus = FocusNode(
    debugLabel: 'mind-map-format-bar',
    skipTraversal: true,
    canRequestFocus: false,
  );

  /// 颜色面板展开的高度（0 为收起）：画布让正在编辑的节点露出来时一并让开。
  final ValueNotifier<double> panelExtent = ValueNotifier<double>(0);

  /// 主题输入框失焦时是否仍算在编辑：焦点去了格式条（颜色代码输入框）。
  bool get keepsEditing => toolbarFocus.hasFocus;

  InlineRichTextController? _current;
  bool _disposed = false;
  bool _scheduled = false;

  InlineRichTextController? get current => _current;

  void attach(InlineRichTextController controller) {
    if (identical(_current, controller)) return;
    _current = controller;
    _notifyLater();
  }

  void detach(InlineRichTextController controller) {
    if (!identical(_current, controller)) return;
    _current = null;
    _notifyLater();
  }

  /// 报告颜色面板的高度。可能在构建或卸载途中调用（画布听到后会挪视口），
  /// 一律放进微任务，会话已释放时不再写。
  void setPanelExtent(double extent) {
    scheduleMicrotask(() {
      if (!_disposed) panelExtent.value = extent;
    });
  }

  void _notifyLater() {
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    toolbarFocus.dispose();
    panelExtent.dispose();
    super.dispose();
  }
}
