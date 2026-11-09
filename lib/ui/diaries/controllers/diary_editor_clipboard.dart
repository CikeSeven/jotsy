import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/services/diary_media_storage_service.dart';
import '../../../core/services/journal_import_block_writer.dart';
import '../../../core/services/journal_import_html.dart';
import 'diary_editor_controller.dart';
import 'diary_editor_insert.dart';
import 'diary_embed_editing.dart';
import 'diary_markdown_paste.dart';
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
    final selection = controller.selection?.normalized;
    if (selection == null || selection.isCollapsed) return;
    final nodes = _selectedNodes(controller, selection);
    _text = _plainTextOf(nodes);
    _nodes = [for (final node in nodes) node.toJson()];
    _imageDigest = null;
    _imageData = null;
    await Clipboard.setData(ClipboardData(text: _text!));
  }

  /// 段落选择模式的复制：[nodes]（各自连同子树）整块写进剪贴板，与 [copy]
  /// 同一份格式快照与纯文本口径，粘回正文时保留格式与嵌套。
  static Future<void> copyBlocks(Iterable<af.Node> nodes) async {
    final blocks = nodes.toList();
    if (blocks.isEmpty) return;
    _text = _plainTextOf(blocks);
    _nodes = [for (final node in blocks) node.toJson()];
    _imageDigest = null;
    _imageData = null;
    await Clipboard.setData(ClipboardData(text: _text!));
  }

  /// 选中内容的纯文本，与 [copy] 写进系统剪贴板的文字同一口径（选区菜单的
  /// 分享、其他应用的文字处理也用它）；没有选区或只是光标时为 null。
  static String? selectedPlainText(DiaryEditorController controller) {
    final selection = controller.selection?.normalized;
    if (selection == null || selection.isCollapsed) return null;
    return _plainTextOf(_selectedNodes(controller, selection));
  }

  /// [selection]（已按正文顺序规整）覆盖到的块。
  ///
  /// 上游按选择方向返回节点，但首尾裁切与落入剪贴板的文档都必须按正文顺序。
  /// 尤其反向跨段选区，未经规整会把两端的偏移用到相反的段落上。选区从格子
  /// 里开始或结束时会带上零散的格子：只留它们的段落，粘到别处不会出现没有
  /// 表格的格子。
  static List<af.Node> _selectedNodes(
    DiaryEditorController controller,
    af.Selection selection,
  ) => [
    for (final node in controller.state.getSelectedNodes(selection: selection))
      if (node.type == 'table/cell') ...node.children else node,
  ];

  static String _plainTextOf(List<af.Node> nodes) => diaryBlocksPlainText({
    'document': {
      'type': 'page',
      'children': [for (final node in nodes) node.toJson()],
    },
  });

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

  /// 粘贴的优先级：图片 → 本应用复制的格式快照 → 剪贴板的文字与 HTML
  /// （Markdown、HTML 与纯文字之间怎么取舍见 [pasteText]）。
  ///
  /// [plainText] 为 true（桌面 Ctrl / ⌘ + Shift + V）时跳过前面所有转换，
  /// 只按每行一段粘贴原文。光标在代码块或表格格子里时同样不转换 Markdown：
  /// 代码要原样保留，格子只收段落。
  static Future<void> paste(
    DiaryEditorController controller, {
    bool plainText = false,
  }) async {
    if (controller.readOnly) return;
    if (plainText) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (controller.state.isDisposed) return;
      final text = data?.text;
      if (text != null && text.isNotEmpty) await _pastePlain(controller, text);
      return;
    }
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
    await pasteText(controller, text: text, html: html);
  }

  /// 剪贴板里的文字与 HTML 怎么粘（[paste] 读完剪贴板后的最后一步）：
  /// 1. 纯文字看起来是 Markdown（[looksLikeDiaryMarkdown]）、光标不在代码块
  ///    或表格格子里，且没有 HTML 或 HTML 只是包着原文（[htmlOnlyWrapsText]）
  ///    → 按 Markdown 转换。以前 HTML 一律优先：Android / Windows 上附带
  ///    HTML 的来源（代码编辑器、笔记与聊天应用）粘进来，Markdown 原文就原样
  ///    落成纯文本；
  /// 2. 否则有 HTML → [pasteHtml]（网页、文档里渲染好的格式）；
  /// 3. 否则每行一段的纯文字。
  ///
  /// pasteboard 只在 Android / Windows 提供 HTML，测试经这里模拟各平台的
  /// 剪贴板内容。
  static Future<void> pasteText(
    DiaryEditorController controller, {
    String? text,
    String? html,
  }) async {
    if (controller.readOnly) return;
    final hasHtml = html != null && html.isNotEmpty;
    if (text != null && text.isNotEmpty) {
      final nodes = _markdownNodes(controller, text);
      if (nodes != null && (!hasHtml || htmlOnlyWrapsText(html))) {
        await _pasteNodes(controller, nodes);
        return;
      }
      if (!hasHtml) {
        await _pastePlain(controller, text);
        return;
      }
    }
    if (hasHtml) await pasteHtml(controller, html);
  }

  /// 输入法一次上屏的多行文字（输入法剪贴板面板里的粘贴，见
  /// `DiaryMultilineInputInterceptor`）与菜单粘贴同样落成块：看起来是
  /// Markdown 时按 Markdown 转换，否则每行一段（与 [_pastePlain] 同一路径，
  /// 表格格子里成为格内段落）。返回 false 时交给上游按原文插入：
  /// - 光标在代码块里：多行原样留在块内；
  /// - 不像 Markdown、换行只在末尾（如 `好的\n`）：分不清是粘贴还是输入法
  ///   把确认的字和回车一起上屏。按粘贴切段时在待办 / 列表里回车得到的是
  ///   正文段而不是下一项，iOS 上游还会去掉末尾换行另走回车，切段会多出一个
  ///   空段，所以照旧交给上游。
  static Future<bool> pasteInputText(
    DiaryEditorController controller,
    String text,
  ) async {
    if (controller.readOnly) return false;
    final nodes = _markdownNodes(controller, text);
    if (nodes != null) {
      await _pasteNodes(controller, nodes);
      return true;
    }
    final normalized = _normalizedLineBreaks(text);
    // 第一个换行就在末尾 = 没有换行或只有末尾一个换行。
    final firstBreak = normalized.indexOf('\n');
    if (firstBreak < 0 ||
        firstBreak == normalized.length - 1 ||
        _caretInside(controller, const {kDiaryBlockCode})) {
      return false;
    }
    await _pastePlain(controller, normalized);
    return true;
  }

  /// [text] 按 Markdown 转换后的块；不该转换（不像 Markdown、光标在代码块
  /// 或格子里）或转换后没有内容时为 null。
  static List<Map<String, dynamic>>? _markdownNodes(
    DiaryEditorController controller,
    String text,
  ) {
    if (_caretInRawTextBlock(controller) || !looksLikeDiaryMarkdown(text)) {
      return null;
    }
    final nodes = diaryMarkdownPasteNodes(text);
    return nodes.isEmpty ? null : nodes;
  }

  /// 把剪贴板里的 HTML 转为块粘贴（与导入共用 [JournalHtmlConverter]）。
  static Future<void> pasteHtml(
    DiaryEditorController controller,
    String html,
  ) async {
    if (controller.readOnly) return;
    final writer = JournalBlockWriter();
    JournalHtmlConverter(
      writer,
      resolveEmbed: (source) => {'image': source},
    ).appendHtml(html);
    final document = diaryEditorDocument(writer.build().contentJson);
    await _pasteNodes(controller, [
      for (final node in document.root.children) node.toJson(),
    ]);
  }

  /// 以纯文本 [text] 替换当前选区（其他应用的文字处理回写结果时用）：与
  /// 桌面“粘贴原文”同一条路径——每行一段、不转换 Markdown，代码块与表格
  /// 格子里的行为也与粘贴原文一致。
  ///
  /// 一步撤销：删除选区与插入文字是两个事务（触及表格时先按本应用的规则删，
  /// 否则由上游 `deleteSelectionIfNeeded` 删），但都是用户编辑、中间只隔
  /// 微任务（不等计时器或平台通道）接连提交，落在上游撤销栈同一条尚未封存的
  /// 记录里（上游在最后一次用户编辑 50ms 后才封存），与粘贴一样撤销一次即
  /// 恢复原文。
  static Future<void> replaceSelectionWithPlainText(
    DiaryEditorController controller,
    String text,
  ) async {
    if (controller.readOnly || controller.state.isDisposed) return;
    await _pastePlain(controller, text);
  }

  static Future<void> _pastePlain(
    DiaryEditorController controller,
    String text,
  ) async {
    controller.select(diaryEditorInsertionSelection(controller));
    await _pasteNodes(controller, [
      for (final line in _normalizedLineBreaks(text).split('\n'))
        af.paragraphNode(text: line).toJson(),
    ]);
  }

  /// Windows 的 `\r\n` 与旧式 `\r` 都按一个换行算，不留在段落里。
  static String _normalizedLineBreaks(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  /// 光标所在的块是代码块，或在表格格子里：这两处粘贴原文，不转换 Markdown。
  static bool _caretInRawTextBlock(DiaryEditorController controller) =>
      _caretInside(controller, const {kDiaryBlockCode, kDiaryBlockTableCell});

  /// 插入点所在的块或它的某一层父块是 [types] 之一。
  static bool _caretInside(
    DiaryEditorController controller,
    Set<String> types,
  ) {
    final selection = diaryEditorInsertionSelection(controller);
    for (
      af.Node? node = controller.document.nodeAtPath(selection.start.path);
      node != null;
      node = node.parent
    ) {
      if (types.contains(node.type)) return true;
    }
    return false;
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
    // 有媒体，或插入点停在嵌入块上（块里没有字可以接，上游的整段粘贴会
    // 落空）：整组插在块旁，见 insertDiaryEditorNodes。
    if (nodes.any((node) => node.delta == null) ||
        diaryEmbedAtCaret(controller.state) != null) {
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
