import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/ui/diaries/models/media_insertion.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';

void main() {
  const attachment = DiaryFileAttachment(
    path: '/documents/diary_attachments/report.pdf',
    name: '报告.pdf',
    sizeBytes: 1024,
  );

  test(
    'video-only content retains its block layout through repeated save and restore',
    () {
      final controller = quill.QuillController.basic();
      addTearDown(controller.dispose);
      insertDiaryMediaBlocks(
        controller: controller,
        selection: controller.selection,
        embeds: [quill.BlockEmbed.video('/documents/diary_videos/trip.mp4')],
      );
      final original = controller.document.toDelta().toJson();
      var content = encodeDiaryDocumentToJson(controller.document);
      for (var i = 0; i < 3; i++) {
        final restored = decodeDiaryContentToDocument(content);
        expect(restored.toDelta().toJson(), original);
        expect(diaryDocumentHasVisibleContent(restored), isTrue);
        content = encodeDiaryDocumentToJson(restored);
      }
      expect(extractPlainTextFromDiaryDocument(controller.document), isEmpty);
    },
  );

  test(
    'inline imported videos are normalized once without losing surrounding prose',
    () {
      final raw = jsonEncode([
        {'insert': 'before'},
        {
          'insert': {'video': '/video.mp4'},
        },
        {'insert': 'after\n'},
      ]);
      final document = decodeDiaryContentToDocument(raw);
      expect(document.toPlainText(), 'before\n\uFFFC\nafter\n');
      expect(
        decodeDiaryContentToDocument(
          encodeDiaryDocumentToJson(document),
        ).toDelta().toJson(),
        document.toDelta().toJson(),
      );
    },
  );

  test(
    'multiple video and attachment blocks keep an editable trailing line',
    () {
      final controller = quill.QuillController.basic();
      addTearDown(controller.dispose);
      insertDiaryMediaBlocks(
        controller: controller,
        selection: controller.selection,
        embeds: [
          quill.BlockEmbed.video('/documents/diary_videos/first.mp4'),
          quill.BlockEmbed(diaryAttachmentEmbedType, attachment.encode()),
          quill.BlockEmbed.video('/documents/diary_videos/second.mp4'),
        ],
      );
      final ops = controller.document.toDelta().toJson();
      expect(ops.where((op) => op['insert'] is Map), hasLength(3));
      expect(controller.document.toPlainText(), '\uFFFC\n\uFFFC\n\uFFFC\n\n');
      expect(controller.selection.baseOffset, 6);
      controller.replaceText(6, 0, '继续写日记', null);
      expect(controller.document.toPlainText(), endsWith('继续写日记\n'));
    },
  );

  test(
    'media inserted into a selected paragraph preserves all existing prose',
    () {
      final controller = quill.QuillController(
        document: documentFromPlainText('hello world'),
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      addTearDown(controller.dispose);
      insertDiaryMediaBlocks(
        controller: controller,
        selection: controller.selection,
        embeds: [quill.BlockEmbed.video('/video.mp4')],
      );
      expect(controller.document.toPlainText(), 'hello\n\uFFFC\n world\n');
    },
  );

  test(
    'attachment-only drafts survive serialization and empty text mirrors',
    () {
      final controller = quill.QuillController.basic();
      addTearDown(controller.dispose);
      insertDiaryMediaBlocks(
        controller: controller,
        selection: const TextSelection.collapsed(offset: -1),
        embeds: [
          quill.BlockEmbed(diaryAttachmentEmbedType, attachment.encode()),
        ],
      );
      final content = encodeDiaryDocumentToJson(controller.document);
      final draft = NewDiaryDraft(
        title: '',
        contentDocJson: content,
        contentText: extractPlainTextFromDiaryDocument(controller.document),
      );
      expect(draft.contentText, isEmpty);
      expect(draft.hasContent, isTrue);
      expect(extractDiaryFilePaths(content), {attachment.path});
      expect(
        decodeDiaryContentToDocument(content).toDelta().toJson(),
        controller.document.toDelta().toJson(),
      );
    },
  );

  test('legacy imported video and file nodes become visible Quill embeds', () {
    final content = jsonEncode({
      'root': {
        'children': [
          {
            'type': 'video',
            'attributes': {'url': '/legacy/video.mp4'},
          },
          {
            'type': 'file',
            'attributes': {
              'url': '/legacy/file.pdf',
              'name': '旧附件.pdf',
              'size': 2048,
            },
          },
        ],
      },
    });
    final document = decodeDiaryContentToDocument(content);
    expect(diaryDocumentHasVisibleContent(document), isTrue);
    final embeds = document
        .toDelta()
        .toJson()
        .where((op) => op['insert'] is Map)
        .toList();
    expect(embeds, hasLength(2));
    expect((embeds.first['insert'] as Map)['video'], '/legacy/video.mp4');
    final file = DiaryFileAttachment.tryDecode(
      (embeds.last['insert'] as Map)[diaryAttachmentEmbedType],
    );
    expect(file?.displayName, '旧附件.pdf');
    expect(file?.sizeBytes, 2048);
    expect(extractDiaryFilePaths(content), {
      '/legacy/video.mp4',
      '/legacy/file.pdf',
    });
  });

  test(
    'malformed attachments are ignored without losing unrelated content',
    () {
      expect(DiaryFileAttachment.tryDecode('{broken'), isNull);
      expect(DiaryFileAttachment.tryDecode({'path': 123}), isNull);
      expect(DiaryFileAttachment.tryDecode({'path': ' '}), isNull);
      expect(extractDiaryFilePaths('plain text'), isEmpty);
      final raw = {
        'url': '/old/report.pdf',
        'name': '报告.pdf',
        'size': 128,
        'custom': 'keep',
      };
      expect(replaceDiaryFilePath(raw, '/new/report.pdf'), {
        ...raw,
        'url': '/new/report.pdf',
      });
    },
  );
}
