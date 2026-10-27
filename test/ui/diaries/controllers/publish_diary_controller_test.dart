import 'dart:convert';
import 'dart:ui' show AppExitResponse;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/controllers/publish_diary_controller.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late DiaryMetaDraftController meta;
  late DateTime now;
  late List<Object> saveErrors;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    meta = DiaryMetaDraftController();
    now = DateTime(2026, 10, 16, 9, 0);
    saveErrors = <Object>[];
  });
  tearDown(() async {
    meta.dispose();
    await database.close();
  });

  PublishDiaryController publisher({
    DateTime? requested,
    Duration debounce = const Duration(milliseconds: 500),
  }) => PublishDiaryController(
    initialDraft: NewDiaryDraft(
      title: 'A walk',
      contentDocJson: '[{"insert":"A walk\\n"}]',
      contentText: 'A walk',
      createdAtOverride: requested,
    ),
    meta: meta,
    clock: () => now,
    onSaveError: saveErrors.add,
    autoSaveDebounce: debounce,
  );

  Future<Diary> stored(String id) async =>
      (await database.getDiaryWithTagsByDiaryId(id))!.diary;

  Map<Object?, Object?> metadataOf(Diary diary) =>
      jsonDecode(diary.metadata) as Map<Object?, Object?>;

  TimeCapsuleSchedule capsuleOn(DateTime day) =>
      TimeCapsuleSchedule(unlockAt: day, precision: TimeCapsulePrecision.date);

  Future<void> rejectDiaryUpdates() => database.customStatement('''
    CREATE TRIGGER reject_diary_update BEFORE UPDATE ON diaries
    BEGIN SELECT RAISE(ABORT, 'disk unavailable'); END;
  ''');

  group('publishing on entry', () {
    test('the diary is dated when it is written', () async {
      final controller = publisher();
      now = now.add(const Duration(minutes: 25));
      final id = await controller.submit(database);

      expect((await stored(id)).createdAt, DateTime(2026, 10, 16, 9, 25));
      expect(controller.diaryId, id);
      expect(controller.phase.value, PublishPhase.published);
      expect(controller.canLeave, isTrue);
      controller.dispose();
    });

    test('a calendar day keeps the day and takes the publish time', () async {
      final controller = publisher(requested: DateTime(2026, 10, 10));
      final id = await controller.submit(database);
      expect((await stored(id)).createdAt, DateTime(2026, 10, 10, 9, 0));
      controller.dispose();
    });

    test('the publish time shown afterwards is the written one', () async {
      final controller = publisher();
      await controller.submit(database);
      now = now.add(const Duration(hours: 2));
      expect(controller.effectivePublishAt, DateTime(2026, 10, 16, 9, 0));
      controller.dispose();
    });

    test('a capsule is dated by its unlock time and sealed now', () async {
      meta.setCapsule(capsuleOn(DateTime(2027, 1, 1, 18)));
      meta.setMood('🙂');
      final controller = publisher();
      expect(controller.validate(), PublishValidation.ok);
      final id = await controller.submit(database);

      final diary = await stored(id);
      expect(diary.createdAt, DateTime(2027));
      expect(diary.capsuleUnlockAt, DateTime(2027));
      expect(diary.capsuleLockedAt, now);
      final metadata = metadataOf(diary);
      expect((metadata['context'] as Map)['moodEmoji'], '🙂');
      expect((metadata['capsule'] as Map)['lockedAt'], now.toIso8601String());
      // 封存卡片在返回时才播放。
      expect(controller.phase.value, PublishPhase.published);
      controller.dispose();
    });

    test('an expired capsule does not validate', () {
      meta.setCapsule(capsuleOn(DateTime(2026, 10, 16, 23)));
      final controller = publisher();
      expect(controller.validate(), PublishValidation.capsuleUnlockPassed);
      controller.dispose();
    });

    test('a failed write returns to idle and can be retried', () async {
      await database.customStatement('''
        CREATE TRIGGER reject_diary_insert BEFORE INSERT ON diaries
        BEGIN SELECT RAISE(ABORT, 'disk unavailable'); END;
      ''');
      final controller = publisher();
      await expectLater(controller.submit(database), throwsA(anything));
      expect(controller.phase.value, PublishPhase.idle);
      expect(controller.canLeave, isFalse);
      expect(controller.diaryId, isNull);

      await database.customStatement('DROP TRIGGER reject_diary_insert');
      await controller.submit(database);
      expect(controller.phase.value, PublishPhase.published);
      controller.dispose();
    });

    test('publishing twice is refused', () async {
      final controller = publisher();
      final first = controller.submit(database);
      expect(() => controller.submit(database), throwsStateError);
      await first;
      expect(() => controller.submit(database), throwsStateError);
      expect(await database.select(database.diaries).get(), hasLength(1));
      controller.dispose();
    });

    test('nothing can be left before the diary is written', () async {
      final controller = publisher();
      expect(controller.canLeave, isFalse);
      expect(await controller.finish(), isFalse);
      // 写库前补存不做任何事。
      expect(await controller.flush(), isTrue);
      expect(await database.select(database.diaries).get(), isEmpty);
      controller.dispose();
    });
  });

  group('editing after publishing', () {
    test('panel changes are saved after the debounce', () async {
      final controller = publisher(debounce: const Duration(milliseconds: 1));
      final id = await controller.submit(database);
      final tagId = await database.createTag(name: 'Life', color: 0xff2196f3);

      meta.setMood('🙂');
      meta.setTagSelected(tagId, true);
      meta.setCover('/covers/a.jpg');
      var diary = await stored(id);
      for (var i = 0; i < 50 && diary.cover == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        diary = await stored(id);
      }

      expect(diary.cover, '/covers/a.jpg');
      expect((metadataOf(diary)['context'] as Map)['moodEmoji'], '🙂');
      final row = await database.getDiaryWithTagsByDiaryId(id);
      expect(row!.tags.map((tag) => tag.id), [tagId]);
      // 标题与正文就是发表时的那份。
      expect(diary.title, 'A walk');
      expect(diary.contentText, 'A walk');
      expect(saveErrors, isEmpty);
      controller.dispose();
    });

    test('flush writes pending changes right away', () async {
      final controller = publisher();
      final id = await controller.submit(database);
      meta.setMood('😴');
      expect(await controller.flush(), isTrue);
      expect(
        (metadataOf(await stored(id))['context'] as Map)['moodEmoji'],
        '😴',
      );
      controller.dispose();
    });

    test('a picked publish time is saved, a confirmed one is not', () async {
      final controller = publisher(requested: DateTime(2025, 3, 15, 10, 30));
      final id = await controller.submit(database);
      final shown = controller.effectivePublishAt;
      final before = (await stored(id)).updatedAt;

      controller.applyPickedPublishAt(shown, shown: shown);
      expect(controller.explicitPublishAt.value, isNull);
      await controller.flush();
      expect((await stored(id)).updatedAt, before);

      final picked = DateTime(2025, 3, 10, 10, 30);
      controller.applyPickedPublishAt(picked, shown: shown);
      await controller.flush();
      expect((await stored(id)).createdAt, picked);
      expect(controller.effectivePublishAt, picked);
      controller.dispose();
    });

    test(
      'setting a capsule seals the diary, clearing it restores the date',
      () async {
        final controller = publisher();
        final id = await controller.submit(database);

        now = DateTime(2026, 10, 16, 9, 5);
        meta.setCapsule(capsuleOn(DateTime(2027, 2, 1)));
        await controller.flush();
        var diary = await stored(id);
        expect(diary.capsuleUnlockAt, DateTime(2027, 2, 1));
        expect(diary.capsuleLockedAt, DateTime(2026, 10, 16, 9, 5));
        expect(diary.createdAt, DateTime(2027, 2, 1));
        expect(
          (metadataOf(diary)['capsule'] as Map)['unlockAt'],
          DateTime(2027, 2, 1).toIso8601String(),
        );

        // 改解封日不改封存时刻。
        now = DateTime(2026, 10, 16, 9, 8);
        meta.setCapsule(capsuleOn(DateTime(2027, 3, 1)));
        await controller.flush();
        diary = await stored(id);
        expect(diary.capsuleUnlockAt, DateTime(2027, 3, 1));
        expect(diary.capsuleLockedAt, DateTime(2026, 10, 16, 9, 5));

        meta.setCapsule(null);
        await controller.flush();
        diary = await stored(id);
        expect(diary.capsuleUnlockAt, isNull);
        expect(diary.capsuleLockedAt, isNull);
        expect(diary.createdAt, DateTime(2026, 10, 16, 9, 0));
        expect(metadataOf(diary).containsKey('capsule'), isFalse);
        controller.dispose();
      },
    );

    test('a failed save is reported and retried on the next flush', () async {
      final controller = publisher();
      final id = await controller.submit(database);
      await rejectDiaryUpdates();

      meta.setMood('🙂');
      expect(await controller.flush(), isFalse);
      expect(saveErrors, hasLength(1));

      await database.customStatement('DROP TRIGGER reject_diary_update');
      expect(await controller.flush(), isTrue);
      expect(
        (metadataOf(await stored(id))['context'] as Map)['moodEmoji'],
        '🙂',
      );
      controller.dispose();
    });
  });

  group('leaving', () {
    test(
      'desktop closing saves the last published metadata before exiting',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final controller = publisher();
        addTearDown(controller.dispose);
        final id = await controller.submit(database);
        meta.setMood('🙂');
        expect(await binding.handleRequestAppExit(), AppExitResponse.exit);
        expect(
          (metadataOf(await stored(id))['context'] as Map)['moodEmoji'],
          '🙂',
        );
        expect(controller.phase.value, PublishPhase.published);
      },
    );

    test(
      'desktop closing is cancelled if published metadata cannot be saved',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final controller = publisher();
        addTearDown(controller.dispose);
        final id = await controller.submit(database);
        await rejectDiaryUpdates();
        meta.setMood('🙂');
        expect(await binding.handleRequestAppExit(), AppExitResponse.cancel);
        expect(saveErrors, hasLength(1));
        await database.customStatement('DROP TRIGGER reject_diary_update');
        expect(await binding.handleRequestAppExit(), AppExitResponse.exit);
        expect(
          (metadataOf(await stored(id))['context'] as Map)['moodEmoji'],
          '🙂',
        );
      },
    );

    test('a plain diary saves and leaves', () async {
      final controller = publisher();
      final id = await controller.submit(database);
      meta.setMood('🙂');

      expect(await controller.finish(), isTrue);
      expect(controller.phase.value, PublishPhase.done);
      expect(controller.canLeave, isFalse);
      expect(
        (metadataOf(await stored(id))['context'] as Map)['moodEmoji'],
        '🙂',
      );
      controller.dispose();
    });

    test('a locked capsule plays the seal before leaving', () async {
      final controller = publisher();
      await controller.submit(database);
      meta.setCapsule(capsuleOn(DateTime(2027)));

      expect(await controller.finish(), isTrue);
      expect(controller.phase.value, PublishPhase.sealing);
      controller.dispose();
    });

    test('a failed save keeps the page open', () async {
      final controller = publisher();
      await controller.submit(database);
      await rejectDiaryUpdates();
      meta.setMood('🙂');

      expect(await controller.finish(), isFalse);
      expect(controller.phase.value, PublishPhase.published);
      expect(controller.canLeave, isTrue);
      expect(saveErrors, hasLength(1));
      controller.dispose();
    });
  });
}
