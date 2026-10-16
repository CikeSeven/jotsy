import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/controllers/publish_diary_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';

void main() {
  late AppDatabase database;
  late DiaryMetaDraftController meta;
  late DateTime now;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    meta = DiaryMetaDraftController();
    now = DateTime(2026, 10, 16, 9, 0);
  });
  tearDown(() async {
    meta.dispose();
    await database.close();
  });

  PublishDiaryController publisher({DateTime? requested}) =>
      PublishDiaryController(
        initialDraft: NewDiaryDraft(
          title: 'A walk',
          contentDocJson: '[{"insert":"A walk\\n"}]',
          contentText: 'A walk',
          createdAtOverride: requested,
        ),
        meta: meta,
        clock: () => now,
      );

  Future<Diary> stored(String id) async =>
      (await database.getDiaryWithTagsByDiaryId(id))!.diary;

  test('the diary is dated when publish is tapped, not when opened', () async {
    final controller = publisher();
    now = now.add(const Duration(minutes: 25));
    final id = await controller.submit(database);

    expect((await stored(id)).createdAt, DateTime(2026, 10, 16, 9, 25));
    expect(controller.phase.value, PublishPhase.done);
    expect(controller.canLeave, isFalse);
    controller.dispose();
  });

  test('a calendar day keeps the day and takes the publish time', () async {
    final controller = publisher(requested: DateTime(2026, 10, 10));
    final id = await controller.submit(database);
    expect((await stored(id)).createdAt, DateTime(2026, 10, 10, 9, 0));
    controller.dispose();
  });

  test('a capsule is dated by its unlock time and sealed now', () async {
    meta.setCapsule(
      TimeCapsuleSchedule(
        unlockAt: DateTime(2027, 1, 1, 18),
        precision: TimeCapsulePrecision.date,
      ),
    );
    meta.setMood('🙂');
    final controller = publisher();
    expect(controller.validate(), PublishValidation.ok);
    final id = await controller.submit(database);

    final diary = await stored(id);
    expect(diary.createdAt, DateTime(2027));
    expect(diary.capsuleUnlockAt, DateTime(2027));
    expect(diary.capsuleLockedAt, now);
    final metadata = jsonDecode(diary.metadata) as Map;
    expect((metadata['context'] as Map)['moodEmoji'], '🙂');
    expect((metadata['capsule'] as Map)['lockedAt'], now.toIso8601String());
    expect(controller.phase.value, PublishPhase.sealing);
    controller.dispose();
  });

  test('an expired capsule does not validate', () {
    meta.setCapsule(
      TimeCapsuleSchedule(
        unlockAt: DateTime(2026, 10, 16, 23),
        precision: TimeCapsulePrecision.date,
      ),
    );
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
    expect(controller.canLeave, isTrue);

    await database.customStatement('DROP TRIGGER reject_diary_insert');
    await controller.submit(database);
    expect(controller.phase.value, PublishPhase.done);
    controller.dispose();
  });

  test('publishing twice is refused', () async {
    final controller = publisher();
    final first = controller.submit(database);
    expect(() => controller.submit(database), throwsStateError);
    await first;
    expect(await database.select(database.diaries).get(), hasLength(1));
    controller.dispose();
  });

  group('return draft', () {
    test('carries the panel fields and no frozen publish time', () {
      meta.restore(const DiaryMetaDraft(moodEmoji: '🙂', tagIds: {4}));
      final controller = publisher();
      final draft = controller.returnDraft();
      expect(draft.createdAtOverride, isNull);
      expect(draft.moodEmoji, '🙂');
      expect(draft.selectedTagIds, {4});
      expect(draft.title, 'A walk');
      controller.dispose();
    });

    test('carries a picked time, ignores a confirmed one', () {
      final controller = publisher(requested: DateTime(2025, 3, 15, 10, 30));
      final shown = controller.effectivePublishAt;
      controller.applyPickedPublishAt(shown, shown: shown);
      expect(controller.returnDraft().createdAtOverride, shown);
      expect(controller.explicitPublishAt.value, isNull);

      final picked = DateTime(2025, 3, 10, 10, 30);
      controller.applyPickedPublishAt(picked, shown: shown);
      expect(controller.returnDraft().createdAtOverride, picked);
      expect(controller.effectivePublishAt, picked);
      controller.dispose();
    });
  });
}
