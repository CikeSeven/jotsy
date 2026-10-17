import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_day_photos/diary_day_photo_tile.dart';
import 'package:node_diary/ui/diaries/widgets/diary_day_photos/diary_day_photos_sheet.dart';
import 'package:node_diary/ui/diaries/widgets/diary_day_photos/diary_day_photos_strip.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_day_photo_library.dart';

/// 补写过去某天：编辑页列出相册里这天拍的照片，勾选后插入正文。
void main() {
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  late Directory appRoot;
  late Directory gallery;
  late SettingsService settings;

  setUp(() async {
    appRoot = await Directory.systemTemp.createTemp('jotsy_day_photos_app_');
    gallery = await Directory.systemTemp.createTemp('jotsy_day_photos_dcim_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (_) async => appRoot.path);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
    await appRoot.delete(recursive: true);
    await gallery.delete(recursive: true);
  });

  final now = DateTime.now();
  final backfillDay = DateTime(now.year, now.month, now.day - 3);
  final breakfast = DayPhoto(
    id: 'breakfast',
    takenAt: backfillDay.add(const Duration(hours: 8)),
  );
  final hike = DayPhoto(
    id: 'hike',
    takenAt: backfillDay.add(const Duration(hours: 14)),
  );

  /// 相册原图是真实文件：在 testWidgets 里须经 runAsync 写入，假时钟下
  /// 文件 IO 的 Future 不会完成。
  Future<FakeDayPhotoLibrary> galleryLibrary(
    WidgetTester tester, {
    DayPhotoAccess access = DayPhotoAccess.granted,
  }) async {
    final library = FakeDayPhotoLibrary(
      access: access,
      photosByDay: {
        backfillDay: [breakfast, hike],
      },
    );
    await tester.runAsync(() async {
      for (final photo in [breakfast, hike]) {
        final file = File(p.join(gallery.path, '${photo.id}.png'));
        await file.writeAsBytes(kTinyPng);
        library.files[photo.id] = file;
      }
    });
    return library;
  }

  Future<AppLocalizations> openEditor(
    WidgetTester tester, {
    required DayPhotoLibrary library,
    DateTime? createDate,
    bool suggestionsEnabled = true,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    settings = await SettingsService.create();
    await settings.setDayPhotoSuggestionsEnabled(suggestionsEnabled);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
          dayPhotoLibraryProvider.overrideWithValue(library),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: EditDiaryPage(
            entryMode: EditDiaryEntryMode.create,
            restoreCreateDraft: false,
            createDateOverride: createDate,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() => tester.pump(Duration.zero));
    return tester.element(find.byType(EditDiaryPage)).l10n;
  }

  List<String> imageEmbeds(WidgetTester tester) {
    final document = tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .controller
        .document;
    return <String>[
      for (final op in document.toDelta().toList())
        if (op.data case {'image': final String path}) path,
    ];
  }

  /// 复制原图是真实文件 IO：离开假时钟推进，直到正文里出现图片。
  Future<void> waitForImages(WidgetTester tester, int count) async {
    for (var i = 0; i < 60 && imageEmbeds(tester).length < count; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('backfilling a past day inserts the picked photos', (
    tester,
  ) async {
    final library = await galleryLibrary(tester);
    final l10n = await openEditor(
      tester,
      library: library,
      createDate: backfillDay,
    );

    expect(find.text(l10n.diaryDayPhotosTitle(2)), findsOneWidget);
    expect(find.byType(DiaryDayPhotoTile), findsNWidgets(2));
    expect(library.requestCount, 0);

    await tester.tap(find.bySemanticsLabel(RegExp('14:00')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.diaryDayPhotosSelected(1)), findsOneWidget);

    await tester.tap(find.text(l10n.diaryDayPhotosInsert));
    await waitForImages(tester, 1);

    final images = imageEmbeds(tester);
    expect(images, hasLength(1));
    final imagesRoot = p.join(
      appRoot.path,
      DiaryMediaStorageService.imagesDirectoryName,
    );
    expect(p.isWithin(imagesRoot, images.single), isTrue);
    expect(p.basename(images.single), 'hike.png');
    // 只读相册：原图必须原封不动。
    expect(
      await tester.runAsync(() => library.files['hike']!.exists()),
      isTrue,
    );
    expect(library.releaseCount, 1);

    // 已插入的照片锁定，勾选清空，操作行收起。
    expect(
      find.bySemanticsLabel(RegExp('14:00.*added|added.*14:00')),
      findsOneWidget,
    );
    expect(find.text(l10n.diaryDayPhotosInsert), findsNothing);
  });

  testWidgets('the full grid shares the selection and inserts from there', (
    tester,
  ) async {
    final library = await galleryLibrary(tester);
    final l10n = await openEditor(
      tester,
      library: library,
      createDate: backfillDay,
    );

    await tester.tap(find.text(l10n.diaryDayPhotosShowAll));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryDayPhotosSheet), findsOneWidget);
    final inSheet = find.descendant(
      of: find.byType(DiaryDayPhotosSheet),
      matching: find.byType(DiaryDayPhotoTile),
    );
    expect(inSheet, findsNWidgets(2));

    await tester.tap(inSheet.at(0));
    await tester.tap(inSheet.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.diaryDayPhotosInsertCount(2)));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryDayPhotosSheet), findsNothing);
    await waitForImages(tester, 2);

    // 按拍摄时间插入：早餐在前，徒步在后。
    expect(imageEmbeds(tester).map(p.basename).toList(), [
      'breakfast.png',
      'hike.png',
    ]);
  });

  Finder coverLabel(String time) =>
      find.bySemanticsLabel(RegExp('$time.*cover'));

  /// 拷贝封面是真实文件 IO：离开假时钟推进，直到出现封面角标。
  Future<void> waitForCover(WidgetTester tester, String time) async {
    for (var i = 0; i < 60 && coverLabel(time).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  /// 新建草稿防抖 1.3 秒后写入设置；返回草稿里的封面路径。
  Future<String?> savedDraftCover(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();
    final raw = settings.createDiaryDraftRaw;
    if (raw == null) return null;
    return (jsonDecode(raw) as Map<String, Object?>)['cover'] as String?;
  }

  testWidgets('a single selected photo can become the cover', (tester) async {
    final library = await galleryLibrary(tester);
    final l10n = await openEditor(
      tester,
      library: library,
      createDate: backfillDay,
    );
    await tester.enterText(find.byType(TextField).first, 'Hike day');

    await tester.tap(find.bySemanticsLabel(RegExp('14:00')));
    await tester.pumpAndSettle();
    // 只选一张时次要按钮是“设为封面”，不是“取消选择”。
    expect(find.text(l10n.diaryDayPhotosClear), findsNothing);
    await tester.tap(find.text(l10n.diaryDayPhotosSetCover));
    await waitForCover(tester, '14:00');

    expect(coverLabel('14:00'), findsOneWidget);
    expect(find.text(l10n.diaryDayPhotosCoverSet), findsOneWidget);
    expect(find.text(l10n.diaryDayPhotosClearCover), findsOneWidget);

    final cover = await savedDraftCover(tester);
    expect(cover, isNotNull);
    expect(p.isWithin(p.join(appRoot.path, 'diary_covers'), cover!), isTrue);
    expect(await tester.runAsync(() => File(cover).exists()), isTrue);
    // 只读相册：原图仍在。
    expect(
      await tester.runAsync(() => library.files['hike']!.exists()),
      isTrue,
    );
    expect(library.releaseCount, 1);

    await tester.tap(find.text(l10n.diaryDayPhotosClearCover));
    await tester.pumpAndSettle();
    expect(coverLabel('14:00'), findsNothing);
    expect(await savedDraftCover(tester), isNull);
  });

  testWidgets('long-pressing an inserted photo sets and removes the cover', (
    tester,
  ) async {
    final library = await galleryLibrary(tester);
    final l10n = await openEditor(
      tester,
      library: library,
      createDate: backfillDay,
    );

    await tester.tap(find.bySemanticsLabel(RegExp('08:00')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.diaryDayPhotosInsert));
    await waitForImages(tester, 1);

    final breakfastTile = find.byType(DiaryDayPhotoTile).first;
    await tester.longPress(breakfastTile);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.diaryDayPhotosSetCover));
    await waitForCover(tester, '08:00');
    expect(coverLabel('08:00'), findsOneWidget);
    expect(await savedDraftCover(tester), isNotNull);

    await tester.longPress(breakfastTile);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.diaryDayPhotosClearCover));
    await tester.pumpAndSettle();
    expect(coverLabel('08:00'), findsNothing);
    expect(await savedDraftCover(tester), isNull);
  });

  testWidgets('a photo deleted from the gallery is skipped with a hint', (
    tester,
  ) async {
    final library = await galleryLibrary(tester);
    final l10n = await openEditor(
      tester,
      library: library,
      createDate: backfillDay,
    );
    await tester.runAsync(() => library.files.remove('breakfast')!.delete());

    final tiles = find.byType(DiaryDayPhotoTile);
    await tester.tap(tiles.at(0));
    await tester.tap(tiles.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.diaryDayPhotosInsert));
    await waitForImages(tester, 1);

    expect(imageEmbeds(tester).map(p.basename), ['hike.png']);
    expect(find.text(l10n.diaryDayPhotosMissing(1)), findsOneWidget);
  });

  testWidgets('photo access is requested only after tapping allow', (
    tester,
  ) async {
    final library = await galleryLibrary(tester, access: DayPhotoAccess.denied);
    final l10n = await openEditor(
      tester,
      library: library,
      createDate: backfillDay,
    );

    expect(find.text(l10n.diaryDayPhotosAccessBody), findsOneWidget);
    expect(library.requestCount, 0);

    await tester.tap(find.text(l10n.diaryDayPhotosAllowAccess));
    await tester.pumpAndSettle();

    expect(library.requestCount, 1);
    expect(find.byType(DiaryDayPhotoTile), findsNWidgets(2));
  });

  testWidgets('dismissing hides the strip for this entry', (tester) async {
    final library = await galleryLibrary(tester);
    final l10n = await openEditor(
      tester,
      library: library,
      createDate: backfillDay,
    );

    await tester.tap(find.byTooltip(l10n.diaryDayPhotosDismiss));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryDayPhotoTile), findsNothing);
    final strip = tester.getSize(find.byType(DiaryDayPhotosStrip));
    expect(strip.height, 0);
  });

  testWidgets('writing for today never touches the photo library', (
    tester,
  ) async {
    final library = await galleryLibrary(tester);
    await openEditor(tester, library: library, createDate: now);
    expect(find.byType(DiaryDayPhotoTile), findsNothing);
    expect(library.checkCount, 0);
  });

  testWidgets('the editor setting turns the suggestions off', (tester) async {
    final library = await galleryLibrary(tester);
    await openEditor(
      tester,
      library: library,
      createDate: backfillDay,
      suggestionsEnabled: false,
    );
    expect(find.byType(DiaryDayPhotoTile), findsNothing);
    expect(library.checkCount, 0);
  });
}
