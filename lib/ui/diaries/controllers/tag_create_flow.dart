import 'dart:async';

import 'package:flutter/material.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

import '../widgets/create_tag_dialog.dart';

/// 在挑选标签的地方就地新建一个标签：弹“新建标签”，确认后写进标签表。
///
/// 发布 / 编辑页的标签子页（`DiaryMetaActions.createTag`）与多选日记的标签
/// 面板共用这一条路径。[initialName] 预填弹窗里的名称（如没有结果的检索词）。
///
/// 返回新标签的 id（同名标签已存在时为它的 id，颜色按 [AppDatabase.createTag]
/// 的口径随之更新）；取消、页面已销毁或写库失败时为 null，失败另给提示。
/// 调用方拿到 id 后自行把它设为选中，并先确认自己仍挂载。
Future<int?> runCreateTagFlow(
  BuildContext context,
  AppDatabase database, {
  String? initialName,
}) async {
  final tag = await showCreateTagDialog(context, initialName: initialName);
  if (tag == null || !context.mounted) return null;
  try {
    return await database.createTag(name: tag.name, color: tag.color);
  } catch (error) {
    debugPrint('Tag creation failed: $error');
    if (context.mounted) {
      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: context,
          snackBar: SnackBar(
            content: Text(context.l10n.publishTagCreateFailed),
          ),
        ),
      );
    }
    return null;
  }
}
