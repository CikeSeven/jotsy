import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/mind_map/mind_map_blocks.dart';
import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_from_blocks.dart';
import '../../../core/database/mind_map/mind_map_schema.dart';
import '../../mind_maps/pages/mind_map_editor_page.dart';
import '../models/edit_diary_create_seed.dart';
import '../pages/edit_diary_page.dart';
import 'diary_editor_controller.dart';
import 'diary_editor_insert.dart';
import 'diary_link_editing.dart';

/// 正文里嵌入导图（`mind_map` 块）的写入：插入、全屏编辑后写回、删除。
///
/// 全屏编辑期间每次改动都直接写进块（不进撤销栈，日记的自动保存照常读到
/// 最新内容）；关闭时先静默换回打开前的内容，再把最终内容作为一次普通改动
/// 写入——正文里由此只多一步撤销（撤销即回到打开前）。

/// 在光标处插入一张空导图并直接打开全屏编辑（[insertDiaryEditorNodes] 的
/// 插入口径：空段落被取代，否则插在后面）。
Future<void> insertDiaryMindMap(
  BuildContext context,
  DiaryEditorController controller,
) async {
  if (controller.readOnly || controller.isDisposed) return;
  final map = MindMapDocument.blank();
  final node = af.Node(
    type: kDiaryBlockMindMap,
    attributes: mindMapBlockData(map),
  );
  insertDiaryEditorNodes(controller: controller, nodes: <af.Node>[node]);
  if (!context.mounted) return;
  await editDiaryMindMap(context, controller, node);
}

/// 全屏编辑块 [node] 里的导图，关闭后写回。
Future<void> editDiaryMindMap(
  BuildContext context,
  DiaryEditorController controller,
  af.Node node,
) async {
  if (controller.readOnly || controller.isDisposed) return;
  final original = Map<String, Object?>.of(node.attributes);
  final page = isMindMapPageData(original);
  final before = mindMapOfBlockData(original);
  void write(MindMapDocument map, {required bool recordUndo}) {
    if (controller.isDisposed || node.parent == null) return;
    final transaction = controller.state.transaction
      ..updateNode(node, mindMapBlockData(map, page: page));
    controller.apply(
      transaction,
      recordUndo: recordUndo,
      updateSelection: false,
    );
  }

  final after = await openMindMapEditor(
    context,
    before,
    onChanged: (map) => write(map, recordUndo: false),
  );
  if (identical(after, before) || controller.isDisposed) return;
  // 先静默回到打开前，再把最终内容写成一步可撤销的改动。
  final restore = controller.state.transaction
    ..updateNode(node, <String, Object?>{
      kMindMapBlockMapKey: original[kMindMapBlockMapKey],
    });
  controller.apply(restore, recordUndo: false, updateSelection: false);
  write(after, recordUndo: true);
}

/// 删除块 [node]：与日记链接卡片同一口径（光标落到前一个文字块末尾或后一个
/// 文字块开头）。
void deleteDiaryMindMap(DiaryEditorController controller, af.Node node) =>
    deleteDiaryLinkCard(controller, node);

/// 把文字日记 [diary] 按标题与列表的层级转成一张新的导图日记，打开新建页
/// （原文不动；什么都没改就离开时不留草稿，同“另存为日记”）。
Future<void> openMindMapFromDiary(BuildContext context, Diary diary) async {
  final map = mindMapFromDiaryBlocks(
    decodeStoredDiaryBlocks(diary.content),
    title: diary.title,
  );
  await Navigator.of(context).push<Object?>(
    MaterialPageRoute<Object?>(
      builder: (_) => EditDiaryPage(
        entryMode: EditDiaryEntryMode.create,
        createSeed: EditDiaryCreateSeed(
          title: map.root.text,
          contentDocJson: encodeDiaryBlocks(mindMapDiaryDocument(map)),
        ),
      ),
    ),
  );
}
