import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/app_platform.dart';
import '../../controllers/diary_editor_clipboard.dart';
import '../../controllers/diary_editor_controller.dart';

/// 桌面只读正文的复制与全选。选中文字时接管该正文的焦点，不连接输入法，
/// 也不开放上游的编辑命令；翻页、Esc 等按键继续交给页面。
class DiaryReadOnlyShortcuts extends StatefulWidget {
  const DiaryReadOnlyShortcuts({
    super.key,
    required this.controller,
    required this.enabled,
    required this.child,
    this.focusNode,
  });

  final DiaryEditorController controller;
  final bool enabled;
  final Widget child;
  final FocusNode? focusNode;

  @override
  State<DiaryReadOnlyShortcuts> createState() => _DiaryReadOnlyShortcutsState();
}

class _DiaryReadOnlyShortcutsState extends State<DiaryReadOnlyShortcuts> {
  final FocusNode _ownFocus = FocusNode(debugLabel: 'readonly_diary');
  FocusNode get _focus => widget.focusNode ?? _ownFocus;

  @override
  void initState() {
    super.initState();
    widget.controller.state.selectionNotifier.addListener(_onSelection);
  }

  @override
  void didUpdateWidget(DiaryReadOnlyShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.state.selectionNotifier.removeListener(_onSelection);
      widget.controller.state.selectionNotifier.addListener(_onSelection);
    }
  }

  void _onSelection() {
    if (!AppPlatform.isDesktop || !widget.enabled) return;
    final selection = widget.controller.state.selection;
    if (selection != null && !selection.isCollapsed) _focus.requestFocus();
  }

  @override
  void dispose() {
    widget.controller.state.selectionNotifier.removeListener(_onSelection);
    _ownFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppPlatform.isDesktop || !widget.enabled) return widget.child;
    final apple = AppPlatform.isMacOS;
    return CallbackShortcuts(
      bindings: {
        SingleActivator(
          LogicalKeyboardKey.keyC,
          control: !apple,
          meta: apple,
        ): () =>
            unawaited(DiaryEditorClipboard.copy(widget.controller)),
        SingleActivator(
          LogicalKeyboardKey.keyA,
          control: !apple,
          meta: apple,
        ): () =>
            af.selectAllCommand.handler(widget.controller.state),
      },
      child: Focus(focusNode: _focus, child: widget.child),
    );
  }
}
