import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/services/diary_media_storage_service.dart';
import '../../../core/services/journal_import_block_writer.dart';
import '../../../core/services/journal_import_html.dart';
import 'diary_editor_controller.dart';
import 'diary_editor_insert.dart';
import 'diary_table_editing.dart';
import 'diary_table_selection.dart';

/// 剪贴板只在显式复制/粘贴时访问。原生树的格式快照只留在本进程内，并以
/// 系统剪贴板的文字或图片摘要核对，避免粘贴到其他应用后来复制的新内容时
/// 仍误用旧快照。图片落入既有托管媒体目录，不引用其他应用的缓存。
abstract final class DiaryEditorClipboard {
  static String? _text;
  static List<Map<String, dynamic>>? _nodes;
  static String? _imageDigest;
  static Map<String, dynamic>? _imageData;

  static Future<void> writeImage(
    Uint8List bytes,
    Map<String, dynamic> data,
  ) async {
    _imageDigest = sha256.convert(bytes).toString();
    _imageData = Map.of(data);
    _nodes = null;
    _text = null;
    await Pasteboard.writeImage(bytes);
  }

  static Future<void> copy(DiaryEditorController controller) async {
    // 上游按选择方向返回节点，但首尾裁切与落入剪贴板的文档都必须按正文顺序。
    // 尤其反向跨段选区，未经规整会把两端的偏移用到相反的段落上。
    final selection = controller.selection?.normalized;
    if (selection == null || selection.isCollapsed) return;
    // 选区从格子里开始或结束时会带上零散的格子：只留它们的段落，粘到
    // 别处不会出现没有表格的格子。
    final nodes = [
      for (final node in controller.state.getSelectedNodes(
        selection: selection,
      ))
        if (node.type == 'table/cell') ...node.children else node,
    ];
    final document = {
      'document': {
        'type': 'page',
        'children': [for (final node in nodes) node.toJson()],
      },
    };
    _text = diaryBlocksPlainText(document);
    _nodes = [for (final node in nodes) node.toJson()];
    _imageDigest = null;
    _imageData = null;
    await Clipboard.setData(ClipboardData(text: _text!));
  }

  static Future<void> cut(DiaryEditorController controller) async {
    if (controller.readOnly) return;
    final selection = controller.selection?.normalized;
    if (selection == null || selection.isCollapsed) return;
    await copy(controller);
    if (controller.state.isDisposed) return;
    if (!await deleteDiaryTableSelection(controller.state, selection)) {
      await controller.state.deleteSelection(selection);
    }
  }

  static Future<void> paste(DiaryEditorController controller) async {
    if (controller.readOnly) return;
    Uint8List? bytes;
    try {
      bytes = await Pasteboard.image;
    } on MissingPluginException {
      // Widget 测试和不提供图片剪贴板的系统仍保留文字粘贴。
    } on PlatformException {
      /* 剪贴板只有文字或平台没有图片权限。 */
    }
    if (controller.state.isDisposed) return;
    if (bytes != null && bytes.isNotEmpty) {
      await insertImageBytes(controller, bytes);
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (controller.state.isDisposed) return;
    final text = data?.text;
    if (text != null && text == _text && _nodes != null) {
      await _pasteNodes(controller, _nodes!);
      return;
    }
    String? html;
    try {
      html = await Pasteboard.html;
    } on MissingPluginException {
      // 平台未提供 HTML，使用纯文字。
    } on PlatformException {
      /* 不同系统支持的剪贴板格式不同。 */
    }
    if (controller.state.isDisposed) return;
    if (html != null && html.isNotEmpty) {
      final writer = JournalBlockWriter();
      JournalHtmlConverter(
        writer,
        resolveEmbed: (source) => {'image': source},
      ).appendHtml(html);
      final document = diaryEditorDocument(writer.build().contentJson);
      await _pasteNodes(controller, [
        for (final node in document.root.children) node.toJson(),
      ]);
    } else if (text != null && text.isNotEmpty) {
      controller.select(diaryEditorInsertionSelection(controller));
      await _pasteNodes(controller, [
        for (final line in text.replaceAll('\r\n', '\n').split('\n'))
          af.paragraphNode(text: line).toJson(),
      ]);
    }
  }

  static Future<void> _pasteNodes(
    DiaryEditorController controller,
    List<Map<String, dynamic>> data,
  ) async {
    final document = diaryEditorDocument(
      jsonEncode({
        'document': {'type': 'page', 'children': data},
      }),
    );
    var nodes = document.root.children.toList();
    final target = diaryEditorInsertionSelection(controller);
    controller.select(target);
    // 触及表格的选区先按本应用的规则删掉（上游的 deleteSelection 会把从
    // 表格外选进来的整个表格删掉）。
    if (!target.isCollapsed &&
        diarySelectionTouchesTable(controller.state, target)) {
      await deleteDiaryTableSelection(controller.state, target);
      if (controller.state.isDisposed) return;
    }
    // 粘进格子的只能是段落：各块的文字各成一段，媒体与表格结构丢掉。
    final caret = controller.selection;
    if (caret != null &&
        diaryTableCellOf(controller.document.nodeAtPath(caret.end.path)) !=
            null) {
      nodes = diaryTableCellParagraphs(nodes);
      if (nodes.isEmpty) return;
    }
    if (nodes.any((node) => node.delta == null)) {
      insertDiaryEditorNodes(
        controller: controller,
        nodes: nodes,
        replaceSelection: true,
      );
    } else if (nodes.length == 1) {
      await controller.state.pasteSingleLineNode(nodes.single);
    } else {
      await controller.state.pasteMultiLineNodes(nodes);
    }
  }

  static Future<void> insertImageBytes(
    DiaryEditorController controller,
    Uint8List bytes,
  ) async {
    final sameImage = _imageDigest == sha256.convert(bytes).toString();
    final file = await DiaryMediaStorageService.importFile(
      kind: DiaryMediaKind.image,
      fileName: 'clipboard.png',
      bytes: bytes,
    );
    if (controller.state.isDisposed) {
      await DiaryMediaStorageService.deleteManagedDiaryFile(file.path);
      return;
    }
    try {
      insertDiaryEditorNodes(
        controller: controller,
        replaceSelection: true,
        nodes: [
          af.Node(
            type: 'image',
            attributes: {
              if (sameImage && _imageData != null) ..._imageData!,
              'url': file.path,
            },
          ),
        ],
      );
    } catch (_) {
      await DiaryMediaStorageService.deleteManagedDiaryFile(file.path);
      rethrow;
    }
  }
}
