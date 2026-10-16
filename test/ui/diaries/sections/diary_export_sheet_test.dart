import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/sections/diary_export_sheet.dart';

import '../../../support/expressive_test_theme.dart';

Future<DiaryExportRequest? Function()> _open(
  WidgetTester tester, {
  int count = 3,
  DiaryExportOptions options = DiaryExportOptions.defaults,
  List<DiaryExportOptions>? changes,
  Brightness brightness = Brightness.light,
}) async {
  DiaryExportRequest? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(brightness),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showDiaryExportSheet(
                context,
                diaryCount: count,
                initialOptions: options,
                onOptionsChanged: (next) => changes?.add(next),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => result;
}

Finder _sheetScrollable() => find
    .descendant(
      of: find.byType(DiaryExportSheet),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  testWidgets('lists every format and adapts the options to the format', (
    tester,
  ) async {
    final changes = <DiaryExportOptions>[];
    await _open(tester, changes: changes);

    expect(find.text('共 3 篇'), findsOneWidget);
    for (final name in <String>[
      'PDF',
      'Word 文档',
      'Markdown',
      '网页',
      '纯文本',
      '表格（CSV）',
      'Jotsy 日记文件',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('包含图片'), findsOneWidget);
    expect(find.text('从旧到新'), findsOneWidget);

    await tester.tap(find.text('Markdown'));
    await tester.pumpAndSettle();
    expect(find.text('包含图片、录音、视频与附件'), findsOneWidget);
    expect(changes.last.format, DiaryExportFormat.markdown);

    await tester.scrollUntilVisible(
      find.text('表格（CSV）'),
      80,
      scrollable: _sheetScrollable(),
    );
    await tester.tap(find.text('表格（CSV）'));
    await tester.pumpAndSettle();
    // 表格没有媒体，每列各自独立，不提供媒体与信息开关，只剩排序。
    expect(find.text('包含图片'), findsNothing);
    expect(find.text('包含心情、天气、地点与标签'), findsNothing);
    expect(find.text('从旧到新'), findsOneWidget);

    await tester.tap(find.text('Jotsy 日记文件'));
    await tester.pumpAndSettle();
    expect(find.text('从旧到新'), findsNothing);
    expect(find.text('选项'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save and share close the sheet with the chosen options', (
    tester,
  ) async {
    final result = await _open(
      tester,
      count: 1,
      options: const DiaryExportOptions(format: DiaryExportFormat.word),
      brightness: Brightness.dark,
    );
    // 单篇不显示排序。
    expect(find.text('从旧到新'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('包含心情、天气、地点与标签'),
      80,
      scrollable: _sheetScrollable(),
    );
    await tester.tap(find.text('包含心情、天气、地点与标签'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('保存到文件'),
      80,
      scrollable: _sheetScrollable(),
    );
    await tester.tap(find.text('保存到文件'));
    await tester.pumpAndSettle();
    final request = result()!;
    expect(request.action, DiaryExportAction.save);
    expect(request.options.format, DiaryExportFormat.word);
    expect(request.options.includeMeta, isFalse);

    final shared = await _open(tester);
    await tester.scrollUntilVisible(
      find.text('分享'),
      80,
      scrollable: _sheetScrollable(),
    );
    await tester.tap(find.text('分享'));
    await tester.pumpAndSettle();
    expect(shared()!.action, DiaryExportAction.share);
  });
}
