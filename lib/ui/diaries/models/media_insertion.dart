import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// 视频/附件按独立块插入，保留选中的正文并把光标放到最后一个块后的空行。
void insertDiaryMediaBlocks({
  required quill.QuillController controller,
  required List<quill.BlockEmbed> embeds,
  required TextSelection selection,
}) {
  if (embeds.isEmpty) return;
  controller.skipRequestKeyboard = true;
  final maxOffset = controller.document.length - 1;
  var index = selection.isValid ? selection.end.clamp(0, maxOffset) : maxOffset;
  final text = controller.document.toPlainText();
  if (index > 0 && text[index - 1] != '\n') {
    controller.replaceText(index, 0, '\n', null, ignoreFocus: true);
    index++;
  }
  for (final embed in embeds) {
    // 先创建空块，保证视频的插入规则不会将后方正文与媒体块合并。
    controller.replaceText(index, 0, '\n', null, ignoreFocus: true);
    final lengthBeforeEmbed = controller.document.length;
    controller.replaceText(index, 0, embed, null, ignoreFocus: true);
    // Quill 的 compose 还会为视频自动补换行。按实际增长量去掉本次多余的
    // 空行，不触碰用户原有换行，确保后续文件与光标的偏移恒为两个字符。
    final extraNewlines = controller.document.length - lengthBeforeEmbed - 1;
    if (extraNewlines > 0) {
      controller.replaceText(
        index + 2,
        extraNewlines,
        '',
        null,
        ignoreFocus: true,
      );
    }
    index += 2;
  }
  controller.moveCursorToPosition(
    index.clamp(0, controller.document.length - 1),
  );
}
