import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;

import 'app_text_context_menu.dart';

/// 只读文字的选区：长按（桌面拖选 / 右键）选字，菜单用应用统一的选区菜单
/// （手机为贴着选区的玻璃胶囊、桌面为指针处的竖排菜单，见
/// [AppTextSelectionMenu.adaptive]），与输入框的 [appTextContextMenuBuilder]
/// 同一套菜单项：复制、全选等取自 Flutter 给的 `contextMenuButtonItems`，
/// 手机上另补「分享」（选中的文字经 `onSelectionChanged` 记下）。
///
/// 用在不经输入框、也不是日记正文的只读文字上（AI 对话的回答、问题气泡
/// 等）。里面的按钮、链接照常可点；同一块里的几段文字可以连着选。
class AppSelectionArea extends StatefulWidget {
  const AppSelectionArea({super.key, required this.child});

  final Widget child;

  @override
  State<AppSelectionArea> createState() => _AppSelectionAreaState();
}

class _AppSelectionAreaState extends State<AppSelectionArea> {
  /// 当前选中的文字（分享用）；不在 build 里读，免得选区一变就重建子树。
  String _selected = '';

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      onSelectionChanged: (SelectedContent? content) =>
          _selected = content?.plainText ?? '',
      contextMenuBuilder: (BuildContext context, SelectableRegionState state) {
        final items = state.contextMenuButtonItems;
        final actions = appTextMenuActionsFromButtonItems(context, items);
        final hasShare = items.any(
          (ContextMenuButtonItem item) =>
              item.type == ContextMenuButtonType.share,
        );
        if (!hasShare) {
          final share = appTextShareAction(
            context,
            _selected,
            beforeShare: state.hideToolbar,
          );
          if (share != null) actions.add(share);
        }
        return AppTextSelectionMenu.adaptive(
          anchors: state.contextMenuAnchors,
          actions: actions,
          onDismiss: state.hideToolbar,
        );
      },
      child: widget.child,
    );
  }
}
