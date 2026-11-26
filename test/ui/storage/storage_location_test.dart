import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/app_root_shell.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_data_location.dart';
import 'package:node_diary/core/services/app_data_location_migrator.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/lan_sync/controllers/inert_lan_sync_ui_controller.dart';
import 'package:node_diary/ui/lan_sync/providers/lan_sync_providers.dart';
import 'package:node_diary/ui/storage/pages/storage_page.dart';
import 'package:node_diary/ui/storage/providers/storage_providers.dart';
import 'package:node_diary/ui/storage/sections/storage_location_card.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';
import '../../support/storage_test_fixtures.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('zh'));

class _FakeRelocationHost implements AppDataRelocationHost {
  int callCount = 0;
  String? lastNotice;
  AppDataMigrationResult? lastResult;
  Object? lastError;

  @override
  Future<void> relocate({
    required ThemeMode themeMode,
    required Locale locale,
    required Color seedColor,
    required Future<AppDataMigrationResult> Function(
      void Function(AppDataMigrationProgress progress) onProgress,
    )
    task,
    required String Function(
      AppLocalizations l10n,
      AppDataMigrationResult result,
    )
    successNotice,
    required String Function(AppLocalizations l10n, Object error) failureNotice,
  }) async {
    callCount++;
    try {
      final result = await task((_) {});
      lastResult = result;
      lastNotice = successNotice(_l10n, result);
    } on Object catch (error) {
      lastError = error;
      lastNotice = failureNotice(_l10n, error);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory tempRoot;
  late Directory supportDir;
  late Directory exeDir;
  late AppDataLocationStore store;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('jotsy_storage_ui_test_');
    supportDir = Directory(p.join(tempRoot.path, 'support'))..createSync();
    exeDir = Directory(p.join(tempRoot.path, 'app'))..createSync();
    store = AppDataLocationStore(
      supportDirectoryProvider: () async => supportDir,
      executableDirectoryProvider: () => exeDir,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  Future<void> runWithPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> waitUntil(
    WidgetTester tester,
    bool Function() condition, {
    String Function()? describeFailure,
  }) async {
    for (var i = 0; i < 160 && !condition(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 25));
    }
    if (!condition()) {
      fail('Timed out waiting for condition: ${describeFailure?.call() ?? ''}');
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpLocationStoragePage(
    WidgetTester tester, {
    required bool expectDesktopCard,
    Brightness brightness = Brightness.light,
    Size size = const Size(500, 2400),
    String? pickedPath,
    Future<bool> Function(String path)? onOpenFolder,
    _FakeRelocationHost? host,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final settings = await SettingsService.create();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final service = FakeStorageMediaService(
      sampleStorageReport(withReclaimable: false),
      supportsCompression: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
          appDatabaseProvider.overrideWith((ref) {
            ref.onDispose(db.close);
            return db;
          }),
          lanSyncControllerProvider.overrideWithValue(
            InertLanSyncUiController(),
          ),
          storageMediaServiceProvider.overrideWithValue(service),
          storageLocationStoreProvider.overrideWithValue(store),
          storageDirectoryPickerProvider.overrideWithValue(
            ({required String dialogTitle}) async => pickedPath,
          ),
          storageFolderOpenerProvider.overrideWithValue(
            onOpenFolder ?? (_) async => true,
          ),
          if (host != null)
            appDataRelocationHostProvider.overrideWithValue(host),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(brightness),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StoragePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (expectDesktopCard) {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(StoragePage)),
      );
      await waitUntil(
        tester,
        () => container.read(storageLocationProvider).hasValue,
      );
    }
  }

  Future<void> scrollToCard(WidgetTester tester) async {
    if (find.byType(StorageLocationCard).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.byType(StorageLocationCard),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('hides StorageLocationCard on mobile platforms', (tester) async {
    await runWithPlatform(TargetPlatform.android, () async {
      await pumpLocationStoragePage(tester, expectDesktopCard: false);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(StorageLocationCard), findsNothing);
      expect(find.text(_l10n.storageLocationTitle), findsNothing);
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'renders desktop StorageLocationCard cleanly at 320dp in $brightness',
      (tester) async {
        await runWithPlatform(TargetPlatform.windows, () async {
          await pumpLocationStoragePage(
            tester,
            expectDesktopCard: true,
            brightness: brightness,
            size: const Size(320, 820),
          );
          await scrollToCard(tester);

          expect(find.byType(StorageLocationCard), findsOneWidget);
          expect(find.text(_l10n.storageLocationTitle), findsOneWidget);
          expect(find.text(_l10n.storageLocationDefaultBadge), findsOneWidget);
          expect(find.text(p.normalize(supportDir.path)), findsOneWidget);
          // Reset button is hidden when already using the default directory.
          expect(find.text(_l10n.storageLocationResetDefault), findsNothing);
          expect(tester.takeException(), isNull);
        });
      },
    );
  }

  testWidgets('open folder invokes opener with active directory path', (
    tester,
  ) async {
    await runWithPlatform(TargetPlatform.windows, () async {
      String? openedPath;
      await pumpLocationStoragePage(
        tester,
        expectDesktopCard: true,
        onOpenFolder: (String path) async {
          openedPath = path;
          return true;
        },
      );
      await scrollToCard(tester);
      await tester.tap(find.text(_l10n.storageLocationOpenFolder));
      await tester.pumpAndSettle();

      expect(openedPath, p.normalize(supportDir.path));
    });
  });

  testWidgets(
    'shows validation dialog when picked folder has unrelated files',
    (tester) async {
      await runWithPlatform(TargetPlatform.windows, () async {
        final nonEmpty = Directory(p.join(tempRoot.path, 'non_empty'))
          ..createSync();
        File(p.join(nonEmpty.path, 'other.txt')).writeAsStringSync('x');

        await pumpLocationStoragePage(
          tester,
          expectDesktopCard: true,
          pickedPath: nonEmpty.path,
        );
        await scrollToCard(tester);
        await tester.tap(find.text(_l10n.storageLocationChangeButton));
        await waitUntil(
          tester,
          () => find
              .text(_l10n.storageLocationInvalidTitle)
              .evaluate()
              .isNotEmpty,
        );

        expect(find.text(_l10n.storageLocationInvalidTitle), findsOneWidget);
        expect(find.text(_l10n.storageLocationErrorNotEmpty), findsOneWidget);
      });
    },
  );

  testWidgets('blocks relocation when an editing session is active', (
    tester,
  ) async {
    await runWithPlatform(TargetPlatform.windows, () async {
      final targetDir = Directory(p.join(tempRoot.path, 'empty_target'))
        ..createSync();
      final lease = EditingSessionRegistry.instance.beginEditing('test_editor');
      addTearDown(lease.end);

      final host = _FakeRelocationHost();
      await pumpLocationStoragePage(
        tester,
        expectDesktopCard: true,
        pickedPath: targetDir.path,
        host: host,
      );
      await scrollToCard(tester);
      await tester.tap(find.text(_l10n.storageLocationChangeButton));
      await waitUntil(
        tester,
        () => find.text(_l10n.storageMgmtBusyEditing).evaluate().isNotEmpty,
        describeFailure: () => 'busyEditing snackbar missing',
      );

      expect(host.callCount, 0);
      expect(find.text(_l10n.storageMgmtBusyEditing), findsOneWidget);
    });
  });

  testWidgets(
    'confirming valid empty folder runs migration via relocation host',
    (tester) async {
      await runWithPlatform(TargetPlatform.windows, () async {
        final targetDir = Directory(p.join(tempRoot.path, 'new_target'))
          ..createSync();
        File(p.join(supportDir.path, 'diary_images', 'a.jpg'))
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(<int>[1, 2, 3]);

        final host = _FakeRelocationHost();
        await pumpLocationStoragePage(
          tester,
          expectDesktopCard: true,
          pickedPath: targetDir.path,
          host: host,
        );
        await scrollToCard(tester);
        await tester.tap(find.text(_l10n.storageLocationChangeButton));
        await waitUntil(
          tester,
          () => find
              .text(_l10n.storageLocationConfirmMigrateAction)
              .evaluate()
              .isNotEmpty,
        );

        await tester.tap(find.text(_l10n.storageLocationConfirmMigrateAction));
        await waitUntil(
          tester,
          () => host.callCount > 0 && host.lastNotice != null,
        );

        expect(host.callCount, 1);
        expect(host.lastError, isNull);
        expect(
          p.normalize(host.lastResult!.targetRoot.path),
          p.normalize(targetDir.path),
        );
        expect(
          host.lastNotice,
          _l10n.storageLocationMigratedNotice(p.normalize(targetDir.path)),
        );
        expect(
          File(p.join(targetDir.path, 'diary_images', 'a.jpg')).existsSync(),
          isTrue,
        );
      });
    },
  );

  testWidgets(
    'selecting folder with existing database switches without deleting source',
    (tester) async {
      await runWithPlatform(TargetPlatform.windows, () async {
        final existingTarget = Directory(p.join(tempRoot.path, 'existing_root'))
          ..createSync();
        await tester.runAsync(() async {
          final db = AppDatabase.openFile(
            File(p.join(existingTarget.path, appDatabaseFileName)),
          );
          await db.customSelect('SELECT 1').get();
          await db.close();
        });

        final host = _FakeRelocationHost();
        await pumpLocationStoragePage(
          tester,
          expectDesktopCard: true,
          pickedPath: existingTarget.path,
          host: host,
        );
        await scrollToCard(tester);
        await tester.tap(find.text(_l10n.storageLocationChangeButton));
        await waitUntil(
          tester,
          () => find
              .text(_l10n.storageLocationConfirmSwitchAction)
              .evaluate()
              .isNotEmpty,
        );

        expect(
          find.text(_l10n.storageLocationConfirmSwitchTitle),
          findsOneWidget,
        );
        await tester.tap(find.text(_l10n.storageLocationConfirmSwitchAction));
        await waitUntil(
          tester,
          () => host.callCount > 0 && host.lastNotice != null,
          describeFailure: () =>
              'switch relocate: calls=${host.callCount}, err=${host.lastError}, notice=${host.lastNotice}',
        );

        expect(host.callCount, 1);
        expect(host.lastError, isNull);
        expect(
          host.lastNotice,
          _l10n.storageLocationSwitchedNotice(p.normalize(existingTarget.path)),
        );
        final resolved = await tester.runAsync(store.resolve);
        expect(
          p.normalize(resolved!.activeRoot.path),
          p.normalize(existingTarget.path),
        );
      });
    },
  );

  testWidgets('shows Reset to default action for custom location and confirms', (
    tester,
  ) async {
    await runWithPlatform(TargetPlatform.windows, () async {
      final customRoot = Directory(p.join(tempRoot.path, 'custom_root'))
        ..createSync();
      await tester.runAsync(
        () => store.saveUserConfig(
          supportDir: supportDir,
          targetPath: customRoot.path,
        ),
      );

      final host = _FakeRelocationHost();
      await pumpLocationStoragePage(
        tester,
        expectDesktopCard: true,
        host: host,
      );
      await scrollToCard(tester);

      expect(find.text(_l10n.storageLocationCustomBadge), findsOneWidget);
      expect(find.text(_l10n.storageLocationResetDefault), findsOneWidget);

      await tester.tap(find.text(_l10n.storageLocationResetDefault));
      await waitUntil(
        tester,
        () => find
            .text(_l10n.storageLocationConfirmResetTitle)
            .evaluate()
            .isNotEmpty,
      );

      await tester.tap(find.text(_l10n.storageLocationConfirmMigrateAction));
      await waitUntil(
        tester,
        () => host.callCount > 0 && host.lastNotice != null,
        describeFailure: () =>
            'reset relocate: calls=${host.callCount}, err=${host.lastError}, notice=${host.lastNotice}',
      );

      expect(host.callCount, 1);
      expect(host.lastError, isNull);
      final resolved = await tester.runAsync(store.resolve);
      expect(
        p.normalize(resolved!.activeRoot.path),
        p.normalize(supportDir.path),
      );
    });
  });
}
