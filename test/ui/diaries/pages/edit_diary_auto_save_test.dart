import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  late AppDatabase database;
  late SettingsService settings;
  late String diaryId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    diaryId = await database.createDiary(
      title: 'Original title',
      contentDocJson: '[{"insert":"Original body\\n"}]',
      contentText: 'Original body',
      metadataJson: '{}',
    );
  });
  tearDown(() => database.close());

  Future<void> openEditor(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(brightness),
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => EditDiaryPage(diaryId: diaryId),
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
  }

  quill.QuillController contentController(WidgetTester tester) => tester
      .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
      .controller;

  Future<DiaryWithTags> storedDiary(WidgetTester tester) async => (await tester
      .runAsync(() => database.getDiaryWithTagsByDiaryId(diaryId)))!;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'title and rich text automatically save in ${brightness.name} theme',
      (tester) async {
        await openEditor(tester, brightness: brightness);
        final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
        expect(find.byTooltip(l10n.commonSave), findsNothing);
        expect(
          tester
              .widget<PublishDiaryPanel>(find.byType(PublishDiaryPanel))
              .onPublish,
          isNull,
        );

        await tester.enterText(
          find.widgetWithText(TextField, 'Original title'),
          'Saved automatically',
        );
        final content = contentController(tester);
        content.replaceText(
          0,
          content.document.length - 1,
          'New body',
          const TextSelection.collapsed(offset: 8),
        );
        content.formatText(0, 3, quill.Attribute.bold);
        await tester.pump(const Duration(milliseconds: 600));

        final saved = await storedDiary(tester);
        expect(saved.diary.title, 'Saved automatically');
        expect(saved.diary.contentText, 'New body');
        final document = decodeDiaryContentToDocument(saved.diary.content);
        expect(document.toDelta().first.attributes?['bold'], isTrue);
        expect(find.byType(EditDiaryPage), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      },
    );
  }

  for (final systemBack in [false, true]) {
    testWidgets(
      '${systemBack ? 'system' : 'toolbar'} back saves the last input without a dialog',
      (tester) async {
        await openEditor(tester);
        await tester.enterText(
          find.widgetWithText(TextField, 'Original title'),
          'Last keystroke',
        );
        // 不等待防抖计时，返回必须先将刚输入的内容写入数据库。
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
          await tester.tap(find.byTooltip(l10n.commonBack));
        }
        final saved = await storedDiary(tester);
        await tester.pumpAndSettle();
        expect(saved.diary.title, 'Last keystroke');
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(EditDiaryPage), findsNothing);
        expect(find.text('Open editor'), findsOneWidget);
        await unmount(tester);
      },
    );
  }

  testWidgets('metadata and tag changes automatically save', (tester) async {
    final tagId = await database.createTag(name: 'Life', color: 0xff2196f3);
    await openEditor(tester);
    final panel = tester.widget<PublishDiaryPanel>(
      find.byType(PublishDiaryPanel),
    );
    panel.onMoodChanged('🙂');
    panel.onToggleTag(tagId, true);
    panel.locationController.text = 'Home';
    panel.onLocationChanged('Home');
    await tester.pump(const Duration(milliseconds: 600));

    final saved = await storedDiary(tester);
    final metadata = jsonDecode(saved.diary.metadata) as Map<String, dynamic>;
    expect((metadata['context'] as Map)['moodEmoji'], '🙂');
    expect((metadata['context'] as Map)['location'], 'Home');
    expect(saved.tags.map((tag) => tag.id), [tagId]);
    await unmount(tester);
  });

  testWidgets('address detail changes save and restore when editing again', (
    tester,
  ) async {
    await openEditor(tester);
    var panel = tester.widget<PublishDiaryPanel>(
      find.byType(PublishDiaryPanel),
    );
    expect(panel.locationPrecision, DiaryLocationPrecision.township);
    panel.onLocationPrecisionChanged!(DiaryLocationPrecision.address);
    await tester.pump(const Duration(milliseconds: 600));

    final saved = await storedDiary(tester);
    final metadata = jsonDecode(saved.diary.metadata) as Map;
    expect((metadata['context'] as Map)['locationPrecision'], 'address');
    expect(settings.diaryLocationPrecisionRaw, 'address');
    await unmount(tester);
    await openEditor(tester);
    panel = tester.widget<PublishDiaryPanel>(find.byType(PublishDiaryPanel));
    expect(panel.locationPrecision, DiaryLocationPrecision.address);
    await unmount(tester);
  });

  // 旧版本自动定位后再手改地点仍会保存 geo，重新编辑时不能把手写地点
  // 当成自动文案覆盖；未改过的自动地址照常跟随层级。
  for (final (stored, expected) in [
    ('望京 SOHO', '望京 SOHO'),
    ('北京市 · 望京街道', '北京市'),
  ]) {
    testWidgets('a level change on a located diary turns "$stored" into '
        '"$expected"', (tester) async {
      diaryId = (await tester.runAsync(
        () => database.createDiary(
          title: 'Located',
          contentDocJson: '[{"insert":"Located\\n"}]',
          contentText: 'Located',
          metadataJson: jsonEncode({
            'context': {
              'location': stored,
              'geo': {
                'source': 'amap_auto',
                'latitude': 39.98941,
                'longitude': 116.480881,
                'addressComponent': {
                  'province': '北京市',
                  'city': <Object?>[],
                  'district': '朝阳区',
                  'township': '望京街道',
                },
              },
            },
          }),
        ),
      ))!;
      await openEditor(tester);
      tester
          .widget<PublishDiaryPanel>(find.byType(PublishDiaryPanel))
          .onLocationPrecisionChanged!(DiaryLocationPrecision.city);
      await tester.pump(const Duration(milliseconds: 600));

      final saved = await storedDiary(tester);
      final context =
          (jsonDecode(saved.diary.metadata) as Map)['context'] as Map;
      expect(context['location'], expected);
      expect(context['locationPrecision'], 'city');
      expect((context['geo'] as Map)['latitude'], 39.98941);
      await unmount(tester);
    });
  }

  testWidgets('clearing an existing note automatically saves empty content', (
    tester,
  ) async {
    await openEditor(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Original title'),
      '',
    );
    final content = contentController(tester);
    content.replaceText(
      0,
      content.document.length - 1,
      '',
      const TextSelection.collapsed(offset: 0),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final saved = await storedDiary(tester);
    expect(saved.diary.title, isEmpty);
    expect(saved.diary.contentText, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    await unmount(tester);
  });

  testWidgets('entering the background saves before the debounce expires', (
    tester,
  ) async {
    await openEditor(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Original title'),
      'Background edit',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect((await storedDiary(tester)).diary.title, 'Background edit');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await unmount(tester);
  });

  testWidgets('failed saving keeps the editor open and retries on back', (
    tester,
  ) async {
    await openEditor(tester);
    await tester.runAsync(
      () => database.customStatement('''
        CREATE TRIGGER reject_diary_update BEFORE UPDATE ON diaries
        BEGIN SELECT RAISE(ABORT, 'disk unavailable'); END;
      '''),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Original title'),
      'Keep this input',
    );
    final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
    await tester.tap(find.byTooltip(l10n.commonBack));
    expect((await storedDiary(tester)).diary.title, 'Original title');
    await tester.pumpAndSettle();
    expect(find.byType(EditDiaryPage), findsOneWidget);
    expect(find.text('Keep this input'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Save failed:'), findsOneWidget);

    await tester.runAsync(
      () => database.customStatement('DROP TRIGGER reject_diary_update'),
    );
    await tester.tap(find.byTooltip(l10n.commonBack));
    expect((await storedDiary(tester)).diary.title, 'Keep this input');
    await tester.pumpAndSettle();
    expect(find.byType(EditDiaryPage), findsNothing);
    await unmount(tester);
  });
}
