import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/controllers/backup_import_flow.dart';
import 'package:node_diary/ui/settings/widgets/backup_overwrite_warning_dialog.dart';
import 'package:node_diary/ui/widgets/expressive_choice_tile.dart';

import '../../support/expressive_test_theme.dart';

const _diaryFile = BackupArchivePreview(
  kind: BackupArchiveKind.diaryPackage,
  diaryCount: 1,
  tagCount: 2,
  existingDiaryCount: 0,
  localDiaryCount: 12,
  localTagCount: 4,
  soleDiaryTitle: '春日小记',
);

const _fullBackup = BackupArchivePreview(
  kind: BackupArchiveKind.fullBackup,
  diaryCount: 30,
  tagCount: 6,
  existingDiaryCount: 3,
  localDiaryCount: 12,
  localTagCount: 4,
);

const _dayOneExport = BackupArchivePreview(
  kind: BackupArchiveKind.journalExport,
  journalSource: JournalImportSource.dayOne,
  diaryCount: 40,
  tagCount: 5,
  existingDiaryCount: 2,
  localDiaryCount: 12,
  localTagCount: 4,
  missingMediaCount: 3,
);

const _cloudNotes = BackupArchivePreview(
  kind: BackupArchiveKind.journalExport,
  journalSource: JournalImportSource.wpsNotes,
  diaryCount: 18,
  tagCount: 2,
  existingDiaryCount: 0,
  localDiaryCount: 12,
  localTagCount: 4,
  skippedNotes: {
    JournalSkipReason.unreadable: 1,
    JournalSkipReason.encrypted: 2,
    JournalSkipReason.unsupported: 3,
  },
  summaryOnlyCount: 1,
  partialContentCount: 2,
);

class _FlowResult {
  BackupImportMode? mode;
  bool finished = false;
}

/// 点按按钮走一遍 [chooseBackupImportMode]，记录最终返回的导入方式。
Future<_FlowResult> _startFlow(
  WidgetTester tester,
  BackupArchivePreview preview, {
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final result = _FlowResult();
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
              onPressed: () async {
                result.mode = await chooseBackupImportMode(context, preview);
                result.finished = true;
              },
              child: const Text('start'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('start'));
  await tester.pumpAndSettle();
  return result;
}

TextButton _button(WidgetTester tester, String label) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, label));

