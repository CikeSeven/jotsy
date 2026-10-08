import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/backup_test_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  setUp(() async {
    fixture = await BackupTestFixture.create();
    await fixture.seedCurrentData();
  });
  tearDown(() => fixture.dispose());

  for (final password in [null, 'integrity-password']) {
    test(
      '${password == null ? 'plain' : 'encrypted'} ZIP corruption retains all existing data',
      () async {
        final zip = await fixture.writeZip(
          await fixture.capturePayload(),
          files: {
            'diary_videos/clip.mp4': List.generate(100, (index) => index),
          },
          password: password,
        );
        final bytes = await zip.readAsBytes();
        final decoder = ZipDecoder()..decodeBytes(bytes);
        final header = decoder.directory.fileHeaders.singleWhere(
          (header) => header.filename.endsWith('clip.mp4'),
        );
        final local = header.localHeaderOffset!;
        final fields = ByteData.sublistView(bytes);
        final dataOffset =
            local +
            30 +
            fields.getUint16(local + 26, Endian.little) +
            fields.getUint16(local + 28, Endian.little);
        // AES only authenticates its ciphertext: change the authentication code
        // so that a plaintext CRC alone would incorrectly accept this entry.
        final offset = password == null
            ? dataOffset + 2
            : dataOffset + header.compressedSize! - 1;
        bytes[offset] ^= 1;
        await zip.writeAsBytes(bytes);
        await expectLater(
          fixture.import(zip, password: password),
          throwsA(isA<FormatException>()),
        );
        await fixture.expectCurrentDataIntact();
      },
    );
  }

  test(
    'wrong passwords retain all directories, diary rows and the draft',
    () async {
      final zip = await fixture.writeZip(
        await fixture.capturePayload(),
        password: 'right-password',
      );
      await expectLater(
        fixture.import(zip, password: 'wrong-password'),
        throwsA(isA<FormatException>()),
      );
      await fixture.expectCurrentDataIntact();
    },
  );

  test(
    'traversal entries reject import before modifying any current media',
    () async {
      final zip = await fixture.writeZip(
        await fixture.capturePayload(),
        files: {
          '../escape.bin': [1, 2, 3],
        },
      );
      await expectLater(fixture.import(zip), throwsA(isA<FormatException>()));
      await fixture.expectCurrentDataIntact();
      expect(
        await File('${fixture.documents.path}/escape.bin').exists(),
        isFalse,
      );
    },
  );
}
