import 'package:flutter/material.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/services/app_platform.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/desktop_page_arrows.dart';
import '../controllers/mind_map_editing_controller.dart';
import '../viewmodels/mind_map_labels.dart';
import '../widgets/mind_map_page_scaffold.dart';
import '../widgets/mind_map_workspace.dart';

/// 全屏编辑普通日记正文里嵌入的一张导图。
///
/// 每次改动经 [onChanged] 写回正文里的导图块（不进正文的撤销栈，日记的
/// 自动保存照常），关闭时返回最终的文档，由调用方把“打开前 → 关闭时”
/// 记成正文里的一步撤销（见 `diary_mind_map_editing.dart`）。本页在日记
/// 编辑页之上，编辑会话的阻塞登记由编辑页持有。
class MindMapEditorPage extends StatefulWidget {
  const MindMapEditorPage({
    super.key,
    required this.document,
    required this.onChanged,
  });

  final MindMapDocument document;
  final ValueChanged<MindMapDocument> onChanged;

  @override
  State<MindMapEditorPage> createState() => _MindMapEditorPageState();
}

class _MindMapEditorPageState extends State<MindMapEditorPage> {
  late final MindMapEditingController _controller = MindMapEditingController(
    widget.document,
  )..onChanged = widget.onChanged;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    _controller.stopEditing();
    Navigator.of(context).pop(_controller.document);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final page = PopScope<MindMapDocument>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: MindMapPageScaffold(
        controller: _controller,
        title: ListenableBuilder(
          listenable: _controller,
          builder: (BuildContext context, Widget? _) => Text(
            mindMapTitle(l10n, _controller.document.root.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        onBack: _close,
        body: (BuildContext context, double topInset) =>
            MindMapWorkspace(controller: _controller, topInset: topInset),
      ),
    );
    return AppPlatform.isDesktop
        ? DesktopPageKeys(onEscape: _close, child: page)
        : page;
  }
}

/// 打开嵌入导图的编辑页，返回关闭时的文档（没改动时与 [document] 相同）。
Future<MindMapDocument> openMindMapEditor(
  BuildContext context,
  MindMapDocument document, {
  required ValueChanged<MindMapDocument> onChanged,
}) async {
  final result = await Navigator.of(context).push<MindMapDocument>(
    MaterialPageRoute<MindMapDocument>(
      builder: (_) =>
          MindMapEditorPage(document: document, onChanged: onChanged),
    ),
  );
  return result ?? document;
}