Future<void> _waitForCountdown(WidgetTester tester) async {
  for (
    var second = 0;
    second < backupOverwriteConfirmDelay.inSeconds;
    second++
  ) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets(
    'a diary file without duplicates only offers merging and skips the warning',
    (tester) async {
      final result = await _startFlow(tester, _diaryFile);

      expect(find.text('日记文件'), findsOneWidget);
      expect(find.text('春日小记'), findsOneWidget);
      expect(find.text('1 篇日记 · 2 个标签'), findsOneWidget);
      expect(find.text('包含应用设置'), findsNothing);
      // 只有合并一种方式时不画单选列表，直接说明合并的效果。
      expect(find.byType(ExpressiveChoiceTile), findsNothing);
      expect(find.text('保留本机全部数据，只添加本机没有的日记，已存在的日记保持不变'), findsOneWidget);

      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();
      expect(result.finished, isTrue);
      expect(result.mode, BackupImportMode.merge);
      expect(find.byType(BackupOverwriteWarningDialog), findsNothing);
    },
  );

  testWidgets(
    'overwriting everything needs the acknowledgement and the countdown',
    (tester) async {
      final result = await _startFlow(tester, _fullBackup);

      expect(find.text('完整备份'), findsOneWidget);
      expect(find.text('包含应用设置'), findsOneWidget);
      expect(find.text('其中 3 篇本机已存在'), findsOneWidget);
      expect(find.byType(ExpressiveChoiceTile), findsNWidgets(3));
      // 默认停在最安全的合并上。
      expect(
        tester
            .widget<ListTile>(
              find.ancestor(
                of: find.text('合并（推荐）'),
                matching: find.byType(ListTile),
              ),
            )
            .selected,
        isTrue,
      );

      await tester.tap(find.text('覆盖全部数据'));
      await tester.pumpAndSettle();
      // 改写本机数据的方式只进入下一步，按钮换成“继续”。
      expect(find.text('导入'), findsNothing);
      await tester.tap(find.text('继续'));
      await tester.pumpAndSettle();

      expect(find.byType(BackupOverwriteWarningDialog), findsOneWidget);
      expect(find.text('覆盖全部数据？'), findsOneWidget);
      expect(find.text('此操作无法撤销'), findsOneWidget);
      expect(find.text('12 篇日记（含归档与回收站）'), findsOneWidget);
      expect(find.text('4 个标签'), findsOneWidget);
      expect(_button(tester, '确认覆盖（5）').onPressed, isNull);

      // 倒计时结束但未勾选“我已了解”，仍不能确认。
      await _waitForCountdown(tester);
      expect(_button(tester, '确认覆盖').onPressed, isNull);

      await tester.tap(find.text('我已了解被覆盖的数据无法恢复'));
      await tester.pump();
      expect(_button(tester, '确认覆盖').onPressed, isNotNull);
      await tester.tap(find.text('确认覆盖'));
      await tester.pumpAndSettle();
      expect(result.mode, BackupImportMode.replaceAll);
    },
  );

  testWidgets('acknowledging early still waits for the countdown', (
    tester,
  ) async {
    await _startFlow(tester, _fullBackup);
    await tester.tap(find.text('覆盖已存在的日记'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(find.text('覆盖已存在的日记？'), findsOneWidget);
    expect(
      find.text('本机已存在的 3 篇日记将被文件中的版本整篇替换，它们在本机上的修改与标签都会永久丢失。其他日记不受影响。'),
      findsOneWidget,
    );
    await tester.tap(find.text('我已了解被覆盖的数据无法恢复'));
    await tester.pump(const Duration(seconds: 1));
    expect(_button(tester, '确认覆盖（4）').onPressed, isNull);
    await _waitForCountdown(tester);
    expect(_button(tester, '确认覆盖').onPressed, isNotNull);
  });

  testWidgets(
    "another app's export names its source and never replaces everything",
    (tester) async {
      final result = await _startFlow(tester, _dayOneExport);

      expect(find.text('Day One 导出'), findsOneWidget);
      expect(find.text('40 篇日记 · 5 个标签'), findsOneWidget);
      expect(find.text('其中 2 篇本机已存在'), findsOneWidget);
      expect(find.text('3 个媒体文件不在导出中，将跳过'), findsOneWidget);
      expect(find.text('包含应用设置'), findsNothing);
      // 再次导入同一导出时可以覆盖之前导入的日记，但不能清空本机数据。
      expect(find.byType(ExpressiveChoiceTile), findsNWidgets(2));
      expect(find.text('覆盖全部数据'), findsNothing);

      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();
      expect(result.mode, BackupImportMode.merge);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('lists skipped and summary-only cloud notes in $brightness', (
      tester,
    ) async {
      await _startFlow(
        tester,
        _cloudNotes,
        brightness: brightness,
        size: const Size(320, 640),
      );

      const lines = [
        '2 篇加密或上锁的笔记读不到，将跳过',
        '3 篇手写、思维导图等专有格式的笔记将跳过',
        '1 篇笔记的格式无法识别，将跳过',
        '1 篇笔记的正文没能读取，只导入摘要',
        '2 篇笔记含无法解密或显示的片段，可读正文与原始信息将保留',
      ];
      // 按原因的固定顺序排列，与平台记下的先后无关。
      final tops = [
        for (final line in lines) tester.getTopLeft(find.text(line)).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('nothing about skipped notes when none were skipped', (
    tester,
  ) async {
    await _startFlow(tester, _dayOneExport);
    expect(find.textContaining('将跳过'), findsOneWidget); // 只有缺失媒体那一行
    expect(find.textContaining('只导入摘要'), findsNothing);
  });

  testWidgets('cancelling the warning imports nothing', (tester) async {
    final result = await _startFlow(tester, _fullBackup);
    await tester.tap(find.text('覆盖已存在的日记'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result.finished, isTrue);
    expect(result.mode, isNull);
    expect(find.byType(BackupOverwriteWarningDialog), findsNothing);
  });

  testWidgets('cancelling the import options imports nothing', (tester) async {
    final result = await _startFlow(tester, _fullBackup);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result.finished, isTrue);
    expect(result.mode, isNull);
  });

  testWidgets('radio dots stay centered beside wrapping descriptions', (
    tester,
  ) async {
    await _startFlow(tester, _fullBackup, size: const Size(320, 640));
    final tiles = find.descendant(
      of: find.byType(ExpressiveChoiceTile),
      matching: find.byType(ListTile),
    );
    expect(tiles, findsNWidgets(3));
    for (var index = 0; index < 3; index++) {
      final tile = tiles.at(index);
      final dot = find.descendant(of: tile, matching: find.byType(FaIcon));
      expect(
        (tester.getCenter(dot).dy - tester.getCenter(tile).dy).abs(),
        lessThan(0.5),
        reason: 'option $index',
      );
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('options and warning fit a 320dp phone in $brightness', (
      tester,
    ) async {
      await _startFlow(
        tester,
        _fullBackup,
        brightness: brightness,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('覆盖全部数据'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('继续'));
      await tester.pumpAndSettle();
      expect(find.byType(BackupOverwriteWarningDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _waitForCountdown(tester);
    });
  }

  test('describes import results by mode', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    String describe(
      BackupImportMode mode,
      int added,
      int replaced,
      int skipped,
    ) => describeBackupImportResult(
      l10n,
      BackupImportResult(
        mode: mode,
        addedDiaries: added,
        replacedDiaries: replaced,
        skippedDiaries: skipped,
      ),
      replaceAllMessage: 'restored',
    );

    expect(describe(BackupImportMode.merge, 2, 0, 0), '导入完成：新增 2 篇日记');
    expect(
      describe(BackupImportMode.merge, 0, 0, 1),
      '导入完成：新增 0 篇，跳过 1 篇本机已存在的日记',
    );
    expect(
      describe(BackupImportMode.mergeOverwrite, 1, 3, 0),
      '导入完成：新增 1 篇，覆盖 3 篇日记',
    );
    expect(describe(BackupImportMode.replaceAll, 30, 0, 0), 'restored');
  });

  test('adds an anniversary line when the file had anniversaries', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    String describe(BackupImportMode mode, int added, int replaced, int skip) =>
        describeBackupImportResult(
          l10n,
          BackupImportResult(
            mode: mode,
            addedDiaries: 1,
            replacedDiaries: 0,
            skippedDiaries: 0,
            addedAnniversaries: added,
            replacedAnniversaries: replaced,
            skippedAnniversaries: skip,
          ),
          replaceAllMessage: 'restored',
        );

    expect(
      describe(BackupImportMode.merge, 2, 0, 0),
      '导入完成：新增 1 篇日记\n纪念日：新增 2 个',
    );
    expect(
      describe(BackupImportMode.merge, 0, 0, 3),
      '导入完成：新增 1 篇日记\n纪念日：新增 0 个，跳过 3 个本机已存在的',
    );
    expect(
      describe(BackupImportMode.mergeOverwrite, 1, 2, 0),
      '导入完成：新增 1 篇，覆盖 0 篇日记\n纪念日：新增 1 个，覆盖 2 个',
    );
    expect(describe(BackupImportMode.merge, 0, 0, 0), '导入完成：新增 1 篇日记');
    expect(describe(BackupImportMode.replaceAll, 5, 0, 0), 'restored');
  });
}
