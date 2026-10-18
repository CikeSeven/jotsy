import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_settings.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_share_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 预览页“更多 → 分享”：打开分享面板，复制文字后给出提示，内容开关被记住；
/// 顶栏分享按钮打开同一个面板。
void main() {
  late AppDatabase database;
  late String diaryId;
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    diaryId = await database.createDiary(
      title: '春日小记',
      contentDocJson: '[{"insert":"看花\\n"}]',
      contentText: '看花',
      metadataJson: '{"context":{"location":"杭州西湖"}}',
    );
  });
  tearDown(() => database.close());

  Future<void> pumpPreview(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
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
  }

  testWidgets('More → Share copies the composed text and remembers toggles', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpPreview(tester);

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分享'));
    await tester.pumpAndSettle();
    expect(find.text('分享日记'), findsOneWidget);

    // 地点默认不带；打开后写入设置，下次打开沿用。预览页正文下方本身也
    // 显示地点，只看面板里的文字预览。
    final preview = find.descendant(
      of: find.byType(DiaryShareTextPreview),
      matching: find.textContaining('杭州西湖'),
    );
    expect(preview, findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, '地点'));
    await tester.pumpAndSettle();
    expect(preview, findsOneWidget);

    await tester.tap(find.bySemanticsLabel('复制文字'));
    await tester.pumpAndSettle();

    expect(find.text('分享日记'), findsNothing);
    expect(copied, hasLength(1));
    expect(copied.single, startsWith('春日小记\n\n看花\n\n'));
    expect(copied.single, endsWith('杭州西湖'));
    expect(find.text('已复制到剪贴板'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('app.settings.diary_share_options'),
      contains('"location":true'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('top bar share button opens the share sheet, not a long image', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.diary_preview_style': const DiaryPreviewSettings(
        current: DiaryPreviewStyle(
          page: DiaryPreviewPageStyle(showShareButton: true),
        ),
      ).encode()!,
    });
    await pumpPreview(tester);

    await tester.tap(find.byTooltip('分享'));
    await tester.pumpAndSettle();
    expect(find.text('分享日记'), findsOneWidget);
    expect(find.byType(DiaryShareTextPreview), findsOneWidget);
    // 长图只在面板里选了才生成，点按钮本身不截图（截图期间遮罩写“分享图片”）。
    expect(find.text('分享图片'), findsNothing);

    // 不选任何方式就关掉面板：什么也不执行，页面恢复可用。
    Navigator.of(tester.element(find.text('分享日记'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('分享日记'), findsNothing);
    expect(find.text('分享图片'), findsNothing);
    expect(find.text('正在准备分享'), findsNothing);

    // 再点一次仍能打开（上一次没有留下忙碌态）。
    await tester.tap(find.byTooltip('分享'));
    await tester.pumpAndSettle();
    expect(find.text('分享日记'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
