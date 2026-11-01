import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;

import '../../../../core/services/app_platform.dart';
import '../../controllers/diary_editor_clipboard.dart';
import '../../controllers/diary_editor_controller.dart';

/// 原生块选区的复制/剪切/粘贴入口。使用 Flutter 平台文本菜单和 AppFlowy
/// 选区几何，编辑页的格式工具仍留在既有底部卡片中，不另造一套格式工具。
///
/// 手机在选出一段文字后自动浮在选区上方；可编辑正文里长按松手（或拖完
/// 把手）只落下光标时——空段落、行尾空白，以及 iOS 上任意位置的长按——
/// 浮在光标上方，只有粘贴与全选（见 `_trackCaretMenu`）。桌面与系统
/// 文本框一致，选中时不出现（否则盖住文字与指针），只在右键时经
/// [diaryEditorContextMenuBuilder] 出现在指针处。
class DiaryEditorSelectionToolbar extends StatefulWidget {
  const DiaryEditorSelectionToolbar({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
  });
  final DiaryEditorController controller;
  final Widget child;
  final bool enabled;
  @override
  State<DiaryEditorSelectionToolbar> createState() =>
      _DiaryEditorSelectionToolbarState();
}

class _DiaryEditorSelectionToolbarState
    extends State<DiaryEditorSelectionToolbar> {
  static _DiaryEditorSelectionToolbarState? _active;
  OverlayEntry? _entry;
  ScrollPosition? _parentScroll;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_schedule);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _parentScroll) {
      _parentScroll?.removeListener(_hide);
      _parentScroll = position;
      _parentScroll?.addListener(_hide);
    }
  }

  @override
  void didUpdateWidget(DiaryEditorSelectionToolbar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_schedule);
      widget.controller.addListener(_schedule);
      _caretMenu = null;
      _hide();
    }
  }

  void _schedule() {
    _trackCaretMenu();
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final selection = widget.controller.state.selection;
      if (!widget.enabled ||
          AppPlatform.isDesktop ||
          selection == null ||
          (selection.isCollapsed && selection != _caretMenu)) {
        _hide();
      } else {
        _show();
      }
    });
  }

  /// 长按松手后落下的光标；非 null 时手机在光标上方出菜单（粘贴、全选）。
  af.Selection? _caretMenu;

  /// 每次控制器通知时同步更新 [_caretMenu]（不等到下一帧：期间可能还有
  /// 别的选区更新覆盖掉判定依据）。
  ///
  /// 上游手机选区服务在长按结束（Android 与 iOS）和拖完选区把手时，都以
  /// uiEvent 原因、`doNotAttachTextService: false` 交还选区，且不带“禁止
  /// 浮动工具栏”；点按、横滑移动光标（带禁止标记）、输入与程序设的选区
  /// 都不满足。长按空段落时上游取到的词边界是空的（折叠选区），过去手机
  /// 菜单只认非折叠选区，因此不出菜单、无从粘贴（#119）。
  ///
  /// 正文原本没有焦点时，长按松手才连接输入法并取得焦点，`DiaryEditor`
  /// 的 `_onFocus` 随即以 transaction 原因把同一选区重设一次，覆盖掉这组
  /// 信息；所以记住这次请求，只在选区变化（输入、粘贴、程序换选区）或
  /// 又有一次手势（点按等 uiEvent）时清除。只读正文没有插入点，不出菜单。
  void _trackCaretMenu() {
    final controller = widget.controller;
    if (controller.readOnly || controller.state.isDisposed) {
      _caretMenu = null;
      return;
    }
    final state = controller.state;
    final selection = state.selection;
    final uiEvent =
        state.selectionUpdateReason == af.SelectionUpdateReason.uiEvent;
    final info = state.selectionExtraInfo;
    final released =
        uiEvent &&
        info != null &&
        info[af.selectionExtraInfoDoNotAttachTextService] == false &&
        info[af.selectionExtraInfoDisableFloatingToolbar] != true;
    if (released && selection != null && selection.isCollapsed) {
      _caretMenu = selection;
    } else if (selection != _caretMenu || (uiEvent && !released)) {
      _caretMenu = null;
    }
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
    if (identical(_active, this)) _active = null;
  }

  void _show() {
    if (_active != this) _active?._hide();
    _active = this;
    if (_entry != null) {
      _entry!.markNeedsBuild();
      return;
    }
    _entry = OverlayEntry(
      builder: (_) {
        if (!mounted || widget.controller.state.isDisposed) {
          return const SizedBox.shrink();
        }
        final controller = widget.controller;
        final rects = controller.state.selectionRects();
        if (rects.isEmpty) return const SizedBox.shrink();
        final selection = controller.selection;
        if (selection == null) return const SizedBox.shrink();
        return Theme(
          data: Theme.of(context),
          child: AdaptiveTextSelectionToolbar.buttonItems(
            anchors: TextSelectionToolbarAnchors(
              primaryAnchor: rects.first.topCenter,
              secondaryAnchor: rects.last.bottomCenter,
            ),
            buttonItems: _menuItems(
              controller,
              // 点过菜单项就不再是“刚长按”：粘贴空剪贴板时选区不变，也不能
              // 在下一次通知时把菜单弹回来。
              dismiss: () {
                _caretMenu = null;
                _hide();
              },
              // 与系统文本框一致，手机复制后把选区收成光标。
              afterCopy: () {
                _caretMenu = null;
                _hide();
                if (!controller.state.isDisposed) {
                  controller.select(af.Selection.collapsed(selection.end));
                }
              },
            ),
          ),
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  @override
  void dispose() {
    _hide();
    widget.controller.removeListener(_schedule);
    _parentScroll?.removeListener(_hide);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 桌面正文的右键菜单，交给 [af.AppFlowyEditor.contextMenuBuilder]。
///
/// 上游桌面选区服务在右键时先按位置调整选区（点在已选的段落里保留选区，
/// 否则把光标移到该处），再插入菜单与一层透明遮罩：在菜单外按下指针、选区
/// 清空或调用 dismiss 时一并收起，并在菜单开着时屏蔽正文输入。这里只负责
/// 画菜单与执行动作。
af.ContextMenuWidgetBuilder diaryEditorContextMenuBuilder(
  DiaryEditorController controller,
) =>
    (context, position, editorState, dismiss) => Theme(
      data: Theme.of(context),
      child: _DiaryEditorContextMenu(
        controller: controller,
        // 上游把指针位置向右下偏移 10 再交出；系统文本框的右键菜单以指针为
        // 左上角，这里还原，与标题等输入框一致。
        anchor: position - const Offset(10, 10),
        dismiss: dismiss,
      ),
    );

class _DiaryEditorContextMenu extends StatefulWidget {
  const _DiaryEditorContextMenu({
    required this.controller,
    required this.anchor,
    required this.dismiss,
  });
  final DiaryEditorController controller;
  final Offset anchor;
  final VoidCallback dismiss;

  @override
  State<_DiaryEditorContextMenu> createState() =>
      _DiaryEditorContextMenuState();
}

class _DiaryEditorContextMenuState extends State<_DiaryEditorContextMenu> {
  final FocusNode _focus = FocusNode(debugLabel: 'diary_editor_context_menu');
  FocusNode? _previous;

  @override
  void initState() {
    super.initState();
    // 菜单开着时上游让正文失焦；焦点移到菜单上，Esc 才会先收起菜单，而不是
    // 落到页面（编辑页的 Esc 是返回）。
    _previous = primaryFocus;
    _focus.requestFocus();
  }

  @override
  void dispose() {
    // 编辑态收起时上游会重新聚焦正文，菜单此时已不持有焦点；只读正文没有
    // 上游键盘服务，由这里把焦点还给打开菜单前的位置。
    final previous = _previous;
    if (_focus.hasFocus && previous != null && previous.context != null) {
      previous.requestFocus();
    }
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        widget.dismiss();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: AdaptiveTextSelectionToolbar.buttonItems(
      anchors: TextSelectionToolbarAnchors(primaryAnchor: widget.anchor),
      // 桌面复制后保留选区，与系统文本框一致。
      buttonItems: _menuItems(
        widget.controller,
        dismiss: widget.dismiss,
        afterCopy: widget.dismiss,
      ),
    ),
  );
}

/// 两端共用的菜单项：有选中文字时才有复制 / 剪切，可编辑时才有剪切 /
/// 粘贴（桌面右键可落在光标上，此时只有粘贴与全选）。[dismiss] 收起菜单，
/// [afterCopy] 在写入剪贴板后执行。
List<ContextMenuButtonItem> _menuItems(
  DiaryEditorController controller, {
  required VoidCallback dismiss,
  required VoidCallback afterCopy,
}) {
  final selection = controller.selection;
  final ranged = selection != null && !selection.isCollapsed;
  return [
    if (ranged)
      ContextMenuButtonItem(
        type: ContextMenuButtonType.copy,
        onPressed: () => unawaited(
          DiaryEditorClipboard.copy(controller).then((_) => afterCopy()),
        ),
      ),
    if (!controller.readOnly) ...[
      if (ranged)
        ContextMenuButtonItem(
          type: ContextMenuButtonType.cut,
          onPressed: () {
            dismiss();
            unawaited(DiaryEditorClipboard.cut(controller));
          },
        ),
      ContextMenuButtonItem(
        type: ContextMenuButtonType.paste,
        onPressed: () {
          dismiss();
          unawaited(DiaryEditorClipboard.paste(controller));
        },
      ),
    ],
    ContextMenuButtonItem(
      type: ContextMenuButtonType.selectAll,
      onPressed: () {
        dismiss();
        af.selectAllCommand.handler(controller.state);
      },
    ),
  ];
}
