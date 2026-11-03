import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/app_platform.dart';

/// 菜单项在文字选区菜单里的归属，决定它排在哪一组、手机胶囊上放在哪一行。
///
/// - [lead]：排在最前的一组（如 AI 写作）。桌面竖排菜单里单独成组、在最上面，
///   与下一组之间有分隔线；手机胶囊上与 [primary] 同在主行，排在它们后面。
///   主行放不下时与 [primary] 一样从末尾挪进次要区（因此最先挪走）。
/// - [primary]：编辑类操作（剪切、复制、粘贴、全选、删除），手机上在主行。
/// - [secondary]：其余操作（分享、查询、网页搜索、其他应用的文字处理），
///   手机上收在「更多」后面，桌面上排在最后一组。
enum AppTextMenuSlot { lead, primary, secondary }

/// 文字选区菜单的一项：手机胶囊 [AppTextSelectionToolbar] 与桌面竖排菜单
/// [AppTextContextMenuPanel] 共用的数据。
///
/// 点按时只调用 [onPressed]，收起菜单由调用方负责（输入框里 Flutter 自带的
/// 动作会自己收起工具栏）。
@immutable
class AppTextMenuAction {
  const AppTextMenuAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.slot = AppTextMenuSlot.primary,
    this.shortcut,
  });

  final String label;

  /// `FontAwesomeIcons` 里的图标，由菜单统一定尺寸与颜色。
  final FaIconData icon;
  final VoidCallback onPressed;
  final AppTextMenuSlot slot;

  /// 桌面竖排菜单行尾的快捷键提示（如 `Ctrl+C` / `⌘C`）；手机上不显示。
  final String? shortcut;

  AppTextMenuAction copyWith({AppTextMenuSlot? slot}) => AppTextMenuAction(
    label: label,
    icon: icon,
    onPressed: onPressed,
    slot: slot ?? this.slot,
    shortcut: shortcut,
  );

  @override
  String toString() => 'AppTextMenuAction($label, $slot)';
}

/// 输入框按钮类型对应的图标。
FaIconData appTextMenuIconOf(ContextMenuButtonType type) => switch (type) {
  ContextMenuButtonType.cut => FontAwesomeIcons.scissors,
  ContextMenuButtonType.copy => FontAwesomeIcons.copy,
  ContextMenuButtonType.paste => FontAwesomeIcons.paste,
  ContextMenuButtonType.selectAll => FontAwesomeIcons.objectGroup,
  ContextMenuButtonType.delete => FontAwesomeIcons.deleteLeft,
  ContextMenuButtonType.share => FontAwesomeIcons.shareNodes,
  ContextMenuButtonType.lookUp => FontAwesomeIcons.book,
  ContextMenuButtonType.searchWeb => FontAwesomeIcons.globe,
  ContextMenuButtonType.liveTextInput => FontAwesomeIcons.camera,
  // 其余都是外来动作（Android 的 ProcessText 等），统一用“交给别的应用”。
  ContextMenuButtonType.custom => FontAwesomeIcons.arrowUpRightFromSquare,
};

/// 输入框按钮类型的归属：编辑类在主行，其余收进次要区。
AppTextMenuSlot appTextMenuSlotOf(ContextMenuButtonType type) => switch (type) {
  ContextMenuButtonType.cut ||
  ContextMenuButtonType.copy ||
  ContextMenuButtonType.paste ||
  ContextMenuButtonType.selectAll ||
  ContextMenuButtonType.delete => AppTextMenuSlot.primary,
  ContextMenuButtonType.share ||
  ContextMenuButtonType.lookUp ||
  ContextMenuButtonType.searchWeb ||
  ContextMenuButtonType.liveTextInput ||
  ContextMenuButtonType.custom => AppTextMenuSlot.secondary,
};

/// 桌面上剪切 / 复制 / 粘贴 / 全选的快捷键提示，其余类型与手机上为 null。
///
/// macOS 按系统习惯写 `⌘X`（修饰键符号直接接字母、不加号），其他桌面写
/// `Ctrl+X`。只是提示文字，真正的快捷键仍由输入框 / 正文自己处理。
String? appTextMenuShortcutOf(ContextMenuButtonType type) {
  if (!AppPlatform.isDesktop) return null;
  final key = switch (type) {
    ContextMenuButtonType.cut => 'X',
    ContextMenuButtonType.copy => 'C',
    ContextMenuButtonType.paste => 'V',
    ContextMenuButtonType.selectAll => 'A',
    _ => null,
  };
  if (key == null) return null;
  return AppPlatform.isMacOS ? '⌘$key' : 'Ctrl+$key';
}

/// 把 Flutter 输入框给出的按钮（`EditableTextState.contextMenuButtonItems`）
/// 换成菜单项，顺序不变。
///
/// - 文字：内置类型一律经 [AdaptiveTextSelectionToolbar.getButtonLabel]（与系统
///   工具栏同一份本地化，按平台取 Material / Cupertino 文案）；`custom` 类型用
///   它自带的 `label`（Android ProcessText 的应用名），没有文字的跳过。
/// - 没有 `onPressed` 的按钮（禁用态）不列出：选区菜单里放一个点了没反应的
///   按钮没有意义，Flutter 自己也只在动作可用时才给出按钮。
List<AppTextMenuAction> appTextMenuActionsFromButtonItems(
  BuildContext context,
  Iterable<ContextMenuButtonItem> items,
) => <AppTextMenuAction>[
  for (final item in items)
    if (item.onPressed case final VoidCallback onPressed)
      if (_labelOf(context, item) case final String label when label.isNotEmpty)
        AppTextMenuAction(
          label: label,
          icon: appTextMenuIconOf(item.type),
          onPressed: onPressed,
          slot: appTextMenuSlotOf(item.type),
          shortcut: appTextMenuShortcutOf(item.type),
        ),
];

String _labelOf(BuildContext context, ContextMenuButtonItem item) =>
    item.type == ContextMenuButtonType.custom
    ? item.label ?? ''
    : AdaptiveTextSelectionToolbar.getButtonLabel(context, item);
