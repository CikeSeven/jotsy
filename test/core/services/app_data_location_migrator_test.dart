import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/services/app_data_location.dart';
import 'package:node_diary/core/services/app_data_location_bootstrapper.dart';
import 'package:node_diary/core/services/app_data_location_migrator.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Directory supportDir;
  late Directory sourceRoot;
  late Directory targetRoot;
  late AppDataLocationStore store;
  late AppDataLocationMigrator migrator;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('jotsy_migrator_test_');
    supportDir = Directory(p.join(tempRoot.path, 'support'))..createSync();
    sourceRoot = supportDir;
    targetRoot = Directory(p.join(tempRoot.path, 'moved_data'));
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    store = AppDataLocationStore(
      supportDirectoryProvider: () async => supportDir,
      executableDirectoryProvider: () => null,
    );
    migrator = AppDataLocationMigrator(store: store);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  String buildDiaryDoc({
    required String imagePath,
    required String audioPath,
    required String videoPath,
    required String attachmentPath,
    required String externalPath,
  }) => encodeDiaryBlocks(<String, Object?>{
    kDiaryBlocksDocumentKey: <String, Object?>{
      'type': kDiaryBlockPage,
      'children': <Object?>[
        <String, Object?>{
          'type': kDiaryBlockImage,
          'data': <String, Object?>{'url': imagePath},
        },
        <String, Object?>{
          'type': kDiaryBlockAudio,
          'data': <String, Object?>{'path': audioPath, 'durationMs': 1200},
        },
        <String, Object?>{
          'type': kDiaryBlockVideo,
          'data': <String, Object?>{'url': videoPath},
        },
        <String, Object?>{
          'type': kDiaryBlockAttachment,
          'data': <String, Object?>{
            'path': attachmentPath,
            'name': 'doc.pdf',
            'sizeBytes': 4,
          },
        },
        <String, Object?>{
          'type': kDiaryBlockImage,
          'data': <String, Object?>{'url': externalPath},
        },
      ],
    },
  });

  Future<
    ({
      DateTime diaryUpdatedAt,
      DateTime notebookUpdatedAt,
      DateTime commentEditedAt,
      DateTime draftUpdatedAt,
    })
  >
  seedSourceDataset(Directory root, SettingsService settings) async {
    String createMediaFile(String rel, List<int> bytes) {
      final file = File(p.joinAll(<String>[root.path, ...rel.split('/')]));
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
      return file.path;
    }

    final diaryImg = createMediaFile('diary_images/d1/photo.jpg', <int>[
      1,
      2,
      3,
      4,
    ]);
    final diaryAudio = createMediaFile('diary_recordings/voice.m4a', <int>[
      5,
      6,
    ]);
    final diaryVideo = createMediaFile('diary_videos/clip.mp4', <int>[7, 8, 9]);
    final diaryAttach = createMediaFile('diary_attachments/doc.pdf', <int>[
      10,
      11,
    ]);
    final diaryCover = createMediaFile('diary_covers/cover.jpg', <int>[12, 13]);
    final notebookCover = createMediaFile('diary_covers/nb.png', <int>[14, 15]);
    final commentImg = createMediaFile('diary_images/comment.jpg', <int>[16]);
    final aiImg = createMediaFile('diary_images/ai.jpg', <int>[17, 18]);
    final draftImg = createMediaFile('diary_images/draft.jpg', <int>[19]);
    final draftCover = createMediaFile('diary_covers/draft_cover.jpg', <int>[
      20,
    ]);
    final legacyDraftImg = createMediaFile('diary_images/legacy.jpg', <int>[
      21,
    ]);
    createMediaFile('diary_fonts/custom.ttf', <int>[22, 23]);
    createMediaFile('lan_sync/state.json', <int>[24]);
    createMediaFile('cloud_backup_state/state.json', <int>[25]);
    createMediaFile('media_dedup_state/index.json', <int>[26]);
    Directory(p.join(root.path, 'app_backgrounds')).createSync(recursive: true);

    const externalPath = '/outside/external/picture.png';
    final createdAt = DateTime(2025, 1, 1, 8, 0);
    final diaryUpdatedAt = DateTime(2025, 1, 2, 9, 30, 15);
    final notebookUpdatedAt = DateTime(2025, 2, 3, 10, 0);
    final commentEditedAt = DateTime(2025, 3, 4, 11, 20);
    final draftUpdatedAt = DateTime(2025, 4, 5, 12, 0);

    final db = AppDatabase.openFile(
      File(p.join(root.path, appDatabaseFileName)),
    );
    try {
      await db
          .into(db.diaries)
          .insert(
            DiariesCompanion.insert(
              diaryId: 'd-1',
              title: const Value<String>('迁移日记'),
              content: buildDiaryDoc(
                imagePath: diaryImg,
                audioPath: diaryAudio,
                videoPath: diaryVideo,
                attachmentPath: diaryAttach,
                externalPath: externalPath,
              ),
              contentText: '正文内容',
              cover: Value<String?>(diaryCover),
              createdAt: createdAt,
              updatedAt: diaryUpdatedAt,
            ),
          );
      await db
          .into(db.notebooks)
          .insert(
            NotebooksCompanion.insert(
              notebookId: 'nb-1',
              name: '工作笔记',
              payload: Value<String>(
                jsonEncode(<String, Object?>{'cover': notebookCover}),
              ),
              createdAt: createdAt,
              updatedAt: notebookUpdatedAt,
            ),
          );
      await db
          .into(db.diaryComments)
          .insert(
            DiaryCommentsCompanion.insert(
              commentId: 'c-1',
              diaryId: 'd-1',
              content: '评论内容',
              createdAt: createdAt,
              editedAt: Value<DateTime?>(commentEditedAt),
              images: Value<String?>(
                encodeDiaryCommentImages(<String>[commentImg]),
              ),
            ),
          );
      await db
          .into(db.aiMessages)
          .insert(
            AiMessagesCompanion.insert(
              messageId: 'm-1',
              conversationId: 'conv-1',
              role: 'user',
              images: Value<String?>(
                encodeAiMessageImages(<String>[kAiMessageImageRemoved, aiImg]),
              ),
              createdAt: createdAt,
            ),
          );
      final draftDoc = encodeDiaryBlocks(<String, Object?>{
        kDiaryBlocksDocumentKey: <String, Object?>{
          'type': kDiaryBlockPage,
          'children': <Object?>[
            <String, Object?>{
              'type': kDiaryBlockImage,
              'data': <String, Object?>{'url': draftImg},
            },
          ],
        },
      });
      await db
          .into(db.diaryDrafts)
          .insert(
            DiaryDraftsCompanion.insert(
              draftId: 'draft-1',
              contentText: const Value<String>('草稿'),
              payload: jsonEncode(<String, Object?>{
                'contentDocJson': draftDoc,
                'cover': draftCover,
              }),
              createdAt: createdAt,
              updatedAt: draftUpdatedAt,
            ),
          );
    } finally {
      await db.close();
    }

    final legacyDoc = encodeDiaryBlocks(<String, Object?>{
      kDiaryBlocksDocumentKey: <String, Object?>{
        'type': kDiaryBlockPage,
        'children': <Object?>[
          <String, Object?>{
            'type': kDiaryBlockImage,
            'data': <String, Object?>{'url': legacyDraftImg},
          },
        ],
      },
    });
    await settings.setCreateDiaryDraftRaw(
      jsonEncode(<String, Object?>{'contentDocJson': legacyDoc}),
    );

    return (
      diaryUpdatedAt: diaryUpdatedAt,
      notebookUpdatedAt: notebookUpdatedAt,
      commentEditedAt: commentEditedAt,
      draftUpdatedAt: draftUpdatedAt,
    );
  }

  test(
    'migrateData moves all managed files, preserves support preferences, rebinds paths without bumping timestamps, and cleans source',
    () async {
      final settings = await SettingsService.create();
      final prefsFile = File(p.join(supportDir.path, 'shared_preferences.json'))
        ..writeAsStringSync('{"theme":"light"}');
      final timestamps = await seedSourceDataset(sourceRoot, settings);

      final phases = <AppDataMigrationPhase>[];
      final result = await migrator.migrateData(
        sourceRoot: sourceRoot,
        targetRoot: targetRoot,
        supportDir: supportDir,
        settings: settings,
        onProgress: (AppDataMigrationProgress p) => phases.add(p.phase),
      );

      expect(p.normalize(result.targetRoot.path), p.normalize(targetRoot.path));
      expect(result.cleanupIncomplete, isFalse);
      expect(result.reboundRows, 5);
      expect(
        phases,
        containsAllInOrder(<AppDataMigrationPhase>[
          AppDataMigrationPhase.preparing,
          AppDataMigrationPhase.copying,
          AppDataMigrationPhase.rebinding,
          AppDataMigrationPhase.finalizing,
          AppDataMigrationPhase.cleaningUp,
        ]),
      );

      // Preferences and pointer stay in supportDir; managed source files removed.
      expect(prefsFile.existsSync(), isTrue);
      expect(
        File(p.join(supportDir.path, dataLocationConfigFileName)).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(sourceRoot.path, appDatabaseFileName)).existsSync(),
        isFalse,
      );
      expect(
        Directory(p.join(sourceRoot.path, 'diary_images')).existsSync(),
        isFalse,
      );
      expect(
        Directory(p.join(targetRoot.path, 'app_backgrounds')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(targetRoot.path, 'diary_fonts', 'custom.ttf')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(targetRoot.path, 'lan_sync', 'state.json')).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(targetRoot.path, 'cloud_backup_state', 'state.json'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(targetRoot.path, 'media_dedup_state', 'index.json'),
        ).existsSync(),
        isTrue,
      );
      expect(
        await store.readBoundRootMarker(targetRoot),
        p.normalize(targetRoot.path),
      );
      expect(
        p.normalize((await store.resolve()).activeRoot.path),
        p.normalize(targetRoot.path),
      );

      // Verify target database rebinding & preserved timestamps.
      final targetDb = AppDatabase.openFile(
        File(p.join(targetRoot.path, appDatabaseFileName)),
      );
      addTearDown(targetDb.close);

      final diary = await (targetDb.select(targetDb.diaries)).getSingle();
      expect(diary.updatedAt, timestamps.diaryUpdatedAt);
      expect(diary.cover, p.join(targetRoot.path, 'diary_covers', 'cover.jpg'));
      expect(
        diary.content,
        contains(p.join(targetRoot.path, 'diary_images', 'd1', 'photo.jpg')),
      );
      expect(
        diary.content,
        contains(p.join(targetRoot.path, 'diary_recordings', 'voice.m4a')),
      );
      expect(
        diary.content,
        contains(p.join(targetRoot.path, 'diary_videos', 'clip.mp4')),
      );
      expect(
        diary.content,
        contains(p.join(targetRoot.path, 'diary_attachments', 'doc.pdf')),
      );
      expect(diary.content, contains('/outside/external/picture.png'));

      final notebook = await targetDb.select(targetDb.notebooks).getSingle();
      expect(notebook.updatedAt, timestamps.notebookUpdatedAt);
      expect(
        (jsonDecode(notebook.payload) as Map<String, dynamic>)['cover'],
        p.join(targetRoot.path, 'diary_covers', 'nb.png'),
      );

      final comment = await targetDb.select(targetDb.diaryComments).getSingle();
      expect(comment.editedAt, timestamps.commentEditedAt);
      expect(decodeDiaryCommentImages(comment.images), <String>[
        p.join(targetRoot.path, 'diary_images', 'comment.jpg'),
      ]);

      final aiMessage = await targetDb.select(targetDb.aiMessages).getSingle();
      expect(decodeAiMessageImages(aiMessage.images), <String>[
        kAiMessageImageRemoved,
        p.join(targetRoot.path, 'diary_images', 'ai.jpg'),
      ]);

      final draft = await targetDb.select(targetDb.diaryDrafts).getSingle();
      expect(draft.updatedAt, timestamps.draftUpdatedAt);
      final draftJson = jsonDecode(draft.payload) as Map<String, dynamic>;
      expect(
        draftJson['cover'],
        p.join(targetRoot.path, 'diary_covers', 'draft_cover.jpg'),
      );
      expect(
        draftJson['contentDocJson'],
        contains(p.join(targetRoot.path, 'diary_images', 'draft.jpg')),
      );

      expect(
        settings.createDiaryDraftRaw,
        contains(p.join(targetRoot.path, 'diary_images', 'legacy.jpg')),
      );
    },
  );

  test(
    'migrateData rolls back copied target files when rebinding fails and preserves original source',
    () async {
      // Seed corrupt database file plus real image directory in sourceRoot.
      File(
        p.join(sourceRoot.path, appDatabaseFileName),
      ).writeAsStringSync('NOT_A_VALID_SQLITE_FILE');
      final sampleImg =
          File(p.join(sourceRoot.path, 'diary_images', 'keep.jpg'))
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(<int>[1, 2, 3]);

      await expectLater(
        () => migrator.migrateData(
          sourceRoot: sourceRoot,
          targetRoot: targetRoot,
          supportDir: supportDir,
        ),
        throwsA(anything),
      );

      expect(targetRoot.existsSync(), isFalse);
      expect(sampleImg.existsSync(), isTrue);
      expect(
        p.normalize((await store.resolve()).activeRoot.path),
        p.normalize(sourceRoot.path),
      );
    },
  );

  test(
    'switchToExistingData auto-rebinds externally moved folder using bound root marker',
    () async {
      final settings = await SettingsService.create();
      final externalOldDir = Directory(p.join(tempRoot.path, 'old_portable'))
        ..createSync();
      final timestamps = await seedSourceDataset(externalOldDir, settings);
      await store.writeBoundRootMarker(externalOldDir);

      // Simulate user renaming/moving the portable drive folder externally to targetRoot.
      externalOldDir.renameSync(targetRoot.path);
      final staleMarker = await store.readBoundRootMarker(targetRoot);
      expect(staleMarker, p.normalize(externalOldDir.path));

      final result = await migrator.switchToExistingData(
        sourceRoot: sourceRoot,
        targetRoot: targetRoot,
        supportDir: supportDir,
        settings: settings,
      );

      expect(result.reboundRows, 5);
      expect(
        await store.readBoundRootMarker(targetRoot),
        p.normalize(targetRoot.path),
      );
      expect(
        p.normalize((await store.resolve()).activeRoot.path),
        p.normalize(targetRoot.path),
      );

      final switchedDb = AppDatabase.openFile(
        File(p.join(targetRoot.path, appDatabaseFileName)),
      );
      addTearDown(switchedDb.close);
      final diary = await switchedDb.select(switchedDb.diaries).getSingle();
      expect(diary.updatedAt, timestamps.diaryUpdatedAt);
      expect(diary.cover, p.join(targetRoot.path, 'diary_covers', 'cover.jpg'));
    },
  );

  group('AppDataLocationBootstrapper', () {
    test(
      'completes installer pending migration on startup and clears pendingTargetPath',
      () async {
        final settings = await SettingsService.create();
        await seedSourceDataset(sourceRoot, settings);
        await store.saveUserConfig(
          supportDir: supportDir,
          targetPath: sourceRoot.path,
          pendingTargetPath: targetRoot.path,
        );

        final bootstrapper = AppDataLocationBootstrapper(
          store: store,
          migrator: migrator,
          settingsFactory: () async => settings,
        );
        expect(await bootstrapper.hasPendingStartupWork(), isTrue);

        final startup = await bootstrapper.prepareOnStartup();
        expect(startup.pendingMigrationFailed, isFalse);
        expect(startup.migratedToPath, p.normalize(targetRoot.path));

        final resolved = await store.resolve();
        expect(
          p.normalize(resolved.activeRoot.path),
          p.normalize(targetRoot.path),
        );
        expect(resolved.pendingTargetPath, isNull);
      },
    );

    test(
      'reports failure without losing original data and allows clearing pending target',
      () async {
        final settings = await SettingsService.create();
        await seedSourceDataset(sourceRoot, settings);

        final blockingDir = Directory(p.join(tempRoot.path, 'occupied'))
          ..createSync();
        File(
          p.join(blockingDir.path, 'unrelated.txt'),
        ).writeAsStringSync('keep');

        await store.saveUserConfig(
          supportDir: supportDir,
          targetPath: sourceRoot.path,
          pendingTargetPath: blockingDir.path,
        );

        final bootstrapper = AppDataLocationBootstrapper(
          store: store,
          migrator: migrator,
          settingsFactory: () async => settings,
        );
        final startup = await bootstrapper.prepareOnStartup();
        expect(startup.pendingMigrationFailed, isTrue);
        expect(startup.errorMessage, isNotNull);
        expect(
          File(p.join(sourceRoot.path, appDatabaseFileName)).existsSync(),
          isTrue,
        );

        await bootstrapper.clearPendingMigration();
        final resolved = await store.resolve();
        expect(resolved.pendingTargetPath, isNull);
        expect(
          p.normalize(resolved.activeRoot.path),
          p.normalize(sourceRoot.path),
        );
      },
    );
  });
}
