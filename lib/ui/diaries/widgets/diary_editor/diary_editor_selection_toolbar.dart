import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../controllers/diary_editor_clipboard.dart';
import '../../controllers/diary_editor_controller.dart';

/// 原生块选区的复制/剪切/粘贴入口。使用 Flutter 平台文本菜单和 AppFlowy
/// 选区几何，编辑页的格式工具仍留在既有底部卡片中，不另造一套格式工具。
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
      _hide();
    }
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final selection = widget.controller.state.selection;
      if (!widget.enabled || selection == null || selection.isCollapsed) {
        _hide();
      } else {
        _show();
      }
    });
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
        void finish() {
          _hide();
          if (!controller.state.isDisposed) {
            controller.select(af.Selection.collapsed(selection.end));
          }
        }

        return Theme(
          data: Theme.of(context),
          child: AdaptiveTextSelectionToolbar.buttonItems(
            anchors: TextSelectionToolbarAnchors(
              primaryAnchor: rects.first.topCenter,
              secondaryAnchor: rects.last.bottomCenter,
            ),
            buttonItems: [
              ContextMenuButtonItem(
                type: ContextMenuButtonType.copy,
                onPressed: () => unawaited(
                  DiaryEditorClipboard.copy(controller).then((_) => finish()),
                ),
              ),
              if (!controller.readOnly) ...[
                ContextMenuButtonItem(
                  type: ContextMenuButtonType.cut,
                  onPressed: () {
                    _hide();
                    unawaited(DiaryEditorClipboard.cut(controller));
                  },
                ),
                ContextMenuButtonItem(
                  type: ContextMenuButtonType.paste,
                  onPressed: () {
                    _hide();
                    unawaited(DiaryEditorClipboard.paste(controller));
                  },
                ),
              ],
              ContextMenuButtonItem(
                type: ContextMenuButtonType.selectAll,
                onPressed: () {
                  _hide();
                  af.selectAllCommand.handler(controller.state);
                },
              ),
            ],
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
