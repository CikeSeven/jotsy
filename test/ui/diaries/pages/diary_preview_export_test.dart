import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_typography_provider.dart';
import 'package:node_diary/ui/diaries/sections/diary_export_sheet.dart';
import 'package:node_diary/ui/widgets/action_loading_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 预览页“更多 → 导出”：经共用导出面板选择格式，日记文件先询问可选密码，
/// 其他格式生成后交给系统分享或保存。
void main() {
  late AppDatabase database;
  late String diaryId;
  late Directory temp;
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    diaryId = await database.createDiary(
      title: '春日小记',
      contentDocJson: '[{"insert":"看花\\n"}]',
      contentText: '看花',
      metadataJson: '{}',
      createdAtOverride: DateTime(2026, 4, 3, 9),
    );
    temp = await Directory.systemTemp.createTemp('preview_export_');
  });
  tearDown(() async {
    await database.close();
    await temp.delete(recursive: true);
  });

  Future<void> openExportSheet(
    WidgetTester tester, {
    DiaryTypography? typography,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          if (typography != null)
            diaryTypographyProvider.overrideWithValue(typography),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiaryPreviewPage(diaryId: diaryId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出'));
    await tester.pumpAndSettle();
    expect(find.text('导出日记'), findsOneWidget);
    expect(find.text('共 1 篇'), findsOneWidget);
  }

  Future<void> tapInSheet(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      80,
      scrollable: find
          .descendant(
            of: find.byType(DiaryExportSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  List<String> recordShares(WidgetTester tester) {
    final shared = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathProvider, (MethodCall call) async {
      return call.method == 'getTemporaryDirectory' ? temp.path : null;
    });
    messenger.setMockMethodCallHandler(shareChannel, (MethodCall call) async {
      final arguments = call.arguments as Map<Object?, Object?>;
      shared.addAll((arguments['paths'] as List<Object?>).whereType<String>());
      return 'success';
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathProvider, null);
      messenger.setMockMethodCallHandler(shareChannel, null);
    });
    return shared;
  }

  Future<void> shareInSheet(WidgetTester tester, List<String> shared) async {
    // 文件生成走真实 IO；同时推进虚拟帧时间，让生成结束后的遮罩淡出
    // 定时器也能完成，才能交给系统分享（只有真实延时不会推进测试时钟）。
    await tester.runAsync(() async {
      await tapInSheet(tester, '分享');
      for (var i = 0; i < 50 && shared.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(
      shared,
      hasLength(1),
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data)
          .join('\n'),
    );
  }

  testWidgets('a diary file asks for an optional password before exporting', (
    tester,
  ) async {
    await openExportSheet(tester);
    await tapInSheet(tester, 'Jotsy 日记文件');
    await tapInSheet(tester, '保存到文件');

    // 与完整备份导出同一个密码弹窗，确认键换成“导出”。
    expect(find.text('设置导出密码（可选）'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '导出'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(find.text('设置导出密码（可选）'), findsNothing);
    expect(find.byType(ActionLoadingOverlay), findsWidgets);
    expect(
      tester
          .widgetList<ActionLoadingOverlay>(find.byType(ActionLoadingOverlay))
          .every((ActionLoadingOverlay overlay) => !overlay.visible),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'plain text is generated and handed to the share sheet by file name',
    (tester) async {
      final shared = recordShares(tester);

      await openExportSheet(tester);
      await tapInSheet(tester, '纯文本');
      await shareInSheet(tester, shared);
      expect(shared.single, endsWith('2026-04-03 0900 春日小记.txt'));
      final text = await tester.runAsync(
        () => File(shared.single).readAsString(),
      );
      expect(text, startsWith('春日小记\n'));
      expect(text, contains('看花'));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('Word export uses the current body typography from the preview', (
    tester,
  ) async {
    final shared = recordShares(tester);
    await openExportSheet(
      tester,
      typography: const DiaryTypography(
        fontSize: 20,
        lineHeight: 2,
        letterSpacing: 1,
        paragraphSpacing: 16,
      ),
    );
    await tapInSheet(tester, 'Word 文档');
    await shareInSheet(tester, shared);
    expect(shared.single, endsWith('.docx'));
    final bytes = await tester.runAsync(
      () => File(shared.single).readAsBytes(),
    );
    final styles = ZipDecoder()
        .decodeBytes(bytes!)
        .files
        .singleWhere((f) => f.name == 'word/styles.xml');
    final xml = utf8.decode(styles.content as List<int>);
    expect(
      xml,
      contains('<w:spacing w:after="240" w:line="480" w:lineRule="auto"/>'),
    );
    expect(xml, contains('<w:spacing w:val="15"/><w:sz w:val="30"/>'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
