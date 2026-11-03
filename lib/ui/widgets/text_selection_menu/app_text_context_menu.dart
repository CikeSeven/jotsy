import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/app_platform.dart';
import 'app_text_context_menu_panel.dart';
import 'app_text_menu_action.dart';
import 'app_text_selection_toolbar.dart';

export 'app_text_context_menu_panel.dart';
export 'app_text_menu_action.dart';
export 'app_text_selection_toolbar.dart';

/// 应用统一的文字选区菜单入口：手机为贴着选区的玻璃胶囊
/// [AppTextSelectionToolbar]，桌面为指针处的竖排菜单 [AppTextContextMenuPanel]。
///
/// - 输入框：把 [appTextContextMenuBuilder] 传给 `contextMenuBuilder`。
/// - 日记正文（AppFlowy，自己管理选区浮层）：自己组装菜单项，经
///   [AppTextSelectionMenu.adaptive] 放进自己的 OverlayEntry；分享与其他应用的
///   文字处理可用 [appTextShareAction] / [appTextProcessAction] 生成。
abstract final class AppTextSelectionMenu {
  /// 按平台挑选菜单：桌面（[AppPlatform.isDesktop]）为竖排菜单，左上角在
  /// `anchors.primaryAnchor`（右键时即指针位置），Esc 调 [onDismiss]；手机为
  /// 胶囊（[onDismiss] 不使用，点外部收起由调用方负责）。
  ///
  /// 换一个 [key] 会重新挂载（回到收起态并重播入场动画）；只想在选区变了时
  /// 收起展开的次要区，直接用 [AppTextSelectionToolbar] 的 `collapseScope`。
  static Widget adaptive({
    Key? key,
    required TextSelectionToolbarAnchors anchors,
    required List<AppTextMenuAction> actions,
    required VoidCallback onDismiss,
  }) => AppPlatform.isDesktop
      ? AppTextContextMenuPanel(
          key: key,
          anchor: anchors.primaryAnchor,
          actions: actions,
          onDismiss: onDismiss,
        )
      : AppTextSelectionToolbar(key: key, anchors: anchors, actions: actions);
}

/// 「分享」：把 [text] 交给系统分享面板。只在 [AppPlatform.supportsTextShare]
/// 且 [text] 不全是空白时给出，否则为 null。[beforeShare] 在分享前调用
/// （通常是收起菜单：分享面板盖上来后菜单不该还留在原地）。
AppTextMenuAction? appTextShareAction(
  BuildContext context,
  String text, {
  VoidCallback? beforeShare,
}) {
  if (text.trim().isEmpty) return null;
  return appTextShareActionOf(context, () => text, beforeShare: beforeShare);
}

/// 「分享」的按需取文字版本：点按时才调用 [textOf] 取要分享的文字，适合
/// 取文字代价大、菜单又会频繁重建的场合（日记正文拖动选区把手时每帧重建，
/// 不能每帧把整段选区序列化一遍）。只在 [AppPlatform.supportsTextShare] 时
/// 给出；点按时先调 [beforeShare]，取到的文字为 null 或全是空白就只收起、
/// 不打开分享面板。
AppTextMenuAction? appTextShareActionOf(
  BuildContext context,
  String? Function() textOf, {
  VoidCallback? beforeShare,
}) {
  if (!AppPlatform.supportsTextShare) return null;
  final item = ContextMenuButtonItem(
    type: ContextMenuButtonType.share,
    onPressed: () {},
  );
  return AppTextMenuAction(
    label: AdaptiveTextSelectionToolbar.getButtonLabel(context, item),
    icon: appTextMenuIconOf(ContextMenuButtonType.share),
    slot: appTextMenuSlotOf(ContextMenuButtonType.share),
    onPressed: () {
      // 先取文字再收起：收起菜单的回调可能改动选区（如收成光标）。
      final text = textOf();
      beforeShare?.call();
      if (text == null || text.trim().isEmpty) return;
      Share.share(text);
    },
  );
}

/// 其他应用的文字处理动作（`TextProcessActionsService` 查到的一项），归在
/// 次要区，图标同输入框里的 `custom` 项。
AppTextMenuAction appTextProcessAction(
  ProcessTextAction action, {
  required VoidCallback onPressed,
}) => AppTextMenuAction(
  label: action.label,
  icon: appTextMenuIconOf(ContextMenuButtonType.custom),
  slot: appTextMenuSlotOf(ContextMenuButtonType.custom),
  onPressed: onPressed,
);

/// 输入框（TextField / TextFormField / SelectableText / SearchBar）的
/// `contextMenuBuilder`：签名即 `EditableTextContextMenuBuilder`。
///
/// 菜单项取自 Flutter 给出的 `state.contextMenuButtonItems`（含 Android 的
/// ProcessText 与 iOS 的查询 / 搜索），只换外观；另在手机上补「分享」：
/// Flutter 只在部分情况下自带分享（如选中的不全是空白），列表里还没有分享、
/// 选区不是插入点、也不是密码框时才补，点按先收起工具栏再分享。
///
/// 手机用 `state.contextMenuAnchors` 出胶囊，桌面出竖排菜单（左上角在
/// `primaryAnchor`，右键时即指针位置），Esc 收起工具栏。
Widget appTextContextMenuBuilder(
  BuildContext context,
  EditableTextState state,
) {
  final items = state.contextMenuButtonItems;
  final actions = appTextMenuActionsFromButtonItems(context, items);
  final value = state.textEditingValue;
  final selection = value.selection;
  final hasShare = items.any(
    (ContextMenuButtonItem item) => item.type == ContextMenuButtonType.share,
  );
  if (!hasShare &&
      !state.widget.obscureText &&
      selection.isValid &&
      !selection.isCollapsed) {
    final share = appTextShareAction(
      context,
      selection.textInside(value.text),
      beforeShare: state.hideToolbar,
    );
    if (share != null) actions.add(share);
  }
  return AppTextSelectionMenu.adaptive(
    anchors: state.contextMenuAnchors,
    actions: actions,
    onDismiss: state.hideToolbar,
  );
}
