import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/mind_map/mind_map_blocks.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../mind_maps/pages/mind_map_viewer_page.dart';
import '../../../mind_maps/widgets/mind_map_cards.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../controllers/diary_mind_map_editing.dart';
import '../diary_playback_interaction_guard.dart';
import 'diary_embed_selectable.dart';

/// 思维导图块（`mind_map`）：块级选区同媒体（[DiaryEmbedSelectable]）。
///
/// - 整篇导图日记（`mode: page`）在只读正文（预览页、发布页预览）里画成
///   [MindMapStage]，点按全屏查看；编辑页不经这里（导图日记的编辑页直接是
///   画布，见 `edit_diary_mind_map_flow.dart`）；
/// - 嵌入的导图画成 [MindMapEmbedCard]：只读时点按全屏查看；编辑态点按打开
///   全屏编辑（写回见 `diary_mind_map_editing.dart`），长按 / 右键弹出菜单
///   （编辑、全屏查看、删除）。
class DiaryMindMapBlockBuilder extends af.BlockComponentBuilder {
  DiaryMindMapBlockBuilder({required this.controller});

  final DiaryEditorController controller;

  @override
  af.BlockComponentValidate get validate =>
      (_) => true;

  @override
  af.BlockComponentWidget build(af.BlockComponentContext context) =>
      _DiaryMindMapBlock(
        key: context.node.key,
        node: context.node,
        controller: controller,
      );
}

class _DiaryMindMapBlock extends af.BlockComponentStatefulWidget {
  const _DiaryMindMapBlock({
    super.key,
    required super.node,
    required this.controller,
  }) : super(configuration: const af.BlockComponentConfiguration());

  final DiaryEditorController controller;

  @override
  State<_DiaryMindMapBlock> createState() => _DiaryMindMapBlockState();
}

class _DiaryMindMapBlockState extends State<_DiaryMindMapBlock>
    with af.SelectableMixin, DiaryEmbedSelectable {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    final data = node.attributes;
    final map = mindMapOfBlockData(data);
    void view() => openMindMapViewer(
      context,
      map,
      onEdit: controller.readOnly
          ? null
          : () => editDiaryMindMap(context, controller, node),
    );
    final Widget content;
    if (isMindMapPageData(data)) {
      content = MindMapStage(document: map, onOpen: view);
    } else if (controller.readOnly) {
      content = MindMapEmbedCard(document: map, onTap: view);
    } else {
      content = ExpressiveMenuAnchor(
        menuChildren: <Widget>[
          ExpressiveMenuItem(
            leadingIcon: const FaIcon(FontAwesomeIcons.penToSquare),
            onPressed: () => editDiaryMindMap(context, controller, node),
            child: Text(l10n.mindMapEditMap),
          ),
          ExpressiveMenuItem(
            leadingIcon: const FaIcon(FontAwesomeIcons.expand),
            onPressed: view,
            child: Text(l10n.mindMapViewFull),
          ),
          ExpressiveMenuItem(
            leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
            destructive: true,
            onPressed: () => deleteDiaryMindMap(controller, node),
            child: Text(l10n.commonDelete),
          ),
        ],
        builder: (context, menu, _) => MindMapEmbedCard(
          document: map,
          editable: true,
          onTap: () => editDiaryMindMap(context, controller, node),
          onLongPress: (details) => menu.openAt(details.globalPosition),
          onSecondaryTapUp: (details) => menu.openAt(details.globalPosition),
        ),
      );
    }
    return buildEmbedSelection(
      controller.state,
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DiaryEmbedContent(
          child: DiaryPlaybackInteractionGuard(child: content),
        ),
      ),
    );
  }
}
