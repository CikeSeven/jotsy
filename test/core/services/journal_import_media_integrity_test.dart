import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/journal_import_fixture.dart';

void main() {
  late JournalImportFixture fixture;
  setUp(() async => fixture = await JournalImportFixture.create());
  tearDown(() => fixture.dispose());

  test('shared media keeps its original kind after the source was moved', () {
    final source = fixture.write('recording.3gp', [
      0,
      0,
      0,
      20,
      102,
      116,
      121,
      112,
      51,
      103,
      112,
      52,
    ]);
    final first = fixture.media.embedFile(source.path, mime: 'audio/3gpp')!;
    final second = fixture.media.embedFile(source.path)!;
    expect(second, first);
    expect(source.existsSync(), isFalse);
    final recording = jsonDecode(first['audio'] as String) as Map;
    expect(p.split(recording['path'] as String), contains('diary_recordings'));
    expect(File(recording['path'] as String).readAsBytesSync(), [
      0,
      0,
      0,
      20,
      102,
      116,
      121,
      112,
      51,
      103,
      112,
      52,
    ]);
  });

  test(
    'MIME identifies an opaque filename and keeps downloaded audio as audio',
    () {
      final file = fixture.write('photo.bin', JournalImportFixture.jpeg);
      expect(fixture.media.embedFile(file.path, mime: 'image/jpeg')!.keys, [
        'image',
      ]);
      final audio = fixture.media.embedBytes(
        [1, 2, 3],
        name: 'recording.3gp',
        mime: 'audio/3gpp',
      );
      expect(audio.keys, ['audio']);
    },
  );

  test('data URI attachments retain bytes and malformed data is reported', () {
    final image = fixture.media.embedDataUri(
      'data:image/jpeg;base64,${base64.encode(JournalImportFixture.jpeg)}',
    )!;
    expect(
      File(image['image'] as String).readAsBytesSync(),
      JournalImportFixture.jpeg,
    );
    expect(
      fixture.media.embedDataUri('data:image/png;base64,broken!!!'),
      isNull,
    );
    expect(fixture.media.missingCount, 1);
  });

  test(
    'staging a picked local file copies it without changing the original',
    () {
      final outside = File(p.join(fixture.temporary.path, 'original.jpg'))
        ..writeAsBytesSync(JournalImportFixture.jpeg);
      final image = fixture.media.embedFile(outside.path)!;
      expect(outside.readAsBytesSync(), JournalImportFixture.jpeg);
      expect(
        File(image['image'] as String).readAsBytesSync(),
        JournalImportFixture.jpeg,
      );
      expect(image['image'], isNot(outside.path));
    },
  );
}
