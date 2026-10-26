import '../../../support/diary_content_test_helpers.dart';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor_drop_target.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 桌面上把文件拖进编辑页正文：拖入时显示高亮，松开后经媒体导入链路插入
/// 光标处。原生拖放事件走插件的平台通道，这里直接驱动拖放区的状态
/// （[DiaryEditorDropTargetState.debugHover] / [DiaryEditorDropTargetState.handleDrop]）。
///
/// 编辑器拿到焦点后光标闪烁，pumpAndSettle 等不到静止，这里一律固定帧数。
void main() {
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  late AppDatabase database;
  late SettingsService settings;
  late String diaryId;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    diaryId = await database.createDiary(
      title: 'Drop probe',
      contentDocJson: '[{"insert":"line one\\n"}]',
      contentText: 'line one',
      metadataJson: '{}',
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
    return database.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: page,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  DiaryEditorDropTargetState dropTarget(WidgetTester tester) => tester
      .state<DiaryEditorDropTargetState>(find.byType(DiaryEditorDropTarget));

  double highlightOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(find.byKey(DiaryEditorDropTarget.highlightKey))
      .opacity;

  testWidgets('dragging files over the body shows the drop highlight', (
    tester,
  ) async {
    await pumpPage(tester, EditDiaryPage(diaryId: diaryId));
    expect(find.byType(DropTarget), findsOneWidget);
    expect(highlightOpacity(tester), 0);

    dropTarget(tester).debugHover(true);
    await settle(tester);
    expect(highlightOpacity(tester), 1);
    expect(find.text('Drop to insert'), findsOneWidget);
    final highlight = tester.getRect(
      find.ancestor(
        of: find.text('Drop to insert'),
        matching: find.byType(DecoratedBox),
      ),
    );
    // 与正文列同宽居中（最宽 760，四周留 8）。
    expect(highlight.width, closeTo(760 - 16, 0.5));
    expect(highlight.center.dx, closeTo(640, 0.5));

    dropTarget(tester).debugHover(false);
    await settle(tester);
    expect(highlightOpacity(tester), 0);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('dropping an image inserts an image block into the body', (
    tester,
  ) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('jotsy_drop_test_'),
    ))!;
    addTearDown(() => root.deleteSync(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (_) async => root.path);
    final source = File(p.join(root.path, 'dragged.png'));
    await tester.runAsync(() => source.writeAsBytes(<int>[1, 2, 3]));

    await pumpPage(tester, EditDiaryPage(diaryId: diaryId));
    final controller = tester
        .widget<DiaryEditor>(find.byType(DiaryEditor))
        .controller;
    bool hasImage() => walkDiaryEditorNodes(
      controller.document,
    ).any((node) => node.type == 'image');
    expect(hasImage(), isFalse);

    // 复制是真实的文件读写：在真实异步里松开并等它完成。
    await tester.runAsync(() async {
      dropTarget(tester).handleDrop(<String>[source.path]);
      for (var i = 0; i < 50 && !hasImage(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await settle(tester);
    expect(
      find.text('Files could not be imported. Please try again.'),
      findsNothing,
    );
    expect(hasImage(), isTrue);
    final image = walkDiaryEditorNodes(
      controller.document,
    ).firstWhere((node) => node.type == 'image');
    final copied = image.attributes['url'] as String;
    expect(p.isWithin(root.path, copied), isTrue);
    expect(copied, isNot(source.path));
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('the create page accepts drops too', (tester) async {
    await pumpPage(
      tester,
      const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
    );
    expect(find.byType(DropTarget), findsOneWidget);
    expect(tester.widget<DropTarget>(find.byType(DropTarget)).enable, isTrue);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('phones have no drop target', (tester) async {
    await pumpPage(
      tester,
      const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
    );
    expect(find.byType(DropTarget), findsNothing);
    await unmount(tester);
  });
}
