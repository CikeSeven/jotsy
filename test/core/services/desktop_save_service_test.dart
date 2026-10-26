import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/desktop_save_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('desktop_save_test_');
  });

  tearDown(() async {
    await sandbox.delete(recursive: true);
  });

  test(
    'copies the source to the chosen path and filters by extension',
    () async {
      final source = File(p.join(sandbox.path, 'src', 'IMG_1.jpg'))
        ..createSync(recursive: true)
        ..writeAsStringSync('jpeg');
      final target = p.join(sandbox.path, 'out', 'picked.jpg');
      String? askedName;
      String? askedExtension;
      final service = DesktopSaveService(
        pickPath:
            ({
              required String dialogTitle,
              required String fileName,
              required String extension,
            }) async {
              askedName = fileName;
              askedExtension = extension;
              return target;
            },
      );

      final saved = await service.saveFile(
        source,
        fileName: 'IMG_1.jpg',
        dialogTitle: 'Save image',
      );

      expect(saved, target);
      expect(askedName, 'IMG_1.jpg');
      expect(askedExtension, 'jpg');
      expect(File(target).readAsStringSync(), 'jpeg');
      // 源文件只读，原样保留。
      expect(source.existsSync(), isTrue);
    },
  );

  test('cancelling the dialog writes nothing', () async {
    final service = DesktopSaveService(
      pickPath:
          ({
            required String dialogTitle,
            required String fileName,
            required String extension,
          }) async => null,
    );
    expect(
      await service.saveBytes(
        Uint8List.fromList(<int>[1, 2, 3]),
        fileName: 'code.png',
        dialogTitle: 'Save image',
      ),
      isNull,
    );
    expect(sandbox.listSync(), isEmpty);
  });

  test('saving into a folder never overwrites existing files', () async {
    final folder = Directory(p.join(sandbox.path, 'folder'))..createSync();
    File(p.join(folder.path, 'jotsy_01.jpg')).writeAsStringSync('old');
    final first = File(p.join(sandbox.path, 'a.jpg'))..writeAsStringSync('a');
    final second = File(p.join(sandbox.path, 'b.jpg'))..writeAsStringSync('b');
    final service = DesktopSaveService(
      pickDirectory: ({required String dialogTitle}) async => folder.path,
    );

    final saved = await service.saveFilesToDirectory(
      <File>[first, second],
      fileNames: const <String>['jotsy_01.jpg', 'jotsy_02.jpg'],
      dialogTitle: 'Choose a folder',
    );

    expect(saved, folder.path);
    expect(File(p.join(folder.path, 'jotsy_01.jpg')).readAsStringSync(), 'old');
    expect(
      File(p.join(folder.path, 'jotsy_01 (2).jpg')).readAsStringSync(),
      'a',
    );
    expect(File(p.join(folder.path, 'jotsy_02.jpg')).readAsStringSync(), 'b');
  });
}
