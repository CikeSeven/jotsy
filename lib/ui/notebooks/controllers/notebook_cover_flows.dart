import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../pages/notebook_cover_crop_page.dart';
import '../sections/notebook_cover_photo_sheet.dart';
import 'notebook_editor_controller.dart';

/// 编辑页封面分组的两个流程（页面只负责按钮）：
///
/// - [pickNotebookCoverFromDiaries]：只对已保存的日记本。面板挑出一张日记
///   图片后，经 [NotebookEditorController.setCoverFromFile] 拷贝进封面私有
///   目录再设为封面（不引用日记原图，日记删掉后封面仍在）；拷贝失败提示，
///   当前封面不变。
/// - [adjustNotebookCoverCrop]：打开取景页，完成时把新取景写回表单（参与
///   “有改动”比较，随保存写入）；返回则不变。
///
/// 两个流程都可能在 await 期间页面关闭：之后只在 context 仍挂载时提示，
/// 表单控制器已释放时它自己的 setter 不再通知。

/// 从本子的日记里选一张图作封面。
Future<void> pickNotebookCoverFromDiaries(
  BuildContext context,
  NotebookEditorController editor,
) async {
  final notebookId = editor.notebookId;
  if (notebookId == null || editor.importingCover) return;
  final path = await showNotebookCoverPhotoSheet(
    context,
    notebookId: notebookId,
  );
  if (path == null || !context.mounted) return;
  final message = context.l10n.publishCoverImportFailed;
  final result = await editor.setCoverFromFile(path);
  if (result == NotebookCoverPickResult.failed && context.mounted) {
    showStyleEditorMessage(context, message);
  }
}

/// 调整封面图的取景。
Future<void> adjustNotebookCoverCrop(
  BuildContext context,
  NotebookEditorController editor,
) async {
  final coverPath = editor.coverPath;
  if (coverPath == null) return;
  final style = await Navigator.of(context).push(
    NotebookCoverCropPage.route(coverPath: coverPath, style: editor.coverStyle),
  );
  // 取景页盖住了编辑页，期间封面不会被换；仍核对一次，换过就不采用旧图的取景。
  if (style == null || editor.coverPath != coverPath) return;
  editor.coverStyle = style;
}
