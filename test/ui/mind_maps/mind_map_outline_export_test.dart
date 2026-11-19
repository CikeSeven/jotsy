import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_ops.dart';
import 'package:node_diary/core/database/mind_map/mind_map_schema.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/export/diary_export_blocks.dart';
import 'package:node_diary/ui/mind_maps/controllers/mind_map_io_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

/// 大纲导出（#328）：中心主题是标题、其余主题为逐级缩进的列表并带文字
/// 样式与主题字号；PDF、Word、网页经日记导出的写出器生成，不写日期；纯文本
/// 与“复制为大纲文字”相同。
void main() {
  MindMapDocument outline() {
    final document = MindMapOps.replaceRoot(
      MindMapDocument.blank(),
      mindMapNodeFromOutline('Plan\n  Work\n    Ship\n  Rest')!,
    );
    final work = document.index.preorder.firstWhere(
      (id) => document.index[id]!.text == 'Work',
    );
    return MindMapOps.setStyle(
      MindMapOps.setStyle(document, work, kMindMapStyleSizeKey, 'l'),
      work,
      kMindMapStyleBoldKey,
      true,
    );
  }

  test('the outline blocks leave the root to the title and keep styles and '
      'topic sizes', () {
    final blocks = ExportBlockParser.parseMindMapOutline(outline());
    expect(
      blocks.map((block) => (block.kind, block.indent, block.plainText)),
      <(ExportBlockKind, int, String)>[
        (ExportBlockKind.bullet, 0, 'Work'),
        (ExportBlockKind.bullet, 1, 'Ship'),
        (ExportBlockKind.bullet, 0, 'Rest'),
      ],
    );
    final work = blocks.first.inlines.single;
    expect(work.bold, isTrue);
    expect(work.size, 'large');
    expect(blocks.last.inlines.single.size, isNull);
  });

  testWidgets('outline PDF, Word, web page and plain text are built without '
      'a date line', (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = (await tester.runAsync(SettingsService.create))!;
    final temporary = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('jotsy_outline_export_'),
    ))!;
    addTearDown(() => temporary.deleteSync(recursive: true));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => temporary.path,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      ),
    );
    late BuildContext context;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext built) {
              context = built;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    final map = outline();
    Future<List<int>> build(MindMapExportKind kind) async =>
        (await tester.runAsync(() => buildMindMapExport(context, map, kind)))!;

    final html = utf8.decode(await build(MindMapExportKind.html));
    expect(html, contains('<h1>Plan</h1>'));
    for (final topic in <String>['Work', 'Ship', 'Rest']) {
      expect(html, contains(topic));
    }
    expect(html, contains('font-size:1.25em'));
    expect(html, isNot(contains('<time')));

    final word = await build(MindMapExportKind.word);
    expect(String.fromCharCodes(word.sublist(0, 2)), 'PK');

    final pdf = await build(MindMapExportKind.outlinePdf);
    expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');

    final text = utf8.decode(await build(MindMapExportKind.text));
    expect(text, mindMapOutlineText(map, untitled: 'Untitled mind map'));
    expect(text, 'Plan\n- Work\n  - Ship\n- Rest');

    // 暂存都已删掉，不留在缓存目录里。
    final leftovers = (await tester.runAsync(
      () => temporary.list(recursive: true).where((e) => e is File).toList(),
    ))!;
    expect(leftovers, isEmpty);
  });
}
