import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:node_diary/core/services/day_photo_library_photo_manager.dart';
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

    controller.configure(day: DateTime(2026, 10, 12, 15, 20), autoShow: true);
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

    controller.configure(day: day, autoShow: true);
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
    disabled.configure(day: day, autoShow: false);

    final unsupported = DiaryDayPhotosController(
      library: FakeDayPhotoLibrary(isSupported: false),
    );
    addTearDown(unsupported.dispose);
    unsupported.configure(day: day, autoShow: true);
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

      controller.configure(day: day, autoShow: true);
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
    controller.configure(day: day, autoShow: true);
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

    controller.configure(day: day, autoShow: true);
    await settle();
    controller.configure(day: otherDay, autoShow: true);
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
    controller.configure(day: day, autoShow: true);
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
    controller.configure(day: day, autoShow: true);
    await settle();
    controller.toggle(morning);

    controller.configure(day: otherDay, autoShow: true);
    await settle();

    expect(controller.selectedCount, 0);
    expect(controller.photos, [evening]);
  });

  test('a failing query hides the strip instead of throwing', () async {
    final library = FakeDayPhotoLibrary()..queryError = StateError('boom');
    final controller = DiaryDayPhotosController(library: library);
    addTearDown(controller.dispose);

    controller.configure(day: day, autoShow: true);
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
    controller.configure(day: day, autoShow: true);
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
    controller.configure(day: day, autoShow: true);
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

  group('diaryDay', () {
    final now = DateTime(2026, 10, 17, 9);

    test('today and earlier days can be browsed, future days cannot', () {
      expect(
        DiaryDayPhotosController.diaryDay(
          DateTime(2026, 10, 17, 23, 30),
          now: now,
        ),
        DateTime(2026, 10, 17),
      );
      expect(
        DiaryDayPhotosController.diaryDay(DateTime(2026, 3, 2, 7), now: now),
        DateTime(2026, 3, 2),
      );
      expect(
        DiaryDayPhotosController.diaryDay(DateTime(2026, 10, 18), now: now),
        isNull,
      );
      expect(DiaryDayPhotosController.diaryDay(null, now: now), isNull);
    });
  });

  group('browsing from the menu', () {
    test('loads the day even when the strip does not auto-show', () async {
      final library = FakeDayPhotoLibrary(
        photosByDay: {
          day: [morning, noon],
        },
      );
      final controller = DiaryDayPhotosController(library: library);
      addTearDown(controller.dispose);

      controller.configure(day: day, autoShow: false);
      await settle();
      expect(library.checkCount, 0);
      expect(controller.canBrowse, isTrue);

      controller.browse();
      expect(controller.sheetPhase, DiaryDayPhotosSheetPhase.loading);
      await settle();

      expect(controller.sheetPhase, DiaryDayPhotosSheetPhase.ready);
      expect(controller.photos, [morning, noon]);
      // 提示条仍不自动出现：开关只管它。
      expect(controller.phase, DiaryDayPhotosPhase.hidden);
    });

    test('still loads after the strip was dismissed', () async {
      final library = FakeDayPhotoLibrary(
        photosByDay: {
          day: [morning],
        },
      );
      final controller = DiaryDayPhotosController(library: library);
      addTearDown(controller.dispose);
      controller.configure(day: day, autoShow: true);
      controller.dismiss();
      await settle();
      expect(controller.photos, isEmpty);

      controller.browse();
      await settle();

      expect(controller.sheetPhase, DiaryDayPhotosSheetPhase.ready);
      expect(controller.photos, [morning]);
      expect(controller.phase, DiaryDayPhotosPhase.hidden);
    });

    test('dismissing the strip does not cancel a browse in flight', () async {
      final slow = Completer<List<DayPhoto>>();
      final library = FakeDayPhotoLibrary()..pendingQueries[day] = slow;
      final controller = DiaryDayPhotosController(library: library);
      addTearDown(controller.dispose);
      controller.configure(day: day, autoShow: true);
      controller.browse();
      await settle();

      controller.dismiss();
      slow.complete([evening]);
      await settle();

      expect(controller.photos, [evening]);
      expect(controller.sheetPhase, DiaryDayPhotosSheetPhase.ready);
    });

    test('never asks for permission, only checks it', () async {
      final library = FakeDayPhotoLibrary(access: DayPhotoAccess.denied);
      final controller = DiaryDayPhotosController(library: library);
      addTearDown(controller.dispose);
      controller.configure(day: day, autoShow: false);

      controller.browse();
      expect(controller.sheetPhase, DiaryDayPhotosSheetPhase.loading);
      await settle();

      expect(controller.sheetPhase, DiaryDayPhotosSheetPhase.needsAccess);
      expect(library.checkCount, 1);
      expect(library.requestCount, 0);
      expect(library.queriedDays, isEmpty);
    });

    test('a day without photos ends in the empty state', () async {
      final library = FakeDayPhotoLibrary(access: DayPhotoAccess.limited);
      final controller = DiaryDayPhotosController(library: library);
      addTearDown(controller.dispose);
      controller.configure(day: day, autoShow: false);

      controller.browse();
      await settle();

      expect(controller.sheetPhase, DiaryDayPhotosSheetPhase.empty);
      expect(controller.isLimited, isTrue);
    });

    test('a failing query ends in the empty state', () async {
      final library = FakeDayPhotoLibrary()..queryError = StateError('boom');
      final controller = DiaryDayPhotosController(library: library);
      addTearDown(controller.dispose);
      controller.configure(day: day, autoShow: false);

      controller.browse();
      await settle();

      expect(controller.sheetPhase, DiaryDayPhotosSheetPhase.empty);
    });

    test('granting access from the sheet loads the photos', () async {
      final library = FakeDayPhotoLibrary(
        access: DayPhotoAccess.denied,
        photosByDay: {
          day: [noon],
        },
      );
      final controller = DiaryDayPhotosController(library: library);
      addTearDown(controller.dispose);
      controller.configure(day: day, autoShow: false);
      controller.browse();
      await settle();

      await controller.requestAccess();

      expect(library.requestCount, 1);
      expect(controller.sheetPhase, DiaryDayPhotosSheetPhase.ready);
      expect(controller.photos, [noon]);
    });

    test(
      'a result for the previous day is discarded after a day change',
      () async {
        final otherDay = DateTime(2026, 10, 13);
        final slow = Completer<List<DayPhoto>>();
        final library = FakeDayPhotoLibrary(
          photosByDay: {
            otherDay: [evening],
          },
        )..pendingQueries[day] = slow;
        final controller = DiaryDayPhotosController(library: library);
        addTearDown(controller.dispose);
        controller.configure(day: day, autoShow: false);
        controller.browse();
        await settle();

        controller.configure(day: otherDay, autoShow: false);
        slow.complete([morning]);
        await settle();
        expect(controller.photos, isEmpty);
        // 换了日期，“打开过面板”随之清掉：不自动读取新的一天。
        expect(library.queriedDays, [day]);

        controller.browse();
        await settle();
        expect(controller.day, otherDay);
        expect(controller.photos, [evening]);
      },
    );

    test('refresh reloads while browsing', () async {
      final library = FakeDayPhotoLibrary(
        access: DayPhotoAccess.denied,
        photosByDay: {
          day: [morning],
        },
      );
      final controller = DiaryDayPhotosController(library: library);
      addTearDown(controller.dispose);
      controller.configure(day: day, autoShow: false);
      controller.browse();
      await settle();
      expect(controller.sheetPhase, DiaryDayPhotosSheetPhase.needsAccess);

      // 面板开着时去系统设置开了权限，回到应用。
      library.access = DayPhotoAccess.granted;
      controller.refresh();
      await settle();

      expect(controller.sheetPhase, DiaryDayPhotosSheetPhase.ready);
      expect(library.requestCount, 0);
    });

    test(
      'refresh does nothing when neither auto-showing nor browsing',
      () async {
        final library = FakeDayPhotoLibrary(
          photosByDay: {
            day: [morning],
          },
        );
        final controller = DiaryDayPhotosController(library: library);
        addTearDown(controller.dispose);
        controller.configure(day: day, autoShow: false);

        controller.refresh();
        await settle();

        expect(library.checkCount, 0);
        expect(controller.photos, isEmpty);
      },
    );

    test('cannot browse without a day or on unsupported platforms', () {
      final noDay = DiaryDayPhotosController(library: FakeDayPhotoLibrary());
      addTearDown(noDay.dispose);
      noDay.configure(day: null, autoShow: false);
      expect(noDay.canBrowse, isFalse);

      final library = FakeDayPhotoLibrary(isSupported: false);
      final unsupported = DiaryDayPhotosController(library: library);
      addTearDown(unsupported.dispose);
      unsupported.configure(day: day, autoShow: false);
      unsupported.browse();
      expect(unsupported.canBrowse, isFalse);
      expect(library.checkCount, 0);
    });
  });

  test('dayPhotoRange covers exactly one local calendar day', () {
    final range = dayPhotoRange(DateTime(2026, 12, 31, 18, 45));
    expect(range.start, DateTime(2026, 12, 31));
    expect(range.end, DateTime(2027, 1, 1));
  });

  group('videos', () {
    final clip = DayPhoto(
      id: 'v',
      takenAt: DateTime(2026, 10, 12, 10),
      isVideo: true,
      duration: const Duration(seconds: 42),
    );

    test('combineDayPhotoAccess merges image and video access', () {
      DayPhotoAccess combine(DayPhotoAccess images, DayPhotoAccess videos) =>
          combineDayPhotoAccess(images: images, videos: videos);
      const granted = DayPhotoAccess.granted;
      const limited = DayPhotoAccess.limited;
      const denied = DayPhotoAccess.denied;
      expect(combine(granted, granted), granted);
      expect(combine(limited, limited), limited);
      expect(combine(denied, denied), denied);
      // Android 13+ 升级上来、只授权过图片。
      expect(combine(granted, denied), DayPhotoAccess.imagesOnly);
      expect(combine(granted, limited), limited);
      expect(combine(limited, denied), limited);
      expect(combine(denied, granted), limited);
      expect(DayPhotoAccess.imagesOnly.canRead, isTrue);
      expect(DayPhotoAccess.imagesOnly.canReadVideos, isFalse);
      expect(DayPhotoAccess.limited.canReadVideos, isTrue);
    });

    test('lists videos with photos and counts them', () async {
      final library = FakeDayPhotoLibrary(
        photosByDay: {
          day: [morning, clip, noon],
        },
      );
      final controller = DiaryDayPhotosController(library: library);
      addTearDown(controller.dispose);

      controller.configure(day: day, autoShow: true);
      await settle();

      expect(controller.photos, [morning, clip, noon]);
      expect(controller.videoCount, 1);
      expect(library.queriedWithVideos, [true]);
      expect(controller.needsVideoAccess, isFalse);

      controller.toggle(morning);
      expect(controller.selectionHasVideo, isFalse);
      controller.toggle(clip);
      expect(controller.selectionHasVideo, isTrue);
      expect(controller.selectedPhotos, [morning, clip]);
    });

    test('with image access only, videos are skipped until allowed', () async {
      final library = FakeDayPhotoLibrary(
        access: DayPhotoAccess.imagesOnly,
        photosByDay: {
          day: [morning, clip, noon],
        },
      );
      final controller = DiaryDayPhotosController(library: library);
      addTearDown(controller.dispose);

      controller.configure(day: day, autoShow: true);
      await settle();

      expect(controller.phase, DiaryDayPhotosPhase.ready);
      expect(controller.photos, [morning, noon]);
      expect(controller.needsVideoAccess, isTrue);
      expect(controller.isLimited, isFalse);
      expect(library.queriedWithVideos, [false]);
      expect(library.requestCount, 0);

      await controller.requestAccess();
      await settle();

      expect(library.requestCount, 1);
      expect(controller.needsVideoAccess, isFalse);
      expect(controller.photos, [morning, clip, noon]);
      expect(library.queriedWithVideos.last, isTrue);
    });

    test('declining videos again turns the button into settings', () async {
      final library = FakeDayPhotoLibrary(
        access: DayPhotoAccess.imagesOnly,
        accessAfterRequest: DayPhotoAccess.imagesOnly,
        photosByDay: {
          day: [morning, clip],
        },
      );
      final controller = DiaryDayPhotosController(library: library);
      addTearDown(controller.dispose);

      controller.configure(day: day, autoShow: true);
      await settle();
      expect(controller.shouldOpenSettings, isFalse);

      await controller.requestAccess();
      await settle();
      expect(controller.needsVideoAccess, isTrue);
      expect(controller.shouldOpenSettings, isTrue);
      // 照片仍在，没有因为拒绝视频而清空。
      expect(controller.photos, [morning]);

      await controller.requestAccess();
      expect(library.requestCount, 1);
      expect(library.openSettingsCount, 1);
    });

    test('a video never becomes the cover', () async {
      final library = FakeDayPhotoLibrary(
        photosByDay: {
          day: [clip],
        },
      );
      final controller = DiaryDayPhotosController(library: library);
      addTearDown(controller.dispose);
      controller.configure(day: day, autoShow: true);
      await settle();

      controller.markCover(clip, '/covers/clip.jpg');
      expect(controller.isCover(clip), isFalse);
    });

    test('items no longer listed cannot be selected', () async {
      final library = FakeDayPhotoLibrary(
        photosByDay: {
          day: [morning],
        },
      );
      final controller = DiaryDayPhotosController(library: library);
      addTearDown(controller.dispose);
      controller.configure(day: day, autoShow: true);
      await settle();

      // 预览页翻的是打开时的列表；重新读取后不在列表里的不再勾选。
      controller.toggle(evening);
      expect(controller.selectedCount, 0);
      controller.toggle(morning);
      expect(controller.selectedCount, 1);
    });
  });

  group('dayPhotoPreviewSize', () {
    test('keeps the aspect ratio and caps the longer side', () {
      final size = dayPhotoPreviewSize(
        DayPhoto(id: 'p', takenAt: day, width: 6000, height: 4000),
        3000,
      );
      expect(size.width, 3000);
      expect(size.height, 2000);
    });

    test('never upscales and handles unknown sizes', () {
      final small = dayPhotoPreviewSize(
        DayPhoto(id: 's', takenAt: day, width: 800, height: 1200),
        3000,
      );
      expect((small.width, small.height), (800, 1200));
      final unknown = dayPhotoPreviewSize(
        DayPhoto(id: 'u', takenAt: day),
        3000,
      );
      expect((unknown.width, unknown.height), (3000, 3000));
    });

    test('a very long screenshot keeps at least one pixel of width', () {
      final size = dayPhotoPreviewSize(
        DayPhoto(id: 'l', takenAt: day, width: 1, height: 90000),
        3000,
      );
      expect(size.width, 1);
      expect(size.height, 3000);
    });
  });
}
