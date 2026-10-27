import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_background_storage_service.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_test_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 复用备份测试的隔离目录：它把 path_provider 的文档目录指向临时目录，
  // appDataRootDirectory（手机分支）因此落在这里。
  late BackupTestFixture fixture;
  setUp(() async => fixture = await BackupTestFixture.create());
  tearDown(() => fixture.dispose());

  Directory managed() => Directory(
    p.join(fixture.documents.path, AppBackgroundStorageService.directoryName),
  );

  Future<String> writeSource(String name, List<int> bytes) async {
    final file = File(p.join(fixture.root.path, name));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  test('imports a copy and returns only its file name', () async {
    final source = await writeSource('Photo.PNG', [1, 2, 3]);
    final name = await AppBackgroundStorageService.importImage(source);

    expect(name, matches(RegExp(r'^bg_\d+\.png$')));
    expect(p.basename(name), name);
    expect(await File(p.join(managed().path, name)).readAsBytes(), [1, 2, 3]);
    // 原图不动。
    expect(await File(source).readAsBytes(), [1, 2, 3]);

    final resolved = await AppBackgroundStorageService.resolve(name);
    expect(resolved?.path, p.join(managed().path, name));
    expect(
      AppBackgroundStorageService.pathFor(fixture.documents, name),
      resolved?.path,
    );
  });

  test('falls back to .jpg when the source has no extension', () async {
    final source = await writeSource('noext', [1]);
    expect(
      await AppBackgroundStorageService.importImage(source),
      endsWith('.jpg'),
    );
  });

  test('rejects a missing source file', () async {
    await expectLater(
      AppBackgroundStorageService.importImage(
        p.join(fixture.root.path, 'missing.png'),
      ),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('resolve rejects traversal and missing files', () async {
    // 托管目录外放一个真实存在的文件，确认穿越写法拿不到它。
    await File(p.join(fixture.documents.path, 'secret.png')).writeAsBytes([1]);
    await managed().create(recursive: true);
    for (final name in <String?>[
      null,
      '',
      ' bg.png',
      '.',
      '..',
      '../secret.png',
      '..\\secret.png',
      'sub/bg.png',
      'C:secret.png',
      p.join(fixture.documents.path, 'secret.png'),
    ]) {
      expect(AppBackgroundStorageService.isValidName(name), isFalse);
      expect(await AppBackgroundStorageService.resolve(name), isNull);
    }
    expect(AppBackgroundStorageService.isValidName('bg_1.png'), isTrue);
    expect(await AppBackgroundStorageService.resolve('bg_1.png'), isNull);
  });

  test('deleteUnreferenced only removes unreferenced plain files', () async {
    final keep = await AppBackgroundStorageService.importImage(
      await writeSource('a.png', [1]),
    );
    final drop = await AppBackgroundStorageService.importImage(
      await writeSource('b.png', [2]),
    );
    final nested = await Directory(
      p.join(managed().path, 'nested'),
    ).create(recursive: true);
    await File(p.join(nested.path, 'inner.png')).writeAsBytes([3]);
    final outside = File(p.join(fixture.documents.path, 'outside.png'));
    await outside.writeAsBytes([4]);

    expect(await AppBackgroundStorageService.deleteUnreferenced({keep}), 1);
    expect(await File(p.join(managed().path, keep)).exists(), isTrue);
    expect(await File(p.join(managed().path, drop)).exists(), isFalse);
    expect(await File(p.join(nested.path, 'inner.png')).exists(), isTrue);
    expect(await outside.exists(), isTrue);
  });

  test('deleteUnreferenced is a no-op without the directory', () async {
    expect(await AppBackgroundStorageService.deleteUnreferenced({}), 0);
  });
}
