import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../controllers/diary_link_editing.dart';
import '../diary_link/diary_link_card.dart';
import '../diary_playback_interaction_guard.dart';
import 'diary_embed_selectable.dart';

/// 日记链接卡片块（`link_card`）：外观见 [DiaryLinkCard]，块级选区同媒体
/// （[DiaryEmbedSelectable]）。
///
/// - 只读正文：点按卡片打开目标（[onOpen]）；
/// - 编辑态：点按在卡片下方弹出菜单，桌面右键 / 长按在指针处弹出：打开
///   （只有日记——打开日记本会回到首页，关掉正在写的这一篇）、转为行内
///   链接、删除。点按不打开，免得想选中、拖动卡片时跳走。
class DiaryLinkCardBlockBuilder extends af.BlockComponentBuilder {
  DiaryLinkCardBlockBuilder({required this.controller, required this.onOpen});

  final DiaryEditorController controller;
  final ValueChanged<DiaryLinkTarget> onOpen;

  @override
  af.BlockComponentValidate get validate =>
      (_) => true;

  @override
  af.BlockComponentWidget build(af.BlockComponentContext context) =>
      _DiaryLinkCardBlock(
        key: context.node.key,
        node: context.node,
        controller: controller,
        onOpen: onOpen,
      );
}

class _DiaryLinkCardBlock extends af.BlockComponentStatefulWidget {
  const _DiaryLinkCardBlock({
    super.key,
    required super.node,
    required this.controller,
    required this.onOpen,
  }) : super(configuration: const af.BlockComponentConfiguration());

  final DiaryEditorController controller;
  final ValueChanged<DiaryLinkTarget> onOpen;

  @override
  State<_DiaryLinkCardBlock> createState() => _DiaryLinkCardBlockState();
}

class _DiaryLinkCardBlockState extends State<_DiaryLinkCardBlock>
    with af.SelectableMixin, DiaryEmbedSelectable {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    final target = diaryLinkCardTarget(node.attributes);
    final snapshot = diaryLinkCardTitle(node.attributes);
    final Widget card;
    if (controller.readOnly) {
      card = DiaryLinkCard(
        target: target,
        snapshot: snapshot,
        onTap: target == null ? null : () => widget.onOpen(target),
      );
    } else {
      card = ExpressiveMenuAnchor(
        menuChildren: [
          if (target?.kind == DiaryLinkKind.diary)
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(
                FontAwesomeIcons.arrowUpRightFromSquare,
              ),
              onPressed: () => widget.onOpen(target!),
              child: Text(l10n.diaryLinkOpen),
            ),
          if (target != null)
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.link),
              onPressed: () => convertDiaryLinkCardToInline(
                controller,
                node,
                fallback: target.kind == DiaryLinkKind.notebook
                    ? l10n.diaryLinkGroupNotebooks
                    : l10n.diaryLinkGroupDiaries,
              ),
              child: Text(l10n.diaryLinkCardToInline),
            ),
          ExpressiveMenuItem(
            leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
            destructive: true,
            onPressed: () => deleteDiaryLinkCard(controller, node),
            child: Text(l10n.commonDelete),
          ),
        ],
        builder: (context, menu, _) => Semantics(
          hint: l10n.diaryLinkCardMenu,
          child: DiaryLinkCard(
            target: target,
            snapshot: snapshot,
            // 编辑态卡片不论目标是否还在都可点：菜单里还有删除。
            onTap: menu.open,
            tapUnavailable: true,
            onLongPress: (details) => menu.openAt(details.globalPosition),
            onSecondaryTapUp: (details) => menu.openAt(details.globalPosition),
          ),
        ),
      );
    }
    return buildEmbedSelection(
      controller.state,
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DiaryPlaybackInteractionGuard(child: card),
      ),
    );
  }
}
