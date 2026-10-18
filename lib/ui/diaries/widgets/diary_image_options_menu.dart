import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show showCupertinoModalPopup;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
// 复用上游的宽高滑条，保持与原菜单一致的调整方式；上游未导出该组件。
// ignore: implementation_imports
import 'package:flutter_quill_extensions/src/editor/image/widgets/image_resizer.dart'
    show ImageResizer;
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
  required quill.QuillController controller,
  required quill.Node node,
  required String source,
  required bool readOnly,
}) async {
  final l10n = context.l10n;
  final offset = node.documentOffset;
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
      _showResizer(
        context,
        controller,
        node: node,
        offset: offset,
        style: style,
      );
    case _ImageAction.copy:
      await DiaryImageEmbedActions.copy(
        controller,
        source: source,
        style: style,
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
      DiaryImageEmbedActions.remove(controller, offset: offset);
  }
}

/// 宽高滑条（上游 [ImageResizer]）：拖动时逐帧写回 embed 的样式。初始值取已有
/// 上限并夹到滑条范围内（导入的图片可能写着比屏幕还大的宽度，滑条会断言越界）；
/// 没有上限时取最大值，与上游一致。每次写入都只替换宽高两项，所以始终基于
/// 打开时的 [style] 计算即可，样式里的其他声明原样保留。
void _showResizer(
  BuildContext context,
  quill.QuillController controller, {
  required quill.Node node,
  required int offset,
  required String? style,
}) {
  final bounds = diaryImageEmbedBounds(node);
  showCupertinoModalPopup<void>(
    context: context,
    builder: (BuildContext modalContext) {
      final screen = MediaQuery.sizeOf(modalContext);
      double? initial(double bound, double max) =>
          bound.isFinite ? math.min(bound, max) : null;
      return ImageResizer(
        imageWidth: initial(bounds.maxWidth, screen.width),
        imageHeight: initial(bounds.maxHeight, screen.height),
        maxWidth: screen.width,
        maxHeight: screen.height,
        onImageResize: (double width, double height) {
          DiaryImageEmbedActions.resize(
            controller,
            offset: offset,
            style: style,
            width: width,
            height: height,
          );
        },
      );
    },
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
