import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show Attribute, Block, RenderEditor;

import '../../../../l10n/app_localizations.dart';
import '../../controllers/diary_code_language_tracker.dart';
import '../../models/diary_code_block/diary_code_block_newline.dart';
import '../../models/diary_code_block/diary_code_language.dart';
import '../../viewmodels/diary_code_block_look.dart';
import 'diary_code_block_header_painter.dart';

// 代码块标题栏的几何与文案：从 Quill 的渲染树读出每个代码块标题栏的位置，
// 并决定上面显示的语言名与复制按钮的读屏标签。
//
// 输入：已完成本帧布局的 RenderEditor、坐标换算的目标祖先、代码块外观、
// 语言识别状态与文案。
// 输出：按文档顺序排列的 [DiaryCodeBlockHeaderGeometry]。
// 副作用：无（只读渲染树，不触发识别）。
//
// 与 Quill 的几何约定（flutter_quill 11.6.0）：每个代码块是 RenderEditor 的
// 一个子节点（container 为该 Block），子节点的位置在 parentData.offset；块
// 装饰画在子节点按块外边距（`DefaultStyles.code` 的 horizontal / vertical
// spacing，即 DiaryCodeBlockLook.blockStyle）收缩后的矩形上，Quill 固定的
// 代码块内边距（左右 4、上下 16）在装饰之内。标题栏占据装饰上方
// headerHeight 高的那段外边距：
//   Rect.fromLTRB(装饰.left, 装饰.top - headerHeight, 装饰.right, 装饰.top)。
// 换用别的 Quill 版本时须重新核对 RenderEditableTextBlock 的装饰绘制。

/// 一个代码块标题栏的位置与文案；命中测试与读屏节点都以它为准。
@immutable
class DiaryCodeBlockHeaderGeometry {
  const DiaryCodeBlockHeaderGeometry({
    required this.block,
    required this.rect,
    required this.label,
    required this.semanticsLabel,
  });

  final Block block;

  /// 标题栏矩形，换算到收集时传入的祖先的局部坐标。
  final Rect rect;

  /// 显示的语言名。
  final String label;

  /// 复制按钮的读屏标签。
  final String semanticsLabel;

  /// 复制按钮的点按区域。
  Rect get copyRect => DiaryCodeBlockHeaderPainter.copyRect(rect);

  @override
  bool operator ==(Object other) =>
      other is DiaryCodeBlockHeaderGeometry &&
      identical(other.block, block) &&
      other.rect == rect &&
      other.label == label &&
      other.semanticsLabel == semanticsLabel;

  @override
  int get hashCode =>
      Object.hash(identityHashCode(block), rect, label, semanticsLabel);
}

/// [root] 子树里的第一个 RenderEditor（深度优先）；没有时为 null。
RenderEditor? findDiaryRenderEditor(RenderObject root) {
  if (root is RenderEditor) {
    return root;
  }
  RenderEditor? found;
  root.visitChildren((RenderObject child) {
    found ??= findDiaryRenderEditor(child);
  });
  return found;
}

/// [editor] 中每个代码块的标题栏，坐标换算到 [ancestor]（须是 [editor] 的
/// 祖先）。只能在布局完成后调用（绘制、命中测试、语义阶段）。
List<DiaryCodeBlockHeaderGeometry> collectDiaryCodeBlockHeaders({
  required RenderEditor editor,
  required RenderObject ancestor,
  required DiaryCodeBlockLook look,
  required DiaryCodeLanguageTracker tracker,
  required AppLocalizations l10n,
}) {
  final horizontal = look.blockStyle.horizontalSpacing;
  final vertical = look.blockStyle.verticalSpacing;
  final transform = editor.getTransformTo(ancestor);
  final headers = <DiaryCodeBlockHeaderGeometry>[];
  for (
    var child = editor.firstChild;
    child != null;
    child = editor.childAfter(child)
  ) {
    final node = child.container;
    if (!isDiaryCodeBlock(node)) {
      continue;
    }
    final block = node as Block;
    final box = (child.parentData! as BoxParentData).offset & child.size;
    final decorationTop = box.top + vertical.top;
    final header = Rect.fromLTRB(
      box.left + horizontal.left,
      decorationTop - DiaryCodeBlockLook.headerHeight,
      box.right - horizontal.right,
      decorationTop,
    );
    final text = describeDiaryCodeBlockHeader(
      block,
      autoDetect: look.autoDetect,
      tracker: tracker,
      l10n: l10n,
    );
    headers.add(
      DiaryCodeBlockHeaderGeometry(
        block: block,
        rect: MatrixUtils.transformRect(transform, header),
        label: text.label,
        semanticsLabel: text.semanticsLabel,
      ),
    );
  }
  return headers;
}

/// 标题栏的语言名与复制按钮的读屏标签：
/// - 明确指定的语言：语言名（“C/C++”“Python”…）；
/// - 纯文本：“纯文本”；
/// - 未指定：开启自动识别且认出来了取识别结果的名称，否则“代码”。
///
/// 只读识别状态的上一次结果（[DiaryCodeLanguageTracker.lastDetected]），不
/// 触发识别：高亮在构建正文时已经识别过，标题栏与高亮用的是同一份结果。
({String label, String semanticsLabel}) describeDiaryCodeBlockHeader(
  Block block, {
  required bool autoDetect,
  required DiaryCodeLanguageTracker tracker,
  required AppLocalizations l10n,
}) {
  final choice = DiaryCodeLanguageChoice.fromAttributeValue(
    block.style.attributes[Attribute.codeBlock.key]?.value,
  );
  if (choice.isPlain) {
    final label = l10n.codeBlockLanguagePlain;
    return (label: label, semanticsLabel: l10n.codeBlockCopySemantics(label));
  }
  final id =
      choice.languageId ?? (autoDetect ? tracker.lastDetected(block) : null);
  final name = id == null ? null : diaryCodeLanguageById(id)?.name;
  if (name == null) {
    // 读屏不念“复制 代码 代码”，直接念按钮名。
    return (
      label: l10n.codeBlockLabelGeneric,
      semanticsLabel: l10n.codeBlockCopy,
    );
  }
  return (label: name, semanticsLabel: l10n.codeBlockCopySemantics(name));
}
