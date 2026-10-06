import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// 播放、拖动和弹窗期间临时释放编辑焦点，手势结束后恢复正文获取焦点的能力。
/// 不清空选区；恢复 canRequestFocus 不会主动把键盘重新拉起。
class DiaryPlaybackInteractionGuard extends StatefulWidget {
  const DiaryPlaybackInteractionGuard({super.key, required this.child});
  final Widget child;

  @override
  State<DiaryPlaybackInteractionGuard> createState() =>
      _DiaryPlaybackInteractionGuardState();
}

class _DiaryPlaybackInteractionGuardState
    extends State<DiaryPlaybackInteractionGuard> {
  final _pointers = <int>{};
  FocusNode? _editorFocus;
  bool _couldRequestFocus = false;
  quill.QuillController? _editorController;
  TextSelection? _selection;

  void _onDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_editorFocus != null) return;
    final editor = context.findAncestorWidgetOfExactType<quill.QuillEditor>();
    if (editor == null) return;
    _editorFocus = editor.focusNode;
    _editorController = editor.controller;
    _selection = editor.controller.selection;
    _couldRequestFocus = editor.focusNode.canRequestFocus;
    editor.focusNode.canRequestFocus = false;
  }

  void _onEnd(PointerEvent event) {
    _pointers.remove(event.pointer);
    // Quill 的透明识别器会在子控件之后收到 tapUp，需等整帧完成再恢复焦点。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pointers.isEmpty) _restore();
    });
  }

  void _restore({bool restoreSelection = true}) {
    final node = _editorFocus;
    _editorFocus = null;
    final controller = _editorController;
    _editorController = null;
    final selection = _selection;
    _selection = null;
    if (node?.context?.mounted ?? false) {
      // 连续播放/暂停会被 Quill 当作双击选择词语。保留 tapDown 以维持其
      // 内部手势状态，再在同一帧末恢复原选区，防止播放器改变正文光标。
      if (restoreSelection &&
          controller != null &&
          selection != null &&
          controller.selection != selection) {
        controller.ignoreFocusOnTextChange = true;
        try {
          controller.updateSelection(selection, quill.ChangeSource.local);
        } finally {
          controller.ignoreFocusOnTextChange = false;
        }
      }
      node!.canRequestFocus = _couldRequestFocus;
    }
  }

  @override
  void dispose() {
    _restore(restoreSelection: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _onDown,
    onPointerUp: _onEnd,
    onPointerCancel: _onEnd,
    child: widget.child,
  );
}
