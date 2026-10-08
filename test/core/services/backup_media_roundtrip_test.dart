import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/data_archive_service.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_test_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  setUp(() async => fixture = await BackupTestFixture.create());
  tearDown(() => fixture.dispose());

  for (final password in [null, 'password']) {
    test(
      'backup restores legal dotted video and attachment names (${password == null ? 'plain' : 'encrypted'})',
      () async {
        final video = await DiaryMediaStorageService.importFile(
          kind: DiaryMediaKind.video,
          fileName: '旅程..mp4',
          bytes: [1, 2, 255],
        );
        final file = await DiaryMediaStorageService.importFile(
          kind: DiaryMediaKind.attachment,
          fileName: '报告 100%..pdf',
          bytes: [3, 4, 254],
        );
        final content = jsonEncode([
          {
            'insert': {'video': video.path},
          },
          {'insert': '\n'},
          {
            'insert': {'attachment': file.encode()},
          },
          {'insert': '\n'},
          {
            'insert': {'file': File(file.path).uri.toString()},
          },
          {'insert': '\n'},
        ]);
        final oldDocuments = fixture.documents;
        final relativeVideo = p.relative(video.path, from: oldDocuments.path);
        final relativeFile = p.relative(file.path, from: oldDocuments.path);
        await fixture.database.createDiary(
          title: '',
          contentDocJson: content,
          contentText: '',
          metadataJson: '{}',
        );
        await fixture.settings.setCreateDiaryDraftRaw(
          jsonEncode({'contentDocJson': content}),
        );
        final backup = await DataArchiveService.exportToZip(
          database: fixture.database,
          settingsService: fixture.settings,
          zipPassword: password,
        );
        await oldDocuments.delete(recursive: true);
        fixture.documents = await Directory(
          p.join(fixture.root.path, 'restored_documents'),
        ).create();
        await fixture.import(backup, password: password);
        final restored = await fixture.database
            .select(fixture.database.diaries)
            .getSingle();
        expect(extractDiaryFilePaths(restored.content), {
          p.join(fixture.documents.path, relativeVideo),
          p.join(fixture.documents.path, relativeFile),
        });
        expect(
          await File(
            p.join(fixture.documents.path, relativeVideo),
          ).readAsBytes(),
          [1, 2, 255],
        );
        expect(
          await File(
            p.join(fixture.documents.path, relativeFile),
          ).readAsBytes(),
          [3, 4, 254],
        );
        expect(
          (jsonDecode(fixture.settings.createDiaryDraftRaw!)
              as Map)['contentDocJson'],
          restored.content,
        );
      },
    );
  }

  test(
    'backup preserves all time capsule fields and rebinds a draft cover',
    () async {
      final unlock = DateTime(2027, 1, 2);
      final locked = DateTime(2026, 10, 8);
      final cover = File(
        p.join(fixture.documents.path, 'diary_covers', 'cover.png'),
      );
      await cover.parent.create();
      await cover.writeAsBytes([1, 2, 3]);
      await fixture.database.createDiary(
        title: 'capsule',
        contentDocJson: '[{"insert":"text\\n"}]',
        contentText: 'text',
        metadataJson: '{}',
        cover: cover.path,
        capsuleUnlockAt: unlock,
        capsuleLockedAt: locked,
      );
      await fixture.settings.setCreateDiaryDraftRaw(
        jsonEncode({
          'title': 'draft',
          'contentDocJson': '[{"insert":"draft\\n"}]',
          'cover': cover.path,
        }),
      );
      final backup = await DataArchiveService.exportToZip(
        database: fixture.database,
        settingsService: fixture.settings,
      );
      fixture.documents = await Directory(
        p.join(fixture.root.path, 'new_documents'),
      ).create();
      await fixture.import(backup);
      final diary = await fixture.database
          .select(fixture.database.diaries)
          .getSingle();
      expect(diary.capsuleUnlockAt, unlock);
      expect(diary.capsuleLockedAt, locked);
      final restoredCover = p.join(
        fixture.documents.path,
        'diary_covers',
        'cover.png',
      );
      expect(diary.cover, restoredCover);
      expect(
        (jsonDecode(fixture.settings.createDiaryDraftRaw!) as Map)['cover'],
        restoredCover,
      );
      expect(await File(restoredCover).readAsBytes(), [1, 2, 3]);
    },
  );
}
