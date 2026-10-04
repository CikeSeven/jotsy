import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Inserts one or more image blocks into the diary document at the current selection.
///
/// Ensures each image occupies its own block line, separates multiple images
/// with clean newlines, and positions the cursor on a new line after insertion.
void insertDiaryImages({
  required quill.QuillController controller,
  required List<String> imagePaths,
  TextSelection? selection,
}) {
  final validPaths = imagePaths
      .where((path) => path.trim().isNotEmpty)
      .toList();
  if (validPaths.isEmpty) return;
  controller.skipRequestKeyboard = true;

  final sel = selection ?? controller.selection;
  final documentLength = controller.document.length;
  final maxOffset = documentLength <= 0 ? 0 : documentLength - 1;
  final start = sel.isValid ? sel.start.clamp(0, maxOffset) : maxOffset;
  final end = sel.isValid ? sel.end.clamp(0, maxOffset) : start;
  final replaceLength = (end - start).clamp(0, documentLength - start);

  var currentOffset = start;
  if (replaceLength > 0) {
    controller.replaceText(start, replaceLength, '', null, ignoreFocus: true);
  }

  final text = controller.document.toPlainText();

  // If preceding character is not a newline and not at start of note, break line first
  if (currentOffset > 0 &&
      text.length >= currentOffset &&
      text[currentOffset - 1] != '\n') {
    controller.replaceText(currentOffset, 0, '\n', null, ignoreFocus: true);
    currentOffset++;
  }

  for (final imagePath in validPaths) {
    controller.replaceText(
      currentOffset,
      0,
      quill.BlockEmbed.image(imagePath),
      null,
      ignoreFocus: true,
    );
    currentOffset++;

    // Add newline after each image embed
    controller.replaceText(currentOffset, 0, '\n', null, ignoreFocus: true);
    currentOffset++;
  }

  final targetCursor = currentOffset.clamp(
    0,
    controller.document.length <= 0 ? 0 : controller.document.length - 1,
  );
  controller.moveCursorToPosition(targetCursor);
}
