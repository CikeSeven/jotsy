import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_recording_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 编辑页与录音面板的装配：工具栏麦克风打开面板、关闭按钮收起面板。
/// 不触碰真实麦克风——开始录音需要原生插件，由设备集成测试覆盖。
void main() {
  late AppDatabase database;
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
  });
  tearDown(() => database.close());

  Future<void> pumpCreatePage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    // 悬浮工具栏只在软键盘弹起且正文有焦点时出现。
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
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
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets(
    'toolbar microphone opens the recording panel and close hides it',
    (tester) async {
      await pumpCreatePage(tester);
      expect(find.byType(DiaryRecordingPanel), findsNothing);
      final editor = tester.element(find.byType(quill.QuillEditor));

      await tester.tap(find.byTooltip('录音'));
      await tester.pumpAndSettle();
      // 实际打开和收起面板时，编辑器子树不能因 PopScope 根节点切换而重建。
      expect(tester.element(find.byType(quill.QuillEditor)), same(editor));
      expect(find.byType(DiaryRecordingPanel), findsOneWidget);
      expect(find.byTooltip('开始录音'), findsOneWidget);
      expect(find.text('点按麦克风开始录音'), findsOneWidget);
      // 待机面板不得带着循环动画，否则编辑页会一直出帧。
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.tap(find.byTooltip('关闭录音'));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryRecordingPanel), findsNothing);
      expect(tester.element(find.byType(quill.QuillEditor)), same(editor));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets(
    'opening the panel with reduce motion on raises no layout errors',
    (tester) async {
      // 工具栏与面板外层的 AnimatedSize 时长为 0 时，面板插入造成的尺寸变化会
      // 触发 “mutated in its own performLayout” 断言；这里守住该回归。
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpCreatePage(tester);

      await tester.tap(find.byTooltip('录音'));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryRecordingPanel), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('关闭录音'));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryRecordingPanel), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );
}
