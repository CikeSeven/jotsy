import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/controllers/data_management_controller.dart';
import 'package:node_diary/ui/settings/controllers/journal_import_controller.dart';
import 'package:node_diary/ui/settings/widgets/backup_import_folder_section.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_test_fixture.dart';
import '../../support/expressive_test_theme.dart';

/// 从其他日记应用导入、来源带日记本时：日记本功能关闭则不询问落地方式，
/// 来源日记本名一律落成标签，也不改写记住的选择；开启时照常询问。
void main() {
  late BackupTestFixture fixture;
  late FilePicker originalPicker;

  setUpAll(() {
    try {
      originalPicker = FilePicker.platform;
    } catch (_) {
      originalPicker = _FakePicker('');
    }
  });
  tearDown(() => FilePicker.platform = originalPicker);

  /// 两个日记本的 Day One 导出（只有一本时不记日记本）。
  Future<String> twoJournalsZip() async {
    final archive = Archive();
    for (final (name, keys) in [
      ('Travel', ['T1', 'T2']),
      ('Work', ['W1']),
    ]) {
      final bytes = utf8.encode(
        jsonEncode({
          'entries': [
            for (final (index, key) in keys.indexed)
              {
                'uuid': key,
                'creationDate': '2024-05-0${index + 1}T08:00:00Z',
                'text': key,
              },
          ],
        }),
      );
      archive.addFile(ArchiveFile('$name.json', bytes.length, bytes));
    }
    final file = File(p.join(fixture.temporary.path, 'journals.zip'));
    await file.writeAsBytes(ZipEncoder().encode(archive)!);
    return file.path;
  }

  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(done(), isTrue);
  }

  Future<_HostState> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(fixture.database),
          settingsServiceProvider.overrideWith((ref) async => fixture.settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const _Host(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state<_HostState>(find.byType(_Host));
  }

  // 两种情况在同一个测试里依次跑：导入经 `DataArchiveService` 的静态串行
  // 队列，在上一个测试的假时钟区里完成的 Future 到下一个测试里不会再推进。
  testWidgets('off lands source journals as tags without asking; on asks', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    for (final enabled in <bool>[false, true]) {
      fixture = (await tester.runAsync(BackupTestFixture.create))!;
      final zip = (await tester.runAsync(twoJournalsZip))!;
      FilePicker.platform = _FakePicker(zip);
      if (!enabled) {
        await fixture.settings.setAppFeaturesRaw('{"notebooks":false}');
      }
      final host = await pumpHost(tester);

      await tester.tap(find.text('import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Day One'));
      await waitFor(
        tester,
        () => find.text(l10n.dataMgmtImportAction).evaluate().isNotEmpty,
      );

      expect(
        find.byType(BackupImportFolderSection),
        enabled ? findsOneWidget : findsNothing,
        reason: 'enabled: $enabled',
      );
      await tester.tap(find.text(l10n.dataMgmtImportAction));
      await waitFor(tester, () => host.snacks.isNotEmpty);

      final (notebooks, tags) = (await tester.runAsync(
        () async => (
          await fixture.database.getNotebooks(),
          await fixture.database.select(fixture.database.tags).get(),
        ),
      ))!;
      if (enabled) {
        expect(notebooks.map((row) => row.name).toSet(), {'Travel', 'Work'});
        expect(tags, isEmpty);
      } else {
        expect(notebooks, isEmpty);
        expect(tags.map((tag) => tag.name).toSet(), {'Travel', 'Work'});
      }
      // 记住的选择不受这次（按标签）导入影响。
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(_Host)),
        ).read(journalImportFolderModeProvider),
        JournalImportFolderMode.notebooks,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
      await tester.runAsync(fixture.dispose);
    }
  });
}

class _FakePicker extends FilePicker {
  _FakePicker(this.path);

  final String path;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult(<PlatformFile>[
    PlatformFile(name: p.basename(path), size: 0, path: path),
  ]);
}

class _Host extends ConsumerStatefulWidget {
  const _Host();

  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> implements DataManagementHost {
  final List<String> snacks = <String>[];
  bool _busy = false;

  @override
  bool get busy => _busy;

  @override
  void setBusy(bool busy, [String text = '']) => _busy = busy;

  @override
  void showSnack(String message) => snacks.add(message);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => JournalImportController(this).importFromApp(),
          child: const Text('import'),
        ),
      ),
    );
  }
}
