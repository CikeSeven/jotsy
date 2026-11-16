import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/mind_map_editing_controller.dart';
import '../sections/mind_map_export_sheet.dart';
import '../viewmodels/mind_map_labels.dart';
import '../widgets/mind_map_page_scaffold.dart';
import '../widgets/mind_map_workspace.dart';

/// 只读查看一张导图：全屏画布，可以平移、缩放、点徽标看收起的分支（只在
/// 本页生效，不写回）。[onEdit] 给出时顶栏有“编辑导图”。
class MindMapViewerPage extends StatefulWidget {
  const MindMapViewerPage({super.key, required this.document, this.onEdit});

  final MindMapDocument document;
  final VoidCallback? onEdit;

  @override
  State<MindMapViewerPage> createState() => _MindMapViewerPageState();
}

class _MindMapViewerPageState extends State<MindMapViewerPage> {
  late final MindMapEditingController _controller = MindMapEditingController(
    widget.document,
    readOnly: true,
  );
  final GlobalKey<MindMapWorkspaceState> _workspace =
      GlobalKey<MindMapWorkspaceState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onEdit = widget.onEdit;
    return MindMapPageScaffold(
      title: Text(
        mindMapTitle(l10n, widget.document.root.text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onBack: () => Navigator.of(context).maybePop(),
      actions: <Widget>[
        IconButton(
          tooltip: l10n.mindMapExport,
          onPressed: () => showMindMapExportSheet(context, widget.document),
          icon: const FaIcon(FontAwesomeIcons.fileExport, size: 16),
        ),
        IconButton(
          tooltip: l10n.mindMapFit,
          onPressed: () => _workspace.currentState?.fitToScreen(),
          icon: const FaIcon(FontAwesomeIcons.expand, size: 16),
        ),
        if (onEdit != null)
          IconButton(
            tooltip: l10n.mindMapEditMap,
            onPressed: () {
              Navigator.of(context).pop();
              onEdit();
            },
            icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 17),
          ),
      ],
      body: (BuildContext context, double topInset) => MindMapWorkspace(
        key: _workspace,
        controller: _controller,
        topInset: topInset,
        readOnly: true,
      ),
    );
  }
}

/// 打开只读查看页。
Future<void> openMindMapViewer(
  BuildContext context,
  MindMapDocument document, {
  VoidCallback? onEdit,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => MindMapViewerPage(document: document, onEdit: onEdit),
  ),
);
