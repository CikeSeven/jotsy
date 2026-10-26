import '../../../support/diary_content_test_helpers.dart';
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_media.dart';
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
  late DiaryEditorController documentController;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_media_import_test_');
    pickedFile = File(p.join(root.path, 'picked.bin'));
    await pickedFile.writeAsBytes([1, 2, 3]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
    documentController = DiaryEditorController();
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
        expect(documentController.flatSelection.baseOffset, 4);
        expect(importer.isBusy, isFalse);
        expect(importer.isCopying, isFalse);
      },
    );
  }

  test('picker cache copies are discarded once the import finishes', () async {
    // path_provider 的 mock 让临时目录与 documents 同为 root。
    final cached = File(p.join(root.path, 'file_picker', '1700', 'IMG_1.jpg'));
    await cached.parent.create(recursive: true);
    await cached.writeAsBytes([9, 9]);
    final importer = DiaryMediaImportController(
      picker: (_) async => [
        PlatformFile(name: 'IMG_1.jpg', size: 2, path: cached.path),
        PlatformFile(name: 'picked.bin', size: 3, path: pickedFile.path),
      ],
    );
    addTearDown(importer.dispose);

    expect(
      await importer.pickAndInsert(
        controller: documentController,
        kind: DiaryMediaKind.image,
        isCurrent: () => true,
      ),
      DiaryMediaImportOutcome.inserted,
    );

    expect(await cached.exists(), isFalse);
    expect(await cached.parent.exists(), isFalse);
    expect(await Directory(p.join(root.path, 'file_picker')).exists(), isTrue);
    // 选择器缓存之外的路径（桌面端原文件）不受影响。
    expect(await pickedFile.exists(), isTrue);
  });

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
      documentController.restoreContent(plainTextToContentJson('hello world'));
      documentController.updateSelection(
        const TextSelection.collapsed(offset: 5),
        'local',
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
      importer.cancel();
      documentController.restoreContent(plainTextToContentJson('new document'));
      pickerCompletion.complete([
        PlatformFile(name: 'video.mp4', size: 3, path: pickedFile.path),
      ]);
      expect(await importing, DiaryMediaImportOutcome.cancelled);
      expect(pickCount, 1);
      expect(documentController.document.toPlainText(), 'new document\n');
    },
  );

  group('insertFiles (desktop drag and drop)', () {
    test('picks the block kind from the file extension', () {
      expect(
        DiaryMediaImportController.kindForPath('/a/Photo.JPG'),
        DiaryMediaKind.image,
      );
      expect(
        DiaryMediaImportController.kindForPath('/a/clip.mov'),
        DiaryMediaKind.video,
      );
      for (final path in ['/a/song.mp3', '/a/notes.pdf', '/a/noext']) {
        expect(
          DiaryMediaImportController.kindForPath(path),
          DiaryMediaKind.attachment,
        );
      }
    });

    test('dropped files are copied and inserted in their order', () async {
      final image = File(p.join(root.path, 'dropped.png'));
      await image.writeAsBytes([4, 5, 6]);
      final audio = File(p.join(root.path, 'voice.mp3'));
      await audio.writeAsBytes([7, 8]);
      final folder = Directory(p.join(root.path, 'folder'));
      await folder.create();
      final importer = DiaryMediaImportController();
      addTearDown(importer.dispose);

      expect(
        await importer.insertFiles(
          controller: documentController,
          paths: [image.path, folder.path, audio.path],
          isCurrent: () => true,
        ),
        DiaryMediaImportOutcome.inserted,
      );
      final types = [
        for (final node in walkDiaryEditorNodes(documentController.document))
          node.type,
      ];
      expect(types.indexOf('image'), greaterThanOrEqualTo(0));
      expect(
        types.indexOf(diaryAttachmentEmbedType),
        greaterThan(types.indexOf('image')),
      );
      final nodes = walkDiaryEditorNodes(documentController.document);
      final paths = <String>[
        for (final node in nodes)
          if (node.type == 'image')
            node.attributes['url'] as String
          else if (node.type == diaryAttachmentEmbedType)
            node.attributes['path'] as String,
      ];
      expect(paths, hasLength(2));
      // 复制进私有目录，原文件原样保留。
      for (final path in paths) {
        expect(p.isWithin(root.path, path), isTrue);
        expect(path, isNot(anyOf(image.path, audio.path)));
        expect(await File(path).exists(), isTrue);
      }
      expect(await image.exists(), isTrue);
      expect(await audio.exists(), isTrue);
    });

    test('a dropped file inside the picker cache is never deleted', () async {
      final cached = File(p.join(root.path, 'file_picker', 'mine.png'));
      await cached.parent.create(recursive: true);
      await cached.writeAsBytes([1]);
      final importer = DiaryMediaImportController();
      addTearDown(importer.dispose);
      await importer.insertFiles(
        controller: documentController,
        paths: [cached.path],
        isCurrent: () => true,
      );
      expect(await cached.exists(), isTrue);
    });

    test('nothing usable leaves the document unchanged', () async {
      final importer = DiaryMediaImportController();
      addTearDown(importer.dispose);
      expect(
        await importer.insertFiles(
          controller: documentController,
          paths: [p.join(root.path, 'gone.png'), root.path],
          isCurrent: () => true,
        ),
        DiaryMediaImportOutcome.cancelled,
      );
      expect(documentController.document.toPlainText(), '\n');
    });
  });
}
