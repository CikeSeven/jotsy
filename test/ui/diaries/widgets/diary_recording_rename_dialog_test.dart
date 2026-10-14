import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_recording_rename_dialog.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  /// 弹窗结果通过 [result] 回传；`opened` 用来点开弹窗。
  Future<void> pumpHost(WidgetTester tester, List<String?> result) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result.add(
                await showDiaryRecordingRenameDialog(
                  context,
                  initialName: '旧名字',
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts from the current name and returns the trimmed result', (
    tester,
  ) async {
    final result = <String?>[];
    await pumpHost(tester, result);
    expect(find.text('重命名录音'), findsOneWidget);
    expect(find.text('旧名字'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  晨间反思  ');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(result, ['晨间反思']);
    expect(find.byType(AlertDialog), findsNothing);
    // 控制器随弹窗释放：退场动画期间不得再被使用。
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling returns null instead of an empty name', (
    tester,
  ) async {
    final result = <String?>[];
    await pumpHost(tester, result);
    await tester.enterText(find.byType(TextField), '改了一半');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(result, [null]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submitting from the keyboard confirms like the button', (
    tester,
  ) async {
    final result = <String?>[];
    await pumpHost(tester, result);
    await tester.enterText(find.byType(TextField), ' 键盘提交 ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(result, ['键盘提交']);
  });

  testWidgets('an emptied field returns an empty string for the caller', (
    tester,
  ) async {
    final result = <String?>[];
    await pumpHost(tester, result);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    // 空串表示“恢复默认标题”，由调用方解释；它不同于取消的 null。
    expect(result, ['']);
  });

  testWidgets('names are limited to 30 characters', (tester) async {
    final result = <String?>[];
    await pumpHost(tester, result);
    await tester.enterText(find.byType(TextField), '字' * 40);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(result.single, hasLength(30));
  });
}
