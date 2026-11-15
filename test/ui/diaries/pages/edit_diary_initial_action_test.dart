import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_create_initial_action.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_recording_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 桌面小组件的“拍照记 / 录音记”：新建日记的编辑页入场后不等用户点工具栏，直接
/// 开始拍照或录音。
void main() {
  const camera = MethodChannel('com.jotsy.diary/camera_capture');

  Future<void> pumpPage(
    WidgetTester tester,
    DiaryCreateInitialAction? action,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = await SettingsService.create();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: EditDiaryPage(
            entryMode: EditDiaryEntryMode.create,
            createInitialAction: action,
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('photo opens the camera right away', (tester) async {
    final requests = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(camera, (call) async {
          requests.add(call.arguments);
          // 相当于用户在相机里返回、没有拍：正文不变。
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(camera, null);
    });
    await pumpPage(tester, DiaryCreateInitialAction.camera);
    expect(requests, [
      {'kind': 'image'},
    ]);
    await unmount(tester);
  });

  testWidgets('voice opens the recording panel and starts right away', (
    tester,
  ) async {
    const recorder = MethodChannel('com.llfbandit.record/messages');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recorder, (call) async {
          calls.add(call.method);
          // 没有麦克风权限：面板留着并说明原因，正文不变。
          return call.method == 'hasPermission' ? false : null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(recorder, null);
    });
    await pumpPage(tester, DiaryCreateInitialAction.voice);
    expect(find.byType(DiaryRecordingPanel), findsOneWidget);
    expect(calls, contains('hasPermission'));
    await unmount(tester);
  });

  testWidgets('a plain new entry neither films nor records', (tester) async {
    final requests = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(camera, (call) async {
          requests.add(call.arguments);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(camera, null);
    });
    await pumpPage(tester, null);
    expect(requests, isEmpty);
    expect(find.byType(DiaryRecordingPanel), findsNothing);
    await unmount(tester);
  });
}
