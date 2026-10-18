import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/diary_audio_storage_service.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';
import 'package:node_diary/core/services/cloud_backup_service.dart';
import 'package:node_diary/core/services/cloud_backup_settings_service.dart';
import 'package:node_diary/core/services/cloud_backup_target.dart';
import 'package:node_diary/core/services/webdav_client.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_test_fixture.dart';
import '../../support/webdav_test_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  setUp(() async => fixture = await BackupTestFixture.create());
  tearDown(() => fixture.dispose());

  for (final password in [null, 'audit-password']) {
    test(
      'WebDAV backup location preserves mixed media, drafts and recycle bin (${password == null ? 'plain' : 'encrypted'})',
      () async {
        final remoteRoot = await Directory(
          p.join(fixture.root.path, 'remote'),
        ).create();
        final server = await startWebDavFixture(remoteRoot);
        final targets = await CloudBackupSettingsService.create();
        addTearDown(() async {
          targets.dispose();
          await server.close(force: true);
        });
        final target = CloudBackupTarget.create(
          kind: CloudBackupKind.webDav,
          config: {
            'serverUrl': 'http://${server.address.host}:${server.port}/',
            'username': 'audit',
            'password': 'local-fixture-only',
            'remoteDirectory': '/backups/',
          },
        );
        await targets.saveTarget(target);
        final sync = CloudBackupService(
          database: fixture.database,
          settingsService: fixture.settings,
          targets: targets,
          webDavClientFactory: (config) => WebDavClient(
            config: config,
            clientFactory: realFixtureHttpClient,
          ),
        );

        const audioBytes = [0, 255, 1, 254, 128];
        const videoBytes = [3, 0, 255, 129, 2];
        const attachmentBytes = [10, 255, 0, 200];
        const duplicateBytes = [99, 98, 97];
        const storage = DiaryAudioStorageService();
        final pending = await storage.createPendingPath();
        await File(pending).writeAsBytes(audioBytes);
        final audioPath = await storage.persistRecording(pending);
        final audio = DiaryAudioAttachment(
          path: audioPath,
          duration: const Duration(seconds: 7),
          name: '会议录音',
          waveform: const [0.1, 0.8],
        );
        final video = await DiaryMediaStorageService.importFile(
          kind: DiaryMediaKind.video,
          fileName: '旅行.mp4',
          bytes: videoBytes,
        );
        final attachment = await DiaryMediaStorageService.importFile(
          kind: DiaryMediaKind.attachment,
          fileName: '会议 报告.pdf',
          bytes: attachmentBytes,
        );
        final duplicate = await DiaryMediaStorageService.importFile(
          kind: DiaryMediaKind.attachment,
          fileName: '会议 报告.pdf',
          bytes: duplicateBytes,
        );
        final pathsAndBytes = {
          p.relative(audioPath, from: fixture.documents.path): audioBytes,
          p.relative(video.path, from: fixture.documents.path): videoBytes,
          p.relative(attachment.path, from: fixture.documents.path):
              attachmentBytes,
          p.relative(duplicate.path, from: fixture.documents.path):
              duplicateBytes,
        };
        final content = jsonEncode([
          {
            'insert': {'audio': audio.encode()},
          },
          {'insert': '\n'},
          {
            'insert': {'video': video.path},
          },
          {'insert': '\n'},
          {
            'insert': {'attachment': attachment.encode()},
          },
          {'insert': '\n'},
          {
            'insert': {'attachment': duplicate.encode()},
          },
          {'insert': '\n'},
        ]);
        final diaryId = await fixture.database.createDiary(
          title: 'mixed media',
          contentDocJson: content,
          contentText: '',
          metadataJson: '{}',
        );
        await fixture.database.softDeleteDiary(diaryId);
        await fixture.database.saveDiaryDraft(
          title: '',
          contentText: '',
          payload: jsonEncode({
            'title': '',
            'contentDocJson': content,
            'contentText': '',
          }),
        );

        final entry = await sync.uploadCurrentBackup(
          target,
          zipPassword: password,
        );
        final listed = await sync.listBackups(target);
        expect(listed.map((backup) => backup.fileName), [entry.fileName]);
        // manifest 记录的创建时间与文件名推断一致，manifest 本身不算备份。
        expect(
          listed.single.createdAt!.isAtSameMomentAs(entry.createdAt!),
          isTrue,
        );
        final localZip = await sync.downloadBackup(target, entry);
        expect(
          await sync.isLocalBackupPasswordProtected(localZip),
          password != null,
        );
        await fixture.documents.delete(recursive: true);
        fixture.documents = await Directory(
          p.join(fixture.root.path, 'restored_documents'),
        ).create();
        await sync.restoreFromLocalBackup(
          zipFile: localZip,
          zipPassword: password,
          mode: BackupImportMode.replaceAll,
        );

        final restored = await fixture.database
            .select(fixture.database.diaries)
            .getSingle();
        expect(restored.diaryId, diaryId);
        expect(restored.isDeleted, isTrue);
        final expectedPaths = pathsAndBytes.keys
            .map((relative) => p.join(fixture.documents.path, relative))
            .toSet();
        expect({
          ...extractDiaryAudioPaths(restored.content),
          ...extractDiaryFilePaths(restored.content),
        }, expectedPaths);
        final draft =
            jsonDecode(
                  (await fixture.database
                          .select(fixture.database.diaryDrafts)
                          .getSingle())
                      .payload,
                )
                as Map;
        expect(draft['contentDocJson'], restored.content);
        for (final item in pathsAndBytes.entries) {
          expect(
            await File(p.join(fixture.documents.path, item.key)).readAsBytes(),
            item.value,
          );
        }
        final first = (jsonDecode(restored.content) as List).first as Map;
        final restoredAudio = DiaryAudioAttachment.tryDecode(
          (first['insert'] as Map)['audio'],
        )!;
        expect(restoredAudio.name, audio.name);
        expect(restoredAudio.duration, audio.duration);
        expect(restoredAudio.waveform, audio.waveform);
      },
    );
  }
}
