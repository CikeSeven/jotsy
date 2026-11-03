import '../../../support/diary_content_test_helpers.dart';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_day_photo_preview_page.dart';
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
  late AppDatabase database;

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

  /// 编辑已有日记：日记表的读取在假时钟下要离开它推进。
  Future<void> settleDrift(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  /// 写入一篇发表在 [backfillDay] 晚上的日记，返回它的业务 id。
  Future<String> seedDiary(WidgetTester tester) async => (await tester.runAsync(
    () => database.createDiary(
      title: 'Hike day',
      contentDocJson: jsonEncode(<Map<String, Object?>>[
        <String, Object?>{'insert': 'We walked.\n'},
      ]),
      contentText: 'We walked.',
      metadataJson: '{}',
      createdAtOverride: backfillDay.add(const Duration(hours: 21)),
    ),
  ))!;

  Future<AppLocalizations> openEditor(
    WidgetTester tester, {
    required DayPhotoLibrary library,
    DateTime? createDate,
    bool suggestionsEnabled = true,
    bool editExisting = false,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    settings = await SettingsService.create();
    await settings.setDayPhotoSuggestionsEnabled(suggestionsEnabled);
    final existing = editExisting ? await seedDiary(tester) : null;

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
            quill.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: existing != null
              ? EditDiaryPage(diaryId: existing)
              : EditDiaryPage(
                  entryMode: EditDiaryEntryMode.create,
                  createDateOverride: createDate,
                ),
        ),
      ),
    );
    if (existing != null) await settleDrift(tester);
    await tester.pumpAndSettle();
    addTearDown(() => tester.pump(Duration.zero));
    return tester.element(find.byType(EditDiaryPage)).l10n;
  }

  List<String> imageEmbeds(WidgetTester tester) {
    final document = tester
        .widget<DiaryEditor>(find.byType(DiaryEditor))
        .controller
        .document;
    return <String>[
      for (final op in document.toDelta().toList())
        if (op.data case {'image': final String path}) path,
    ];
  }

  /// 某个拍摄时间的那一格（读屏文案里带时间）。
  Finder tileAt(String time) => find.ancestor(
    of: find.bySemanticsLabel(RegExp(time)),
    matching: find.byType(DiaryDayPhotoTile),
  );

  /// 点格子右上角的勾选圈（点缩略图本身是打开预览）。
  Future<void> toggleTile(WidgetTester tester, Finder tile) async {
    await tester.tapAt(tester.getTopRight(tile) + const Offset(-12, 12));
    await tester.pump();
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

    await toggleTile(tester, tileAt('14:00'));
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

    // 模板建议条也有“全部”，只点照片提示条里的这一个。
    await tester.tap(
      find.descendant(
        of: find.byType(DiaryDayPhotosStrip),
        matching: find.text(l10n.diaryDayPhotosShowAll),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DiaryDayPhotosSheet), findsOneWidget);
    final inSheet = find.descendant(
      of: find.byType(DiaryDayPhotosSheet),
      matching: find.byType(DiaryDayPhotoTile),
    );
    expect(inSheet, findsNWidgets(2));

    await toggleTile(tester, inSheet.at(0));
    await toggleTile(tester, inSheet.at(1));
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

  /// 新建草稿防抖 1.3 秒后写入草稿箱；返回草稿里的封面路径。
  Future<String?> savedDraftCover(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();
    final drafts = await tester.runAsync(
      () => database.watchDiaryDrafts().first,
    );
    if (drafts == null || drafts.isEmpty) return null;
    final payload = jsonDecode(drafts.single.payload) as Map<String, Object?>;
    return payload['cover'] as String?;
  }

  testWidgets('a single selected photo can become the cover', (tester) async {
    final library = await galleryLibrary(tester);
    final l10n = await openEditor(
      tester,
      library: library,
      createDate: backfillDay,
    );
    await tester.enterText(find.byType(TextField).first, 'Hike day');

    await toggleTile(tester, tileAt('14:00'));
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

    await toggleTile(tester, tileAt('08:00'));
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
    await toggleTile(tester, tiles.at(0));
    await toggleTile(tester, tiles.at(1));
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

  group('the top-bar menu', () {
    Finder menuItem(AppLocalizations l10n) =>
        find.text(l10n.diaryDayPhotosMenu);

    Finder sheetTiles() => find.descendant(
      of: find.byType(DiaryDayPhotosSheet),
      matching: find.byType(DiaryDayPhotoTile),
    );

    Future<void> openMenu(WidgetTester tester, AppLocalizations l10n) async {
      await tester.tap(find.byTooltip(l10n.diaryEditorMoreActions));
      await tester.pumpAndSettle();
    }

    Future<void> openDayPhotos(
      WidgetTester tester,
      AppLocalizations l10n,
    ) async {
      await openMenu(tester, l10n);
      await tester.tap(menuItem(l10n));
      await tester.pumpAndSettle();
    }

    /// 编辑已有日记：页面卸载后让 drift 的计时器走完，避免“Timer is still
    /// pending”。
    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }

    testWidgets('opens the past day\'s photos with the setting off', (
      tester,
    ) async {
      final library = await galleryLibrary(tester);
      final l10n = await openEditor(
        tester,
        library: library,
        createDate: backfillDay,
        suggestionsEnabled: false,
      );
      expect(find.byType(DiaryDayPhotoTile), findsNothing);
      expect(library.checkCount, 0);

      await openDayPhotos(tester, l10n);

      expect(
        find.text(
          l10n.diaryDayPhotosSheetTitle(l10n.formatEyebrowDate(backfillDay)),
        ),
        findsOneWidget,
      );
      expect(sheetTiles(), findsNWidgets(2));
      expect(library.requestCount, 0);

      await toggleTile(tester, sheetTiles().at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.diaryDayPhotosInsertCount(1)));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryDayPhotosSheet), findsNothing);
      await waitForImages(tester, 1);
      expect(imageEmbeds(tester).map(p.basename), ['hike.png']);
      // 开关仍关着：提示条不因打开过面板而出现。
      expect(find.byType(DiaryDayPhotoTile), findsNothing);
    });

    testWidgets('shows the empty state for a day without photos', (
      tester,
    ) async {
      final library = await galleryLibrary(tester);
      final l10n = await openEditor(
        tester,
        library: library,
        createDate: now,
        suggestionsEnabled: false,
      );

      await openDayPhotos(tester, l10n);

      expect(find.text(l10n.diaryDayPhotosEmpty), findsOneWidget);
      expect(sheetTiles(), findsNothing);
      // 没有照片时没有底栏。
      expect(find.text(l10n.diaryDayPhotosInsert), findsNothing);
      expect(library.queriedDays, [DateTime(now.year, now.month, now.day)]);
    });

    testWidgets('asks for photo access only after tapping allow', (
      tester,
    ) async {
      final library = await galleryLibrary(
        tester,
        access: DayPhotoAccess.denied,
      );
      final l10n = await openEditor(
        tester,
        library: library,
        createDate: backfillDay,
        suggestionsEnabled: false,
      );

      await openDayPhotos(tester, l10n);

      expect(
        find.descendant(
          of: find.byType(DiaryDayPhotosSheet),
          matching: find.text(l10n.diaryDayPhotosAccessBody),
        ),
        findsOneWidget,
      );
      expect(library.requestCount, 0);

      await tester.tap(find.text(l10n.diaryDayPhotosAllowAccess));
      await tester.pumpAndSettle();

      expect(library.requestCount, 1);
      expect(sheetTiles(), findsNWidgets(2));
    });

    testWidgets('is not offered for a future date', (tester) async {
      final library = await galleryLibrary(tester);
      final l10n = await openEditor(
        tester,
        library: library,
        createDate: DateTime(now.year, now.month, now.day + 5),
      );

      await openMenu(tester, l10n);

      expect(find.text(l10n.diaryTemplateSaveAs), findsOneWidget);
      expect(menuItem(l10n), findsNothing);
      expect(library.checkCount, 0);
    });

    testWidgets('editing a diary opens its day and inserts a photo', (
      tester,
    ) async {
      final library = await galleryLibrary(tester);
      final l10n = await openEditor(
        tester,
        library: library,
        editExisting: true,
      );

      await openDayPhotos(tester, l10n);

      expect(
        find.text(
          l10n.diaryDayPhotosSheetTitle(l10n.formatEyebrowDate(backfillDay)),
        ),
        findsOneWidget,
      );
      expect(sheetTiles(), findsNWidgets(2));

      await toggleTile(tester, sheetTiles().at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.diaryDayPhotosInsertCount(1)));
      await tester.pumpAndSettle();
      await waitForImages(tester, 1);
      expect(imageEmbeds(tester).map(p.basename), ['breakfast.png']);

      await unmount(tester);
    });

    testWidgets('editing a diary sets the cover without writing a draft', (
      tester,
    ) async {
      final library = await galleryLibrary(tester);
      final l10n = await openEditor(
        tester,
        library: library,
        editExisting: true,
      );

      await openDayPhotos(tester, l10n);
      await toggleTile(tester, sheetTiles().at(1));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DiaryDayPhotosSheet),
          matching: find.text(l10n.diaryDayPhotosSetCover),
        ),
      );
      await waitForCover(tester, '14:00');

      expect(coverLabel('14:00'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(l10n.diaryDayPhotosCoverSetEdit),
        ),
        findsOneWidget,
      );

      // 草稿防抖窗口（1.3 秒）与编辑自动保存（0.5 秒）都过去之后。
      await tester.pump(const Duration(milliseconds: 1400));
      await settleDrift(tester);
      final drafts = await tester.runAsync(
        () => database.watchDiaryDrafts().first,
      );
      expect(drafts, isEmpty);
      final diaries = await tester.runAsync(
        () => database.select(database.diaries).get(),
      );
      final cover = diaries!.single.cover;
      expect(cover, isNotNull);
      expect(p.isWithin(p.join(appRoot.path, 'diary_covers'), cover!), isTrue);

      await unmount(tester);
    });
  });

  group('videos and the preview', () {
    final clip = DayPhoto(
      id: 'clip',
      takenAt: backfillDay.add(const Duration(hours: 12)),
      width: 1920,
      height: 1080,
      isVideo: true,
      duration: const Duration(seconds: 23),
    );

    /// 早餐照片 08:00、视频 12:00、徒步照片 14:00；视频是一份假的 mp4。
    Future<FakeDayPhotoLibrary> mixedLibrary(
      WidgetTester tester, {
      DayPhotoAccess access = DayPhotoAccess.granted,
    }) async {
      final library = FakeDayPhotoLibrary(
        access: access,
        photosByDay: {
          backfillDay: [breakfast, clip, hike],
        },
      );
      await tester.runAsync(() async {
        for (final (photo, name) in [
          (breakfast, 'breakfast.png'),
          (clip, 'clip.mp4'),
          (hike, 'hike.png'),
        ]) {
          final file = File(p.join(gallery.path, name));
          await file.writeAsBytes(kTinyPng);
          library.files[photo.id] = file;
        }
      });
      return library;
    }

    /// 正文里的图片与视频块（类型:文件名），按文档顺序。
    List<String> mediaBlocks(WidgetTester tester) {
      final document = tester
          .widget<DiaryEditor>(find.byType(DiaryEditor))
          .controller
          .document;
      return <String>[
        for (final node in walkDiaryEditorNodes(document))
          if (node.type == 'image' || node.type == 'video')
            '${node.type}:${p.basename(node.attributes['url'] as String)}',
      ];
    }

    Future<void> waitForMedia(WidgetTester tester, int count) async {
      for (var i = 0; i < 80 && mediaBlocks(tester).length < count; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
    }

    Finder inPreview(Finder finder) => find.descendant(
      of: find.byType(DiaryDayPhotoPreviewPage),
      matching: finder,
    );

    testWidgets('videos are listed with their length and inserted in order', (
      tester,
    ) async {
      final library = await mixedLibrary(tester);
      final l10n = await openEditor(
        tester,
        library: library,
        createDate: backfillDay,
      );

      expect(find.text(l10n.diaryDayPhotosTitleMixed(2, 1)), findsOneWidget);
      expect(find.byType(DiaryDayPhotoTile), findsNWidgets(3));
      expect(find.text('0:23'), findsOneWidget);
      expect(library.queriedWithVideos, [true]);

      // 只选了视频：次要按钮仍是“取消选择”，视频不能当封面。
      await toggleTile(tester, tileAt('12:00'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.diaryDayPhotosSelectedItems(1)), findsOneWidget);
      expect(find.text(l10n.diaryDayPhotosClear), findsOneWidget);
      expect(find.text(l10n.diaryDayPhotosSetCover), findsNothing);

      await toggleTile(tester, tileAt('08:00'));
      await toggleTile(tester, tileAt('14:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.diaryDayPhotosInsert));
      await waitForMedia(tester, 3);

      // 按拍摄时间：照片、视频、照片，视频插成视频块。
      expect(mediaBlocks(tester), [
        'image:breakfast.png',
        'video:clip.mp4',
        'image:hike.png',
      ]);
      final videosRoot = p.join(
        appRoot.path,
        DiaryMediaStorageService.videosDirectoryName,
      );
      final video = walkDiaryEditorNodes(
        tester
            .widget<DiaryEditor>(find.byType(DiaryEditor))
            .controller
            .document,
      ).singleWhere((node) => node.type == 'video');
      expect(p.isWithin(videosRoot, video.attributes['url'] as String), isTrue);
      // 只读相册：原视频仍在。
      expect(
        await tester.runAsync(() => library.files['clip']!.exists()),
        isTrue,
      );
      expect(library.releaseCount, 1);
      expect(find.bySemanticsLabel(RegExp('12:00.*added')), findsOneWidget);
    });

    testWidgets('tapping a thumbnail previews it; select and insert there', (
      tester,
    ) async {
      final library = await galleryLibrary(tester);
      final l10n = await openEditor(
        tester,
        library: library,
        createDate: backfillDay,
      );

      await tester.tap(tileAt('08:00'));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryDayPhotoPreviewPage), findsOneWidget);
      expect(find.bySemanticsLabel('1 / 2'), findsOneWidget);
      // 点缩略图只是打开预览，不勾选。
      expect(library.requestCount, 0);
      expect(
        tester
            .widget<FilledButton>(inPreview(find.byType(FilledButton)))
            .onPressed,
        isNull,
      );

      // 翻到下一张，勾选，然后在预览页里插入。
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('2 / 2'), findsOneWidget);
      await tester.tap(inPreview(find.byTooltip(l10n.diaryDayPhotosSelect)));
      await tester.pumpAndSettle();
      expect(
        inPreview(find.byTooltip(l10n.diaryDayPhotosDeselect)),
        findsOneWidget,
      );
      await tester.tap(inPreview(find.text(l10n.diaryDayPhotosInsertCount(1))));
      await tester.pumpAndSettle();

      expect(find.byType(DiaryDayPhotoPreviewPage), findsNothing);
      await waitForImages(tester, 1);
      expect(imageEmbeds(tester).map(p.basename), ['hike.png']);
    });

    testWidgets('selection made in the preview carries back to the strip', (
      tester,
    ) async {
      final library = await galleryLibrary(tester);
      final l10n = await openEditor(
        tester,
        library: library,
        createDate: backfillDay,
      );

      await tester.tap(tileAt('14:00'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('2 / 2'), findsOneWidget);
      await tester.tap(inPreview(find.byTooltip(l10n.diaryDayPhotosSelect)));
      await tester.pumpAndSettle();
      await tester.tap(inPreview(find.byTooltip(l10n.commonBack)));
      await tester.pumpAndSettle();

      expect(find.byType(DiaryDayPhotoPreviewPage), findsNothing);
      expect(find.text(l10n.diaryDayPhotosSelected(1)), findsOneWidget);
      // 只选一张图片：操作行可以设为封面。
      expect(find.text(l10n.diaryDayPhotosSetCover), findsOneWidget);
      expect(imageEmbeds(tester), isEmpty);
    });

    testWidgets('a video previews with a player and has no cover menu', (
      tester,
    ) async {
      final library = await mixedLibrary(tester);
      final l10n = await openEditor(
        tester,
        library: library,
        createDate: backfillDay,
      );

      // 长按视频没有“设为封面”菜单。
      await tester.longPress(tileAt('12:00'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.diaryDayPhotosSetCover), findsNothing);

      await tester.tap(tileAt('12:00'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('2 / 3'), findsOneWidget);
      // 底栏写出拍摄时间与时长；读不到播放地址时说明放不了。
      expect(inPreview(find.text('12:00 · 0:23')), findsOneWidget);
      expect(inPreview(find.text(l10n.videoPlaybackFailed)), findsOneWidget);
      expect(inPreview(find.byTooltip(l10n.videoPlay)), findsOneWidget);
    });

    testWidgets('inserting from a preview opened in the sheet closes both', (
      tester,
    ) async {
      final library = await galleryLibrary(tester);
      final l10n = await openEditor(
        tester,
        library: library,
        createDate: backfillDay,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(DiaryDayPhotosStrip),
          matching: find.text(l10n.diaryDayPhotosShowAll),
        ),
      );
      await tester.pumpAndSettle();
      final inSheet = find.descendant(
        of: find.byType(DiaryDayPhotosSheet),
        matching: find.byType(DiaryDayPhotoTile),
      );

      await tester.tap(inSheet.at(0));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryDayPhotoPreviewPage), findsOneWidget);
      await tester.tap(inPreview(find.byTooltip(l10n.diaryDayPhotosSelect)));
      await tester.pumpAndSettle();
      await tester.tap(inPreview(find.text(l10n.diaryDayPhotosInsertCount(1))));
      await tester.pumpAndSettle();

      expect(find.byType(DiaryDayPhotoPreviewPage), findsNothing);
      expect(find.byType(DiaryDayPhotosSheet), findsNothing);
      await waitForImages(tester, 1);
      expect(imageEmbeds(tester).map(p.basename), ['breakfast.png']);
    });

    testWidgets('with only image access, videos wait for a tap on allow', (
      tester,
    ) async {
      final library = await mixedLibrary(
        tester,
        access: DayPhotoAccess.imagesOnly,
      );
      final l10n = await openEditor(
        tester,
        library: library,
        createDate: backfillDay,
      );

      // 照片照常列出，视频不查，另有一行说明。
      expect(find.text(l10n.diaryDayPhotosTitle(2)), findsOneWidget);
      expect(find.byType(DiaryDayPhotoTile), findsNWidgets(2));
      expect(find.text(l10n.diaryDayPhotosVideoAccess), findsOneWidget);
      expect(library.queriedWithVideos, [false]);
      expect(library.requestCount, 0);

      await tester.tap(
        find.descendant(
          of: find.byType(DiaryDayPhotosStrip),
          matching: find.text(l10n.diaryDayPhotosAllowAccess),
        ),
      );
      await tester.pumpAndSettle();

      expect(library.requestCount, 1);
      expect(library.queriedWithVideos.last, isTrue);
      expect(find.byType(DiaryDayPhotoTile), findsNWidgets(3));
      expect(find.text(l10n.diaryDayPhotosTitleMixed(2, 1)), findsOneWidget);
      expect(find.text(l10n.diaryDayPhotosVideoAccess), findsNothing);
    });
  });
}
