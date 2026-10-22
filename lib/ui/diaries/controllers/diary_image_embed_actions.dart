import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'diary_editor_controller.dart';
import 'diary_editor_clipboard.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';
import 'package:node_diary/ui/widgets/image_viewer_export_controller.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_policy.dart';

/// 正文图片菜单（`showDiaryImageOptions`）的动作：调整大小、删除、复制、保存。
///
/// 输入：正文控制器与图片 embed 在文档中的位置（点按时取 `node.documentOffset`，
/// 不依赖光标停在图片上）。副作用：改写正文（大小、删除）、写系统剪贴板、
/// 把原图存进相册。界面（菜单、滑条、提示）由调用方负责。
abstract final class DiaryImageEmbedActions {
  /// 写入缩放菜单的宽高（只作显示上限）。拖动滑条时逐帧调用，所以跳过
  /// 键盘请求，避免每帧把键盘拉起来。
  static void resize(
    DiaryEditorController controller, {
    required af.Node node,
    required String? style,
    required double width,
    required double height,
  }) {
    if (node.parent == null || controller.readOnly) return;
    controller.apply(
      controller.state.transaction
        ..updateNode(node, {
          'style': diaryImageStyleWithSize(style, width: width, height: height),
        })
        ..afterSelection = controller.selection,
      updateSelection: false,
    );
  }

  /// 从正文移除图片。文件不在这里删：撤销或放弃修改后原日记还要用它，未被
  /// 引用的文件由 DiaryMediaCleanupService 过了宽限期再回收。
  static void remove(
    DiaryEditorController controller, {
    required af.Node node,
  }) {
    if (node.parent == null || controller.readOnly) return;
    final transaction = controller.state.transaction;
    final af.Position position;
    if (node.parent == controller.document.root &&
        controller.document.root.children.length == 1) {
      transaction.insertNode(node.path, af.paragraphNode());
      position = af.Position(path: node.path);
    } else if (node.next != null) {
      position = af.Position(path: node.path);
    } else {
      final previous = node.previous ?? node.parent!;
      position = af.Position(
        path: previous.path,
        offset: previous.delta?.length ?? 0,
      );
    }
    transaction
      ..deleteNode(node)
      ..afterSelection = af.Selection.collapsed(position);
    controller.apply(transaction);
  }

  /// 复制图片：编辑器内粘贴时按来源与样式原样插回（`copiedImageUrl`），
  /// 系统剪贴板同时放一份 PNG 供其他应用粘贴。
  ///
  /// 剪贴板图片按比例缩小解码（长边不超过安全上限），超长截图不会被压扁；
  /// 读不出来时只保留编辑器内的复制。
  static Future<void> copy(
    DiaryEditorController controller, {
    required String source,
    required Map<String, dynamic> data,
  }) async {
    final bytes = await _pngBytes(
      boundedImageProvider(resolveDiaryImageProvider(source)),
    );
    if (bytes != null) {
      await DiaryEditorClipboard.writeImage(bytes, data);
    }
  }

  /// 把原图存进相册，返回给用户的提示（忙碌中被忽略时为 null）。与看图页的
  /// “保存到相册”同一条链路，原文件直接写入，不重新编码。
  static Future<String?> saveToGallery(
    String source,
    AppLocalizations l10n,
  ) async {
    final export = ImageViewerExportController();
    try {
      return await export.saveToGallery(source, l10n);
    } finally {
      export.dispose();
    }
  }

  static Future<Uint8List?> _pngBytes(ImageProvider provider) {
    final completer = Completer<Uint8List?>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        stream.removeListener(listener);
        final image = info.image;
        image
            .toByteData(format: ui.ImageByteFormat.png)
            .then(
              (data) => completer.complete(data?.buffer.asUint8List()),
              onError: (Object _) => completer.complete(null),
            )
            .whenComplete(info.dispose);
      },
      onError: (Object _, StackTrace? _) {
        stream.removeListener(listener);
        completer.complete(null);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}
