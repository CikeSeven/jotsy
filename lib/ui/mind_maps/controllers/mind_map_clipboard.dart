import 'package:flutter/services.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_ops.dart';
import '../../../core/database/mind_map/mind_map_text.dart';
import 'mind_map_editing_controller.dart';

/// 导图的复制、剪切与粘贴。
///
/// 复制时整棵子树（含样式、贴纸、备注……）留在本进程里，同时把大纲文本写进
/// 系统剪贴板（贴到别的应用里是缩进列表）。粘贴时系统剪贴板里还是那段
/// 文本，就贴回完整的子树；换成了别的文字，则按缩进解析成主题（每个最浅
/// 的行一棵子树）。贴在选中主题之下（没选中时贴在中心主题下）。
abstract final class MindMapClipboard {
  static MindMapNode? _node;
  static String? _text;

  /// 复制 [id] 的子树。
  static Future<void> copy(MindMapDocument document, String id) async {
    final node = document.index[id];
    if (node == null) return;
    _node = node;
    _text = mindMapSubtreeOutline(node);
    await Clipboard.setData(ClipboardData(text: _text!));
  }

  /// 剪切选中的主题（根不能剪切）。
  static Future<void> cut(MindMapEditingController controller) async {
    final id = controller.selectedId;
    if (id == null || id == controller.document.root.id) return;
    await copy(controller.document, id);
    controller.deleteSelected();
  }

  /// 粘贴到选中的主题下；什么都没贴上时返回 false。
  static Future<bool> paste(MindMapEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    final nodes = text == _text && _node != null
        ? <MindMapNode>[_node!]
        : mindMapNodesFromOutline(text);
    if (nodes.isEmpty) return false;
    final parent = controller.selectedId ?? controller.document.root.id;
    var document = controller.document;
    String? first;
    for (final node in nodes) {
      final (next, id) = MindMapOps.insertSubtree(document, parent, node);
      if (id == null) break;
      document = next;
      first ??= id;
    }
    if (first == null) return false;
    controller.commit(document, select: first);
    return true;
  }
}
