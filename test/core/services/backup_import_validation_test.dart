import 'dart:io';

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

  final invalidDatabases = <String, Object?>{
    'missing database': null,
    'missing table lists': <String, Object?>{},
    'non-list diaries': {'diaries': {}, 'tags': [], 'diaryTags': []},
    'non-map diary row': {
      'diaries': ['invalid'],
      'tags': [],
      'diaryTags': [],
    },
    'missing diary fields': {
      'diaries': [
        {'id': 1},
      ],
      'tags': [],
      'diaryTags': [],
    },
    'missing tags': {'diaries': [], 'diaryTags': []},
  };
  for (final entry in invalidDatabases.entries) {
    test(
      '${entry.key} rejects restoration and retains all current media',
      () async {
        final payload = fixture.emptyPayload()..['database'] = entry.value;
        final zip = await fixture.writeZip(payload);
        await expectLater(fixture.import(zip), throwsA(isA<FormatException>()));
        await fixture.expectCurrentDataIntact();
      },
    );
  }

  test(
    'unsupported versions retain the current database, draft and media',
    () async {
      final payload = fixture.emptyPayload()..['formatVersion'] = 2;
      await expectLater(
        fixture.import(await fixture.writeZip(payload)),
        throwsA(isA<FormatException>()),
      );
      await fixture.expectCurrentDataIntact();
    },
  );

  test(
    'malformed settings reject restoration before swapping directories',
    () async {
      final payload = fixture.emptyPayload()..['settings'] = 42;
      await expectLater(
        fixture.import(await fixture.writeZip(payload)),
        throwsA(isA<FormatException>()),
      );
      await fixture.expectCurrentDataIntact();
    },
  );

  test(
    'duplicate diary identities reject restoration before modifying existing data',
    () async {
      final payload = await fixture.capturePayload();
      final database = payload['database'] as Map;
      final row = (database['diaries'] as List).single as Map;
      database['diaries'] = [
        row,
        {...row, 'id': 2},
      ];
      await expectLater(
        fixture.import(await fixture.writeZip(payload)),
        throwsA(isA<FormatException>()),
      );
      await fixture.expectCurrentDataIntact();
    },
  );

  test(
    'an explicitly empty valid backup can replace the current database',
    () async {
      await fixture.import(await fixture.writeZip(fixture.emptyPayload()));
      expect(
        await fixture.database.select(fixture.database.diaries).get(),
        isEmpty,
      );
      expect(fixture.settings.createDiaryDraftRaw, isNull);
      for (final path in fixture.originalMedia.keys) {
        expect(await File(path).exists(), isFalse);
      }
    },
  );
}
