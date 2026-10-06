import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/ui/diaries/models/diary_export_document.dart';
import 'package:node_diary/ui/diaries/models/media_insertion.dart';
import 'package:node_diary/ui/diaries/utils/diary_markdown_exporter.dart';

void main() {
  test(
    'PDF and Markdown retain readable file names without mutating the diary',
    () {
      final controller = quill.QuillController.basic();
      addTearDown(controller.dispose);
      const file = DiaryFileAttachment(
        path: '/private/diary_attachments/report (1).pdf',
        name: '报告 (1).pdf',
      );
      insertDiaryMediaBlocks(
        controller: controller,
        selection: const TextSelection.collapsed(offset: 0),
        embeds: [
          quill.BlockEmbed.video('/private/diary_videos/trip.mp4'),
          quill.BlockEmbed(diaryAttachmentEmbedType, file.encode()),
        ],
      );
      final original = controller.document.toDelta().toJson();
      final pdf = buildDiaryPdfExportDocument(controller.document);
      expect(pdf.toPlainText(), contains('报告 (1).pdf'));
      expect(pdf.toPlainText(), contains('trip.mp4'));
      expect(pdf.toPlainText(), isNot(contains('/private')));
      final markdown = DiaryMarkdownExporter.build(
        title: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        tagNames: [],
        document: controller.document,
      );
      expect(markdown, contains(r'[报告 \(1\).pdf]'));
      expect(markdown, contains('report%20%281%29.pdf'));
      expect(controller.document.toDelta().toJson(), original);
    },
  );

  test(
    'PDF preserves ordinary formatting and links for remote imported files',
    () {
      final document = quill.Document.fromJson([
        {
          'insert': '正文',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
        {
          'insert': {
            'file': {
              'url': 'https://example.invalid/report.pdf',
              'name': '报告.pdf',
            },
          },
        },
        {'insert': '\n'},
      ]);
      final exported = buildDiaryPdfExportDocument(document).toDelta().toJson();
      expect(exported.first, {
        'insert': '正文',
        'attributes': {'bold': true},
      });
      expect(exported[2], {
        'insert': '报告.pdf',
        'attributes': {'link': 'https://example.invalid/report.pdf'},
      });
    },
  );
}
