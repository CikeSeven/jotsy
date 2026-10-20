import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show Attribute, AttributeScope, Block, ChangeSource, Line, QuillController;
import 'package:flutter_quill/quill_delta.dart';

import '../models/diary_code_block/diary_code_block_newline.dart';

// 代码块的编辑行为：回车（留在块内自动缩进 / 连续空行退出）与代码块操作
// （设语言、转为正文、跳出代码块、复制、把当前行设为代码块）。
//
// 输入：正文的 QuillController；输出：直接改写文档与选区；副作用：复制会写
// 系统剪贴板。焦点由调用方负责，这里不打开任何路由或面板。
//
// 为什么挂在 `QuillController.onReplaceText` 而不是加 quill Rule：
// `replaceText` 在规则改写之后按 `getPositionDelta(用户 Delta, 实际 Delta)`
// 推算光标，规则的改写最多让光标往回挪 1；退出代码块要往回挪 2 个以上（收掉
// 块尾空白行），自动缩进要往后挪缩进的长度，规则都做不到。`onReplaceText`
// 在任何规则之前被调用，返回 false 即放弃默认链路，于是这里自己把整份改写
// 一次组合进文档，再把光标放到计划的位置。
//
// 落地顺序：`document.compose`（不经规则，一次组合 = 撤销栈里一条记录，与
// 默认回车一样会和 400ms 内的输入合并为一步）→ `updateSelection`（唯一一次
// notifyListeners）。编辑器监听到通知后经 `updateRemoteValueIfNeeded` 把改写
// 后的文字与光标推回输入法，输入法里“默认插入的换行”随之被纠正。
// 不用 `QuillController.compose`：它会忽略传入的选区，只按 Delta 变换原选区。
//
// 回车的语义（何时退出、缩进取多少）见 diary_code_block_newline.dart。

final Expando<bool> _attachedControllers = Expando<bool>(
  'diaryCodeBlockEditing',
);

/// 给 [controller] 挂上代码块的回车处理；重复调用只挂一次。
///
/// 已有的 `onReplaceText` 会被串在前面先调用：它返回 false（拦下这次替换）
/// 时直接返回 false，不再处理。只读时不接管。
void attachDiaryCodeBlockEditing(QuillController controller) {
  if (_attachedControllers[controller] ?? false) {
    return;
  }
  _attachedControllers[controller] = true;
  final previous = controller.onReplaceText;
  controller.onReplaceText = (index, len, data) {
    if (previous != null && !previous(index, len, data)) {
      return false;
    }
    if (controller.readOnly) {
      return true;
    }
    final plan = planDiaryCodeBlockNewline(
      controller.document,
      index,
      len,
      data,
    );
    if (plan == null) {
      return true;
    }
    controller.document.compose(plan.delta, ChangeSource.local);
    controller.updateSelection(
      TextSelection.collapsed(offset: plan.caret),
      ChangeSource.local,
    );
    return false;
  };
}

/// 把当前选区触及的每个代码块的每一行设为语言 [value]（true / 'plain' /
/// 语言 id，调用方传入已规整的值）；选区不变。
///
/// 直接按行尾换行组合一个 Delta，而不是对每个块调用 formatText：一次组合
/// 只占一步撤销；且 quill 的行格式规则会把范围之后的第一个换行也带上，
/// 按块范围格式化容易漏到块后一行。
void setDiaryCodeBlockLanguage(QuillController controller, Object value) {
  _formatTouchedCodeLines(controller, <String, dynamic>{
    Attribute.codeBlock.key: value,
  });
}

/// 把当前选区触及的每个代码块转为正文（移除每一行的 `code-block`）。
void convertDiaryCodeBlockToText(QuillController controller) {
  _formatTouchedCodeLines(controller, <String, dynamic>{
    Attribute.codeBlock.key: null,
  });
}

/// 光标在代码块里时跳到块后的普通空行：块后紧跟一个没有块样式的空行就
/// 直接移过去，否则在块后新插一个普通空行再移过去。
void exitDiaryCodeBlock(QuillController controller) {
  final document = controller.document;
  final block = diaryCodeBlockAt(document, controller.selection.extentOffset);
  if (block == null) {
    return;
  }
  final blockEnd = block.documentOffset + block.length;
  final next = block.next;
  if (next is Line && next.length == 1 && !_hasBlockAttributes(next)) {
    controller.updateSelection(
      TextSelection.collapsed(offset: blockEnd),
      ChangeSource.local,
    );
    return;
  }

  final Delta delta;
  if (next != null) {
    // 直接组合而不经 replaceText：PreserveBlockStyleOnInsertRule 会把下一行
    // 的列表 / 引用样式复制给新行。
    delta = Delta()
      ..retain(blockEnd)
      ..insert('\n');
  } else {
    // 代码块是文档最后一个节点：文档末尾的换行之后不能再插入。改为在最后
    // 一个换行之前插入一个带原行属性的换行（内容行留在块里），再把原来的
    // 最后一个换行的块属性全部清掉，成为块后的普通空行。
    final last = block.last as Line;
    final attributes =
        last.style.mergeAll(block.style).toJson() ?? <String, dynamic>{};
    delta = Delta()
      ..retain(blockEnd - 1)
      ..insert('\n', attributes)
      ..retain(1, <String, dynamic>{
        for (final key in attributes.keys) key: null,
      });
  }
  document.compose(delta, ChangeSource.local);
  controller.updateSelection(
    TextSelection.collapsed(offset: blockEnd),
    ChangeSource.local,
  );
}

/// 把 [block] 的纯文本写入系统剪贴板。
Future<void> copyDiaryCodeBlock(Block block) =>
    Clipboard.setData(ClipboardData(text: diaryCodeBlockText(block)));

/// 把当前行（或选区覆盖的各行）设为未指定语言的代码块。
void toggleDiaryCodeBlockOn(QuillController controller) {
  controller.formatSelection(Attribute.codeBlock);
}

void _formatTouchedCodeLines(
  QuillController controller,
  Map<String, dynamic> lineAttributes,
) {
  final selection = controller.selection;
  final blocks = diaryCodeBlocksInRange(
    controller.document,
    selection.start,
    selection.end,
  );
  if (blocks.isEmpty) {
    return;
  }
  final delta = Delta();
  var cursor = 0;
  for (final block in blocks) {
    for (final node in block.children) {
      // 每行的换行在行尾：先跳过行内文字，再给换行设属性。
      final newline = node.documentOffset + node.length - 1;
      delta
        ..retain(newline - cursor)
        ..retain(1, lineAttributes);
      cursor = newline + 1;
    }
  }
  // 只改换行属性，不增删字符，原选区不受影响；组合后经 updateSelection 通知
  // 编辑器重建（选区原样写回）。
  controller.document.compose(delta, ChangeSource.local);
  controller.updateSelection(selection, ChangeSource.local);
}

bool _hasBlockAttributes(Line line) => line.style.attributes.values.any(
  (attribute) => attribute.scope == AttributeScope.block,
);
