import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as af;
import '../controllers/diary_editor_controller.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_image_embed_actions.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/image_viewer_page.dart';

/// 点按正文图片弹出的菜单：查看、调整大小、复制、保存到相册、删除。
///
/// 取代上游 `ImageOptionsMenu`：上游的“缩放”打开它自带的 PhotoView 页面，
/// 长图在那里只是一条细线，也绕开了看图页的统一入口；这里的“查看”经
/// [openImageViewer] 打开（长图按屏宽竖向滚动）。调整大小沿用上游的宽高滑条，
/// 复制沿用上游的编辑器内粘贴约定，保存与看图页同一条链路，提示经
/// [HomeHintVisibilityScope.showTrackedSnackBar]。
///
/// [readOnly]（发布页预览等只读正文）时只有查看、复制、保存。图片位置在
/// 点按时从 [node] 取得，菜单期间正文不会被改动。
Future<void> showDiaryImageOptions(
  BuildContext context, {
  required DiaryEditorController controller,
  required af.Node node,
  required String source,
  required bool readOnly,
}) async {
  final l10n = context.l10n;
  final style = diaryImageStyleOf(node);
  final action = await showDialog<_ImageAction>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _DiaryImageOptionsDialog(readOnly: readOnly),
  );
  if (action == null || !context.mounted) {
    return;
  }
  switch (action) {
    case _ImageAction.view:
      unawaited(
        openImageViewer(
          context,
          items: <ImageViewerItem>[ImageViewerItem(source: source)],
          initialIndex: 0,
        ),
      );
    case _ImageAction.resize:
      _showResizer(context, controller, node: node, style: style);
    case _ImageAction.copy:
      await DiaryImageEmbedActions.copy(
        controller,
        source: source,
        data: node.attributes,
      );
    case _ImageAction.save:
      final hint = await DiaryImageEmbedActions.saveToGallery(source, l10n);
      if (hint != null && context.mounted) {
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: context,
          snackBar: SnackBar(
            content: Text(hint),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    case _ImageAction.delete:
      DiaryImageEmbedActions.remove(controller, node: node);
  }
}

/// 缩放先编辑面板草稿，确认后一次事务提交，保留其他 style 声明。
void _showResizer(
  BuildContext context,
  DiaryEditorController controller, {
  required af.Node node,
  required String? style,
}) {
  final bounds = diaryImageEmbedBounds(node);
  final screen = MediaQuery.sizeOf(context);
  var width = bounds.maxWidth.isFinite
      ? math.min(bounds.maxWidth, screen.width)
      : screen.width;
  var height = bounds.maxHeight.isFinite
      ? math.min(bounds.maxHeight, screen.height)
      : screen.height;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.diaryImageMenuResize,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(context.l10n.diaryEditorImageWidth),
              Slider(
                value: width.clamp(24, screen.width),
                min: 24,
                max: screen.width,
                label: '${width.round()}',
                onChanged: (value) => setState(() => width = value),
              ),
              Text(context.l10n.diaryEditorImageHeight),
              Slider(
                value: height.clamp(24, screen.height),
                min: 24,
                max: screen.height,
                label: '${height.round()}',
                onChanged: (value) => setState(() => height = value),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    DiaryImageEmbedActions.resize(
                      controller,
                      node: node,
                      style: style,
                      width: width,
                      height: height,
                    );
                    Navigator.pop(context);
                  },
                  child: Text(context.l10n.commonConfirm),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

enum _ImageAction { view, resize, copy, save, delete }

class _DiaryImageOptionsDialog extends StatelessWidget {
  const _DiaryImageOptionsDialog({required this.readOnly});

  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    Widget item(
      _ImageAction action,
      FaIconData icon,
      String label, {
      Color? color,
    }) {
      return ListTile(
        leading: SizedBox(
          width: 24,
          child: Center(child: FaIcon(icon, size: 18, color: color)),
        ),
        title: Text(
          label,
          style: color == null ? null : TextStyle(color: color),
        ),
        onTap: () => Navigator.of(context).pop(action),
      );
    }

    return SimpleDialog(
      title: Text(l10n.diaryImageMenuTitle),
      children: <Widget>[
        item(
          _ImageAction.view,
          FontAwesomeIcons.expand,
          l10n.diaryImageMenuView,
        ),
        if (!readOnly)
          item(
            _ImageAction.resize,
            FontAwesomeIcons.upRightAndDownLeftFromCenter,
            l10n.diaryImageMenuResize,
          ),
        item(_ImageAction.copy, FontAwesomeIcons.copy, l10n.diaryImageMenuCopy),
        item(
          _ImageAction.save,
          FontAwesomeIcons.download,
          l10n.imageViewerSaveToGallery,
        ),
        if (!readOnly)
          item(
            _ImageAction.delete,
            FontAwesomeIcons.trashCan,
            l10n.commonDelete,
            color: colorScheme.error,
          ),
      ],
    );
  }
}
