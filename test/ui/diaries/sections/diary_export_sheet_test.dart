import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/sections/diary_export_sheet.dart';
import 'package:node_diary/ui/widgets/expressive_choice_tile.dart';

import '../../../support/expressive_test_theme.dart';

Future<DiaryExportRequest? Function()> _open(
  WidgetTester tester, {
  int count = 3,
  DiaryExportOptions options = DiaryExportOptions.defaults,
  List<DiaryExportOptions>? changes,
  Brightness brightness = Brightness.light,
  bool isBook = false,
  bool commentsEnabled = false,
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
                isBook: isBook,
                commentsEnabled: commentsEnabled,
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

  testWidgets('format radio dots stay centered beside the descriptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _open(tester);

    final tiles = find.descendant(
      of: find.byType(ExpressiveChoiceTile),
      matching: find.byType(ListTile),
    );
    expect(tiles, findsNWidgets(DiaryExportFormat.values.length));
    for (var index = 0; index < DiaryExportFormat.values.length; index++) {
      final tile = tiles.at(index);
      final dot = find.descendant(of: tile, matching: find.byType(FaIcon));
      expect(
        (tester.getCenter(dot).dy - tester.getCenter(tile).dy).abs(),
        lessThan(0.5),
        reason: DiaryExportFormat.values[index].name,
      );
    }
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

  testWidgets('a book shows the book structure switch instead of the order', (
    tester,
  ) async {
    final changes = <DiaryExportOptions>[];
    final result = await _open(tester, isBook: true, changes: changes);

    // PDF：开关默认打开，带一行说明；书序决定先后，不显示排序。
    expect(find.text('书籍结构'), findsOneWidget);
    expect(find.text('扉页、目录与章节标题'), findsOneWidget);
    expect(find.text('从旧到新'), findsNothing);
    expect(
      tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '书籍结构'))
          .value,
      isTrue,
    );

    // 表格与日记文件不写结构，开关隐藏。
    await tester.scrollUntilVisible(
      find.text('表格（CSV）'),
      80,
      scrollable: _sheetScrollable(),
    );
    await tester.tap(find.text('表格（CSV）'));
    await tester.pumpAndSettle();
    expect(find.text('书籍结构'), findsNothing);
    expect(find.text('从旧到新'), findsNothing);
    await tester.tap(find.text('Jotsy 日记文件'));
    await tester.pumpAndSettle();
    expect(find.text('书籍结构'), findsNothing);

    await tester.tap(find.text('网页'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('书籍结构'),
      80,
      scrollable: _sheetScrollable(),
    );
    await tester.tap(find.text('书籍结构'));
    await tester.pumpAndSettle();
    // 开关只对本次有效，不写进导出选项。
    expect(changes.last.format, DiaryExportFormat.html);

    await tester.scrollUntilVisible(
      find.text('保存到文件'),
      80,
      scrollable: _sheetScrollable(),
    );
    await tester.tap(find.text('保存到文件'));
    await tester.pumpAndSettle();
    final request = result()!;
    expect(request.options.format, DiaryExportFormat.html);
    expect(request.bookStructure, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the comments switch follows the feature and the format', (
    tester,
  ) async {
    final changes = <DiaryExportOptions>[];
    await _open(
      tester,
      commentsEnabled: true,
      options: const DiaryExportOptions(format: DiaryExportFormat.text),
      changes: changes,
    );
    await tester.scrollUntilVisible(
      find.text('包含留言'),
      80,
      scrollable: _sheetScrollable(),
    );
    expect(
      tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '包含留言'))
          .value,
      isTrue,
    );
    await tester.tap(find.text('包含留言'));
    await tester.pumpAndSettle();
    expect(changes.last.includeComments, isFalse);

    // 表格本没有选项开关，开启留言后多出这一项；日记文件不提供。
    await tester.scrollUntilVisible(
      find.text('表格（CSV）'),
      80,
      scrollable: _sheetScrollable(),
    );
    await tester.tap(find.text('表格（CSV）'));
    await tester.pumpAndSettle();
    expect(find.text('包含留言'), findsOneWidget);
    await tester.tap(find.text('Jotsy 日记文件'));
    await tester.pumpAndSettle();
    expect(find.text('包含留言'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without the comments feature the switch never appears', (
    tester,
  ) async {
    await _open(
      tester,
      options: const DiaryExportOptions(format: DiaryExportFormat.text),
    );
    expect(find.text('包含心情、天气、地点与标签'), findsOneWidget);
    expect(find.text('包含留言'), findsNothing);
  });

  testWidgets('without a book the switch never appears', (tester) async {
    await _open(tester);
    expect(find.text('书籍结构'), findsNothing);
    expect(find.text('从旧到新'), findsOneWidget);
  });
}
