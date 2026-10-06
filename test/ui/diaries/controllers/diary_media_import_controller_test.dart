import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/ui/diaries/controllers/diary_media_import_controller.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  const galleryChannel = MethodChannel('com.jotsy.diary/video_gallery');
  late Directory root;
  late File pickedFile;
  late quill.QuillController documentController;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_media_import_test_');
    pickedFile = File(p.join(root.path, 'picked.bin'));
    await pickedFile.writeAsBytes([1, 2, 3]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
    documentController = quill.QuillController.basic();
  });

  tearDown(() async {
    documentController.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(galleryChannel, null);
    debugDefaultTargetPlatformOverride = null;
    await root.delete(recursive: true);
  });

  test(
    'Android video action imports from the gallery without invoking the file picker',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var opened = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(galleryChannel, (call) async {
            opened = true;
            expect(call.method, 'pickVideos');
            return [
              {'name': 'gallery.mp4', 'path': pickedFile.path, 'size': 3},
            ];
          });
      final importer = DiaryMediaImportController();
      addTearDown(importer.dispose);
      expect(
        await importer.pickAndInsert(
          controller: documentController,
          kind: DiaryMediaKind.video,
          isCurrent: () => true,
        ),
        DiaryMediaImportOutcome.inserted,
      );
      expect(opened, isTrue);
      final paths = extractDiaryFilePaths(
        encodeDiaryDocumentToJson(documentController.document),
      );
      expect(paths, hasLength(1));
      expect(await File(paths.single).readAsBytes(), [1, 2, 3]);
    },
  );

  test(
    'cancelling Android gallery preserves the document and ends the import',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(galleryChannel, (_) async => null);
      final importer = DiaryMediaImportController();
      addTearDown(importer.dispose);
      expect(
        await importer.pickAndInsert(
          controller: documentController,
          kind: DiaryMediaKind.video,
          isCurrent: () => true,
        ),
        DiaryMediaImportOutcome.cancelled,
      );
      expect(documentController.document.toPlainText(), '\n');
      expect(importer.isBusy, isFalse);
    },
  );

  for (final kind in [DiaryMediaKind.video, DiaryMediaKind.attachment]) {
    test(
      '$kind import copies every selected file before inserting blocks',
      () async {
        final importer = DiaryMediaImportController(
          picker: (_) async => [
            PlatformFile(name: 'first.mp4', size: 3, path: pickedFile.path),
            PlatformFile(name: 'second.pdf', size: 3, path: pickedFile.path),
          ],
        );
        addTearDown(importer.dispose);
        final result = await importer.pickAndInsert(
          controller: documentController,
          kind: kind,
          isCurrent: () => true,
        );
        expect(result, DiaryMediaImportOutcome.inserted);
        final content = encodeDiaryDocumentToJson(documentController.document);
        final paths = extractDiaryFilePaths(content);
        expect(paths, hasLength(2));
        for (final path in paths) {
          expect(await File(path).readAsBytes(), [1, 2, 3]);
          expect(
            p.isWithin(
              p.join(
                root.path,
                DiaryMediaStorageService.directoryNameFor(kind),
              ),
              path,
            ),
            isTrue,
          );
        }
        expect(documentController.selection.baseOffset, 4);
        expect(importer.isBusy, isFalse);
        expect(importer.isCopying, isFalse);
      },
    );
  }

  test('cancelling the picker leaves the document unchanged', () async {
    final importer = DiaryMediaImportController(picker: (_) async => null);
    addTearDown(importer.dispose);
    final original = documentController.document.toDelta().toJson();
    expect(
      await importer.pickAndInsert(
        controller: documentController,
        kind: DiaryMediaKind.attachment,
        isCurrent: () => true,
      ),
      DiaryMediaImportOutcome.cancelled,
    );
    expect(documentController.document.toDelta().toJson(), original);
    expect(importer.isBusy, isFalse);
  });

  test(
    'a failed batch removes copied files and inserts no incomplete content',
    () async {
      final importer = DiaryMediaImportController(
        picker: (_) async => [
          PlatformFile(name: 'good.pdf', size: 3, path: pickedFile.path),
          PlatformFile(
            name: 'missing.pdf',
            size: 3,
            path: p.join(root.path, 'missing.pdf'),
          ),
        ],
      );
      addTearDown(importer.dispose);
      expect(
        await importer.pickAndInsert(
          controller: documentController,
          kind: DiaryMediaKind.attachment,
          isCurrent: () => true,
        ),
        DiaryMediaImportOutcome.failed,
      );
      expect(documentController.document.toPlainText(), '\n');
      final directory = Directory(p.join(root.path, 'diary_attachments'));
      expect(await directory.list(recursive: true).toList(), isEmpty);
      expect(await pickedFile.exists(), isTrue);
    },
  );

  test(
    'leaving the editor during file copying discards the uncommitted copy',
    () async {
      final copied = await DiaryMediaStorageService.importFile(
        kind: DiaryMediaKind.attachment,
        fileName: 'pending.pdf',
        sourcePath: pickedFile.path,
      );
      final copyCompletion = Completer<DiaryFileAttachment>();
      final importer = DiaryMediaImportController(
        picker: (_) async => [PlatformFile(name: 'pending.pdf', size: 3)],
        importer: (_, _) => copyCompletion.future,
      );
      final importing = importer.pickAndInsert(
        controller: documentController,
        kind: DiaryMediaKind.attachment,
        isCurrent: () => true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(importer.isCopying, isTrue);
      importer.dispose();
      copyCompletion.complete(copied);
      expect(await importing, DiaryMediaImportOutcome.cancelled);
      expect(await File(copied.path).exists(), isFalse);
      expect(documentController.document.toPlainText(), '\n');
    },
  );

  test(
    'edits while the picker is open move the captured insertion anchor',
    () async {
      documentController.document = documentFromPlainText('hello world');
      documentController.updateSelection(
        const TextSelection.collapsed(offset: 5),
        quill.ChangeSource.local,
      );
      final pickerCompletion = Completer<List<PlatformFile>?>();
      final importer = DiaryMediaImportController(
        picker: (_) => pickerCompletion.future,
      );
      addTearDown(importer.dispose);
      final importing = importer.pickAndInsert(
        controller: documentController,
        kind: DiaryMediaKind.attachment,
        isCurrent: () => true,
      );
      documentController.replaceText(0, 0, 'prefix ', null);
      await Future<void>.delayed(Duration.zero);
      pickerCompletion.complete([
        PlatformFile(name: 'report.pdf', size: 3, path: pickedFile.path),
      ]);
      expect(await importing, DiaryMediaImportOutcome.inserted);
      expect(
        documentController.document.toPlainText(),
        'prefix hello\n\uFFFC\n world\n',
      );
    },
  );

  test(
    'repeated taps share one active picker and a replaced document cancels import',
    () async {
      var pickCount = 0;
      final pickerCompletion = Completer<List<PlatformFile>?>();
      final importer = DiaryMediaImportController(
        picker: (_) {
          pickCount++;
          return pickerCompletion.future;
        },
      );
      addTearDown(importer.dispose);
      final importing = importer.pickAndInsert(
        controller: documentController,
        kind: DiaryMediaKind.video,
        isCurrent: () => true,
      );
      expect(
        await importer.pickAndInsert(
          controller: documentController,
          kind: DiaryMediaKind.attachment,
          isCurrent: () => true,
        ),
        DiaryMediaImportOutcome.busy,
      );
      documentController.document = documentFromPlainText('new document');
      pickerCompletion.complete([
        PlatformFile(name: 'video.mp4', size: 3, path: pickedFile.path),
      ]);
      expect(await importing, DiaryMediaImportOutcome.cancelled);
      expect(pickCount, 1);
      expect(documentController.document.toPlainText(), 'new document\n');
    },
  );
}
