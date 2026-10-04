import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/image_insertion.dart';

void main() {
  group('insertDiaryImages', () {
    test(
      'does nothing when imagePaths is empty or contains only whitespace',
      () {
        final controller = quill.QuillController.basic();
        addTearDown(controller.dispose);

        insertDiaryImages(controller: controller, imagePaths: <String>[]);
        expect(controller.document.length, 1); // Only default trailing \n

        insertDiaryImages(
          controller: controller,
          imagePaths: <String>['', '   '],
        );
        expect(controller.document.length, 1);
      },
    );

    test(
      'inserts single image into empty document with newline and cursor position',
      () {
        final controller = quill.QuillController.basic();
        addTearDown(controller.dispose);

        insertDiaryImages(
          controller: controller,
          imagePaths: <String>['/path/to/img1.png'],
        );

        final delta = controller.document.toDelta();
        // Delta should have: image embed, newline, and final document newline
        expect(delta.operations.length, greaterThanOrEqualTo(2));
        expect(
          delta.operations.any(
            (op) =>
                op.isInsert &&
                op.data is Map &&
                (op.data as Map)['image'] == '/path/to/img1.png',
          ),
          isTrue,
        );
        // Cursor should be positioned right after the image embed and its newline
        expect(controller.selection.baseOffset, 2);
      },
    );

    test(
      'inserts multiple images in sequential order, each on its own line',
      () {
        final controller = quill.QuillController.basic();
        addTearDown(controller.dispose);

        final images = <String>[
          '/path/to/first.jpg',
          '/path/to/second.png',
          '/path/to/third.webp',
        ];

        insertDiaryImages(controller: controller, imagePaths: images);

        final delta = controller.document.toDelta();
        final insertedImages = delta.operations
            .where(
              (op) =>
                  op.isInsert &&
                  op.data is Map &&
                  (op.data as Map).containsKey('image'),
            )
            .map((op) => (op.data as Map)['image'] as String)
            .toList();

        expect(insertedImages, images);
        // Each image contributes 2 offsets (embed + newline)
        expect(controller.selection.baseOffset, images.length * 2);
      },
    );

    test('breaks line first if cursor is preceded by non-newline text', () {
      final controller = quill.QuillController.basic();
      addTearDown(controller.dispose);

      controller.document.insert(0, 'Hello world');
      // Place cursor at the end of 'Hello world' (offset 11)
      controller.updateSelection(
        const TextSelection.collapsed(offset: 11),
        quill.ChangeSource.local,
      );

      insertDiaryImages(
        controller: controller,
        imagePaths: <String>['/path/to/sample.png'],
      );

      final plainText = controller.document.toPlainText();
      // A newline should precede the embed if insertion was after text
      expect(plainText.startsWith('Hello world\n'), isTrue);
    });

    test('replaces selected text range before inserting images', () {
      final controller = quill.QuillController.basic();
      addTearDown(controller.dispose);

      controller.document.insert(0, 'Start [REPLACE_ME] End');
      // Select '[REPLACE_ME]'
      const start = 6;
      const end = 18;
      controller.updateSelection(
        const TextSelection(baseOffset: start, extentOffset: end),
        quill.ChangeSource.local,
      );

      insertDiaryImages(
        controller: controller,
        imagePaths: <String>['/path/to/replacement.png'],
      );

      final plainText = controller.document.toPlainText();
      expect(plainText.contains('[REPLACE_ME]'), isFalse);
      expect(plainText.startsWith('Start \n'), isTrue);
    });
  });
}
