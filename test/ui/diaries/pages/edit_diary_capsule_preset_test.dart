import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/pages/publish_diary_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 日历“写给这一天的时间胶囊”：编辑页带着预设解封日打开，发布后即为在
/// 该日零点解封的胶囊，发表时间同为解封时间。
void main() {
  testWidgets('a preset unlock day publishes a capsule for that day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = await SettingsService.create();
    final now = DateTime.now();
    final unlockDay = DateTime(now.year, now.month, now.day + 10);
    final results = <Object?>[];

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
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<Object?>(
                    MaterialPageRoute<Object?>(
                      builder: (_) => EditDiaryPage(
                        entryMode: EditDiaryEntryMode.create,
                        restoreCreateDraft: false,
                        createDateOverride: unlockDay,
                        // 带时分的值也按“日期”精度归一到当天零点。
                        createCapsuleUnlockAt: unlockDay.add(
                          const Duration(hours: 15, minutes: 30),
                        ),
                      ),
                    ),
                  );
                  results.add(result);
                },
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Dear future me');
    await tester.pump();
    final l10n = tester.element(find.byType(EditDiaryPage)).l10n;
    await tester.tap(find.byTooltip(l10n.autoT0136));
    await tester.pumpAndSettle();
    expect(find.byType(PublishDiaryPage), findsOneWidget);

    // 发布按钮在可拖拽面板底部（收起态位于屏幕外），直接触发它的回调。
    final publishButton = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is FaIcon &&
              widget.icon?.codePoint == FontAwesomeIcons.paperPlane.codePoint,
        ),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      ),
    );
    publishButton.onPressed!();
    // 写库是真实异步，胶囊还有封存动画：离开假时钟推进，直到结果回传。
    for (var i = 0; i < 60 && results.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    final stored = await tester.runAsync(
      () => database.getDiaryWithTagsByDiaryId(results.single! as String),
    );
    expect(stored?.diary.capsuleUnlockAt, unlockDay);
    expect(stored?.diary.capsuleLockedAt, isNotNull);
    expect(stored?.diary.createdAt, unlockDay);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
