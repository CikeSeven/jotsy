import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:node_diary/ui/diaries/controllers/diary_day_photos_controller.dart';

import '../../../support/fake_day_photo_library.dart';

void main() {
  final day = DateTime(2026, 10, 12);
  final morning = DayPhoto(id: 'a', takenAt: DateTime(2026, 10, 12, 8, 30));
  final noon = DayPhoto(id: 'b', takenAt: DateTime(2026, 10, 12, 12, 5));
  final evening = DayPhoto(id: 'c', takenAt: DateTime(2026, 10, 12, 19, 40));

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('backfillDay', () {
    final now = DateTime(2026, 10, 17, 9);

    test('only days before today count as backfilling', () {
      expect(
        DiaryDayPhotosController.backfillDay(
          DateTime(2026, 10, 16, 23, 59),
          now: now,
        ),
        DateTime(2026, 10, 16),
      );
      expect(
        DiaryDayPhotosController.backfillDay(DateTime(2026, 10, 17), now: now),
        isNull,
      );
      expect(
        DiaryDayPhotosController.backfillDay(DateTime(2026, 11, 1), now: now),
        isNull,
      );
      expect(DiaryDayPhotosController.backfillDay(null, now: now), isNull);
    });
  });

  test('lists the day\'s photos when access is already granted', () async {
    final library = FakeDayPhotoLibrary(
      photosByDay: {
        day: [morning, noon],
      },
    );
    final controller = DiaryDayPhotosController(library: library);
    addTearDown(controller.dispose);

    controller.configure(day: DateTime(2026, 10, 12, 15, 20), enabled: true);
    // 读取中不显示，避免没照片的日子先闪出一块再消失。
    expect(controller.phase, DiaryDayPhotosPhase.hidden);
    await settle();

    expect(controller.phase, DiaryDayPhotosPhase.ready);
    expect(controller.photos, [morning, noon]);
    expect(library.queriedDays, [day]);
    expect(library.requestCount, 0);
  });

  test('a day without photos stays hidden', () async {
    final library = FakeDayPhotoLibrary();
    final controller = DiaryDayPhotosController(library: library);
    addTearDown(controller.dispose);

    controller.configure(day: day, enabled: true);
    await settle();

    expect(controller.phase, DiaryDayPhotosPhase.hidden);
    expect(library.queriedDays, [day]);
  });

  test('never queries when disabled or unsupported', () async {
    final library = FakeDayPhotoLibrary(
      photosByDay: {
        day: [morning],
      },
    );
    final disabled = DiaryDayPhotosController(library: library);
    addTearDown(disabled.dispose);
    disabled.configure(day: day, enabled: false);

    final unsupported = DiaryDayPhotosController(
      library: FakeDayPhotoLibrary(isSupported: false),
    );
    addTearDown(unsupported.dispose);
    unsupported.configure(day: day, enabled: true);
    await settle();

    expect(disabled.phase, DiaryDayPhotosPhase.hidden);
    expect(unsupported.phase, DiaryDayPhotosPhase.hidden);
    expect(library.checkCount, 0);
  });

  test(
    'asks for access only on tap, then opens settings after a denial',
    () async {
      final library = FakeDayPhotoLibrary(
        access: DayPhotoAccess.denied,
        accessAfterRequest: DayPhotoAccess.denied,
        photosByDay: {
          day: [morning],
        },
      );
      final controller = DiaryDayPhotosController(library: library);
      addTearDown(controller.dispose);

      controller.configure(day: day, enabled: true);
      await settle();
      expect(controller.phase, DiaryDayPhotosPhase.needsAccess);
      expect(controller.shouldOpenSettings, isFalse);
      expect(library.requestCount, 0);

      await controller.requestAccess();
      expect(library.requestCount, 1);
      expect(controller.phase, DiaryDayPhotosPhase.needsAccess);
      expect(controller.shouldOpenSettings, isTrue);

      // 再点一次：不再弹框（Android 拒绝后不会再出现），改去系统设置。
      await controller.requestAccess();
      expect(library.requestCount, 1);
      expect(library.openSettingsCount, 1);

      // 用户在设置里打开权限后回到应用。
      library.access = DayPhotoAccess.limited;
      controller.refresh();
      await settle();
      expect(controller.phase, DiaryDayPhotosPhase.ready);
      expect(controller.isLimited, isTrue);
    },
  );

  test('granting access loads the photos right away', () async {
    final library = FakeDayPhotoLibrary(
      access: DayPhotoAccess.denied,
      photosByDay: {
        day: [morning],
      },
    );
    final controller = DiaryDayPhotosController(library: library);
    addTearDown(controller.dispose);
    controller.configure(day: day, enabled: true);
    await settle();

    await controller.requestAccess();

    expect(controller.phase, DiaryDayPhotosPhase.ready);
    expect(controller.photos, [morning]);
  });

  test('a result for a previous day is discarded', () async {
    final otherDay = DateTime(2026, 10, 13);
    final slow = Completer<List<DayPhoto>>();
    final library = FakeDayPhotoLibrary(
      photosByDay: {
        otherDay: [evening],
      },
    )..pendingQueries[day] = slow;
    final controller = DiaryDayPhotosController(library: library);
    addTearDown(controller.dispose);

    controller.configure(day: day, enabled: true);
    await settle();
    controller.configure(day: otherDay, enabled: true);
    await settle();
    slow.complete([morning, noon]);
    await settle();

    expect(controller.day, otherDay);
    expect(controller.photos, [evening]);
  });

  test('selection follows the day order and inserted photos lock', () async {
    final library = FakeDayPhotoLibrary(
      photosByDay: {
        day: [morning, noon, evening],
      },
    );
    final controller = DiaryDayPhotosController(library: library);
    addTearDown(controller.dispose);
    controller.configure(day: day, enabled: true);
    await settle();

    controller
      ..toggle(evening)
      ..toggle(morning);
    expect(controller.selectedPhotos, [morning, evening]);

    controller.markInserted([morning, evening]);
    expect(controller.selectedCount, 0);
    expect(controller.isInserted(morning), isTrue);

    // 已插入的照片点按无效，不会被插第二次。
    controller.toggle(morning);
    expect(controller.selectedCount, 0);

    controller.toggle(noon);
    controller.clearSelection();
    expect(controller.selectedCount, 0);
  });

  test('changing the day clears the selection', () async {
    final otherDay = DateTime(2026, 10, 13);
    final library = FakeDayPhotoLibrary(
      photosByDay: {
        day: [morning],
        otherDay: [evening],
      },
    );
    final controller = DiaryDayPhotosController(library: library);
    addTearDown(controller.dispose);
    controller.configure(day: day, enabled: true);
    await settle();
    controller.toggle(morning);

    controller.configure(day: otherDay, enabled: true);
    await settle();

    expect(controller.selectedCount, 0);
    expect(controller.photos, [evening]);
  });

  test('a failing query hides the strip instead of throwing', () async {
    final library = FakeDayPhotoLibrary()..queryError = StateError('boom');
    final controller = DiaryDayPhotosController(library: library);
    addTearDown(controller.dispose);

    controller.configure(day: day, enabled: true);
    await settle();

    expect(controller.phase, DiaryDayPhotosPhase.hidden);
  });

  test('dismissing hides the strip and ignores later refreshes', () async {
    final library = FakeDayPhotoLibrary(
      photosByDay: {
        day: [morning],
      },
    );
    final controller = DiaryDayPhotosController(library: library);
    addTearDown(controller.dispose);
    controller.configure(day: day, enabled: true);
    await settle();

    controller.dismiss();
    controller.refresh();
    await settle();

    expect(controller.phase, DiaryDayPhotosPhase.hidden);
    expect(library.queriedDays, [day]);
  });

  test('the cover badge follows the draft cover', () async {
    final library = FakeDayPhotoLibrary(
      photosByDay: {
        day: [morning, noon],
      },
    );
    final controller = DiaryDayPhotosController(library: library);
    addTearDown(controller.dispose);
    controller.configure(day: day, enabled: true);
    await settle();

    controller.toggle(noon);
    expect(controller.singleSelection, noon);
    controller.toggle(morning);
    expect(controller.singleSelection, isNull);

    controller.markCover(noon, '/covers/noon.jpg');
    expect(controller.isCover(noon), isTrue);
    expect(controller.isCover(morning), isFalse);

    // 草稿还是这张封面：角标不动。
    controller.syncCover('/covers/noon.jpg');
    expect(controller.isCover(noon), isTrue);

    // 发布页换了别的封面或清除了封面：角标消失。
    controller.syncCover('/covers/other.jpg');
    expect(controller.isCover(noon), isFalse);
    controller.markCover(noon, '/covers/noon.jpg');
    controller.syncCover(null);
    expect(controller.isCover(noon), isFalse);
  });

  test('dayPhotoRange covers exactly one local calendar day', () {
    final range = dayPhotoRange(DateTime(2026, 12, 31, 18, 45));
    expect(range.start, DateTime(2026, 12, 31));
    expect(range.end, DateTime(2027, 1, 1));
  });
}
