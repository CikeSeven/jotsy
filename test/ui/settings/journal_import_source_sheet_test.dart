import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/widgets/journal_import_source_sheet.dart';

import '../../support/expressive_test_theme.dart';

/// 点按按钮打开来源面板，返回选中的来源（取消为 null）。
Future<List<JournalImportSource?>> _open(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final picked = <JournalImportSource?>[];
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      theme: expressiveTestTheme(brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async =>
                  picked.add(await showJournalImportSourceSheet(context)),
              child: const Text('start'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('start'));
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  testWidgets('lists every supported app, grouped, with how to export it', (
    tester,
  ) async {
    final picked = await _open(tester);

    expect(find.text('从哪个应用导入？'), findsOneWidget);
    for (final title in ['日记应用', '笔记应用', '手机与 WPS 云笔记']) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    for (final name in [
      'Day One',
      'Journey',
      'Diarium',
      'Daylio',
      'Apple 手记',
      'Diaro',
      '印象笔记 / Evernote',
      'Google Keep',
      'Joplin',
      'Memos',
      'Markdown / 纯文本',
      '小米笔记',
      '华为备忘录',
      'OPPO 笔记',
      'vivo 笔记',
      '荣耀笔记',
      '魅族笔记',
      'WPS 便签',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('备份文件（.daylio）或导出的 CSV（.csv）'), findsOneWidget);
    expect(find.textContaining('在应用内登录官方云服务'), findsOneWidget);

    await tester.tap(find.text('Apple 手记'));
    await tester.pumpAndSettle();
    expect(picked, [JournalImportSource.appleJournal]);
  });

  testWidgets('picks a phone cloud note source from the compact grid', (
    tester,
  ) async {
    final picked = await _open(tester);

    await tester.ensureVisible(find.text('华为备忘录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('华为备忘录'));
    await tester.pumpAndSettle();

    expect(picked, [JournalImportSource.huaweiNotepad]);
  });

  testWidgets('hides phone cloud notes where sign-in is unavailable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await _open(tester);
      expect(find.text('手机与 WPS 云笔记'), findsNothing);
      expect(find.text('小米笔记'), findsNothing);
      expect(find.text('Day One'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('dismissing the sheet picks nothing', (tester) async {
    final picked = await _open(tester);
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
    expect(picked, [null]);
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits a 320dp phone in $brightness', (tester) async {
      await _open(tester, brightness: brightness, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      expect(find.text('Daylio'), findsOneWidget);
      await tester.ensureVisible(find.text('WPS 便签'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
