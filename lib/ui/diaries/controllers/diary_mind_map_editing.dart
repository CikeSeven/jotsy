import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/mind_map/mind_map_blocks.dart';
import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_from_blocks.dart';
import '../../../core/database/mind_map/mind_map_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../ai/controllers/ai_privacy_gate.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../mind_maps/controllers/mind_map_ai_scope.dart';
import '../../mind_maps/controllers/mind_map_ai_session.dart';
import '../../mind_maps/sections/mind_map_ai_sheet.dart';
import '../../mind_maps/pages/mind_map_editor_page.dart';
import '../../settings/providers/app_features_provider.dart';
import '../models/new_diary_draft.dart';
import 'diary_card_menu_flows.dart';
import 'diary_editor_controller.dart';
import 'diary_editor_insert.dart';
import 'diary_link_editing.dart';
import 'diary_open_flow.dart';
import 'publish_new_diary_directly.dart';

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
    aiAllowed: MindMapAiScope.maybeOf(context)?.allowed,
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

/// 把文字日记 [diary] 按标题与列表的层级转成一张新的导图日记，直接存好并
/// 打开它的编辑页（见 [saveMindMapAsDiary]；原文不动）。
Future<void> openMindMapFromDiary(
  BuildContext context,
  WidgetRef ref,
  Diary diary,
) => saveMindMapAsDiary(
  context,
  ref,
  mindMapFromDiaryBlocks(
    decodeStoredDiaryBlocks(diary.content),
    title: diary.title,
  ),
);

/// 让 AI 把文字日记 [diary] 整理成一张新的导图日记（预览页“更多”）：私密
/// 日记在用户没允许时只提示原因；面板里点“存为导图日记”后直接存好并打开
/// 它的编辑页（见 [saveMindMapAsDiary]），原文不动。
Future<void> openMindMapAiFromDiary(
  BuildContext context,
  WidgetRef ref,
  Diary diary,
) async {
  if (!await _aiAllowedFor(context, ref, diary.diaryId)) return;
  final material = await ref
      .read(appDatabaseProvider)
      .getAiDiary(diary.diaryId);
  if (material == null || !context.mounted) return;
  await showMindMapAiSheet(
    context,
    task: MindMapAiTask.fromDiary,
    diary: material,
    onOpenAsDiary: (map) {
      if (context.mounted) unawaited(saveMindMapAsDiary(context, ref, map));
    },
  );
}

/// 让 AI 总结导图日记 [diary] 里的导图 [map]（预览页“更多”，只读：可复制
/// 或另存为日记）。
Future<void> openMindMapAiSummary(
  BuildContext context,
  WidgetRef ref,
  Diary diary,
  MindMapDocument map,
) async {
  if (!await _aiAllowedFor(context, ref, diary.diaryId)) return;
  if (!context.mounted) return;
  await showMindMapAiSheet(
    context,
    task: MindMapAiTask.summarize,
    document: map,
  );
}

Future<bool> _aiAllowedFor(
  BuildContext context,
  WidgetRef ref,
  String diaryId,
) async {
  final allowed = await aiDiaryAllowed(ref, diaryId);
  if (!allowed && context.mounted) {
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(context.l10n.aiPanelPrivateBlocked)),
    );
  }
  return allowed;
}

/// 把导图 [map] 直接存成一篇新的导图日记，再打开它的编辑页（整页是导图
/// 工作区）。不经新建页与发布页：由日记生成的导图本来就是成品，用户要的是
/// 存下来接着改，而不是先看一遍再点发布。
///
/// 标题为中心主题（[mindMapDiaryTitle]），发表时间为现在，不带心情、标签与
/// 日记本；与“返回时直接发表”同一条写库链路（[publishNewDiaryDirectly]）。
/// 不触发 AI 自动回应：导图日记没有显示回应的地方。写库失败时提示“发表
/// 失败”，什么都不打开。在编辑页里删掉了它时给撤销（[offerDeletedDiaryUndo]）。
Future<void> saveMindMapAsDiary(
  BuildContext context,
  WidgetRef ref,
  MindMapDocument map,
) async {
  final features = ref.read(appFeaturesProvider);
  final document = mindMapDiaryDocument(map);
  final String diaryId;
  try {
    diaryId = await publishNewDiaryDirectly(
      database: ref.read(appDatabaseProvider),
      draft: NewDiaryDraft(
        title: mindMapDiaryTitle(map),
        contentDocJson: encodeDiaryBlocks(document),
        contentText: diaryBlocksPlainText(document),
      ),
      timeCapsulesEnabled: features.timeCapsules,
      notebooksEnabled: features.notebooks,
    );
  } catch (error) {
    debugPrint('Saving mind map as diary failed: $error');
    if (context.mounted) {
      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: context,
          snackBar: SnackBar(content: Text(context.l10n.publishFailed)),
        ),
      );
    }
    return;
  }
  if (!context.mounted) return;
  final result = await openDiaryPage(context, ref, diaryId: diaryId);
  final deletedId = result?.diaryId;
  if (deletedId == null || !context.mounted) return;
  await offerDeletedDiaryUndo(context, ref, deletedId);
}
