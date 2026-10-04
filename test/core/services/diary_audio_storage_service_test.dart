import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_audio_storage_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  const storage = DiaryAudioStorageService();
  late Directory root;
  late Directory documents;
  late Directory temporary;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_recording_storage_');
    documents = await Directory(p.join(root.path, 'documents')).create();
    temporary = await Directory(p.join(root.path, 'temporary')).create();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => switch (call.method) {
            'getTemporaryDirectory' => temporary.path,
            'getApplicationDocumentsDirectory' => documents.path,
            _ => null,
          },
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  test(
    'finished recording moves from pending into managed documents',
    () async {
      final path = await storage.createPendingPath();
      await File(path).writeAsBytes([1, 2, 3, 4]);
      final durable = await storage.persistRecording(path);
      expect(
        p.isWithin(p.join(documents.path, 'diary_recordings'), durable),
        isTrue,
      );
      expect(await File(path).exists(), isFalse);
      expect(await File(durable).readAsBytes(), [1, 2, 3, 4]);
    },
  );

  test(
    'empty recordings are not committed and cleanup preserves external files',
    () async {
      final path = await storage.createPendingPath();
      await File(path).writeAsBytes([]);
      await expectLater(
        storage.persistRecording(path),
        throwsA(isA<FileSystemException>()),
      );
      final external = File(p.join(root.path, 'external.m4a'));
      await external.writeAsBytes([1]);
      await storage.deleteManagedRecording(external.path);
      await storage.deletePendingRecording(external.path);
      expect(await external.exists(), isTrue);
      await storage.deletePendingRecording(path);
      expect(await File(path).exists(), isFalse);
    },
  );
}
