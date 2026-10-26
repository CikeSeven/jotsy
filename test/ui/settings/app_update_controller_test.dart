import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/app_update_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/settings/controllers/app_update_controller.dart';
import 'package:node_diary/ui/settings/models/app_update_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAppUpdateService service;
  late SettingsService settings;
  late ProviderContainer container;
  var now = DateTime(2026, 10, 20, 9);

  Future<void> setUpContainer({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    settings = await SettingsService.create();
    container = ProviderContainer(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
        appUpdateServiceProvider.overrideWithValue(service),
        appUpdateClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
  }

  AppUpdateController controller() =>
      container.read(appUpdateControllerProvider.notifier);
  AppUpdateState state() => container.read(appUpdateControllerProvider);
  AppUpdatePreferences stored() =>
      AppUpdatePreferences.decode(settings.appUpdatePreferencesRaw);

  setUp(() {
    service = FakeAppUpdateService();
    now = DateTime(2026, 10, 20, 9);
  });

  test('finds a newer release and picks the APK for the device ABI', () async {
    await setUpContainer();
    service.outcome = AppUpdateCheckOutcome(
      fakeRelease(),
      AppUpdateSource.builtInSources.first,
    );

    await controller().check(languageCode: 'zh');

    expect(state().phase, AppUpdatePhase.available);
    expect(state().hasUpdate, isTrue);
    expect(state().asset?.name, 'jotsy-v0.6.1-arm64-v8a.apk');
    expect(stored().lastCheckedAt, now);
    expect(stored().lastGoodSourceId, AppUpdateSource.builtInSources.first.id);
    expect(service.cleanedUpFor, isNotEmpty);
  });

  test('reports up to date when the latest release is not newer', () async {
    await setUpContainer();
    service.outcome = AppUpdateCheckOutcome(
      fakeRelease(version: '0.6.0'),
      AppUpdateSource.direct,
    );

    await controller().check(languageCode: 'zh');

    expect(state().phase, AppUpdatePhase.upToDate);
    expect(state().hasUpdate, isFalse);
  });

  test(
    'reports up to date while the latest release is still uploading',
    () async {
      await setUpContainer();
      service.outcome = const AppUpdateCheckOutcome(
        null,
        AppUpdateSource.direct,
      );

      await controller().check(languageCode: 'zh');

      expect(state().phase, AppUpdatePhase.upToDate);
      expect(state().failure, isNull);
      expect(state().release, isNull);
      expect(state().hasUpdate, isFalse);
      expect(stored().lastCheckedAt, now);
    },
  );

  test('shows a check failure, but stays quiet for silent checks', () async {
    await setUpContainer();
    await controller().check(languageCode: 'zh', silent: true);
    expect(state().phase, AppUpdatePhase.idle);

    await controller().check(languageCode: 'zh');
    expect(state().phase, AppUpdatePhase.failed);
    expect(state().failure?.stage, AppUpdateStage.check);
    expect(state().failure?.kind, AppUpdateFailureKind.network);
  });

  test('goes straight to install when the APK was already verified', () async {
    await setUpContainer();
    service
      ..outcome = AppUpdateCheckOutcome(fakeRelease(), AppUpdateSource.direct)
      ..alreadyDownloaded = File('/cache/app_update/0.6.1+18-arm64-v8a.apk');

    await controller().check(languageCode: 'zh');

    expect(state().phase, AppUpdatePhase.readyToInstall);
    expect(state().apkPath, endsWith('0.6.1+18-arm64-v8a.apk'));
  });

  test(
    'downloads, verifies and opens the installer, remembering the route',
    () async {
      await setUpContainer();
      service.outcome = AppUpdateCheckOutcome(
        fakeRelease(),
        AppUpdateSource.direct,
      );
      await controller().check(languageCode: 'zh');

      await controller().download();

      expect(service.lastProbe, isTrue, reason: 'auto route probes speeds');
      expect(state().phase, AppUpdatePhase.readyToInstall);
      expect(service.installCount, 1);
      expect(state().awaitingInstallPermission, isFalse);
    },
  );

  test('a chosen route is used without probing', () async {
    await setUpContainer();
    await controller().setSource('ghfast');
    service.outcome = AppUpdateCheckOutcome(
      fakeRelease(),
      AppUpdateSource.direct,
    );
    await controller().check(languageCode: 'zh');

    await controller().download();

    expect(service.lastProbe, isFalse);
    expect(service.lastSources?.first.id, 'ghfast');
    expect(stored().sourceId, 'ghfast');
  });

  test('cancelling keeps the progress so the download can resume', () async {
    await setUpContainer();
    service
      ..outcome = AppUpdateCheckOutcome(fakeRelease(), AppUpdateSource.direct)
      ..downloadCompleter = Completer<File>();
    await controller().check(languageCode: 'zh');

    final download = controller().download();
    await Future<void>.delayed(Duration.zero);
    expect(state().phase, AppUpdatePhase.downloading);
    service.onProgress!(
      const AppUpdateDownloadProgress(
        received: 20 << 20,
        total: 40 << 20,
        bytesPerSecond: 1048576,
        source: AppUpdateSource.direct,
      ),
    );
    expect(state().progress?.fraction, 0.5);

    controller().cancelDownload();
    await download;

    expect(state().phase, AppUpdatePhase.available);
    expect(state().progress?.fraction, 0.5);
    expect(service.installCount, 0);
  });

  test(
    'waits for the install permission and continues after returning',
    () async {
      await setUpContainer();
      service
        ..outcome = AppUpdateCheckOutcome(fakeRelease(), AppUpdateSource.direct)
        ..canInstall = false;
      await controller().check(languageCode: 'zh');

      await controller().download();
      expect(state().phase, AppUpdatePhase.readyToInstall);
      expect(state().awaitingInstallPermission, isTrue);
      expect(service.installCount, 0);

      // 回到前台但仍未授权：继续等待。
      await controller().handleAppResumed();
      expect(service.installCount, 0);

      service.canInstall = true;
      await controller().handleAppResumed();
      expect(state().awaitingInstallPermission, isFalse);
      expect(service.installCount, 1);
    },
  );

  test('a signature mismatch fails the download and drops progress', () async {
    await setUpContainer();
    service
      ..outcome = AppUpdateCheckOutcome(fakeRelease(), AppUpdateSource.direct)
      ..verifyFailure = AppUpdateFailureKind.signatureMismatch;
    await controller().check(languageCode: 'zh');

    await controller().download();

    expect(state().phase, AppUpdatePhase.failed);
    expect(state().failure?.stage, AppUpdateStage.download);
    expect(state().failure?.kind, AppUpdateFailureKind.signatureMismatch);
    expect(state().progress, isNull);
    expect(state().hasUpdate, isTrue, reason: 'release info stays visible');
  });

  group('autoCheck', () {
    test('returns the release once per interval and honours skip', () async {
      await setUpContainer();
      service.outcome = AppUpdateCheckOutcome(
        fakeRelease(),
        AppUpdateSource.direct,
      );

      final first = await controller().autoCheck(languageCode: 'zh');
      expect(first?.version, AppVersion.tryParse('0.6.1+18'));
      expect(service.fetchCount, 1);

      await controller().skipCurrentVersion();
      expect(stored().skippedVersion, '0.6.1+18');
      expect(state().isSkipped, isTrue);
    });

    test('does not request again within the interval', () async {
      await setUpContainer(
        prefs: <String, Object>{
          'app.update.preferences': AppUpdatePreferences(
            lastCheckedAt: now.subtract(const Duration(hours: 1)),
          ).encode(),
        },
      );
      service.outcome = AppUpdateCheckOutcome(
        fakeRelease(),
        AppUpdateSource.direct,
      );

      expect(await controller().autoCheck(languageCode: 'zh'), isNull);
      expect(service.fetchCount, 0);
      expect(
        service.cleanedUpFor,
        isNotEmpty,
        reason: 'still tidies the cache',
      );
    });

    test('stays silent for a skipped version or when turned off', () async {
      await setUpContainer(
        prefs: <String, Object>{
          'app.update.preferences': const AppUpdatePreferences(
            skippedVersion: '0.6.1+18',
          ).encode(),
        },
      );
      service.outcome = AppUpdateCheckOutcome(
        fakeRelease(),
        AppUpdateSource.direct,
      );
      expect(await controller().autoCheck(languageCode: 'zh'), isNull);
      expect(service.fetchCount, 1);
      expect(state().hasUpdate, isTrue, reason: 'entries still show a badge');

      await controller().setAutoCheck(false);
      now = now.add(const Duration(days: 2));
      container.invalidate(appUpdateControllerProvider);
      expect(await controller().autoCheck(languageCode: 'zh'), isNull);
      expect(service.fetchCount, 1);
    });

    test(
      'checks again every two hours without re-prompting the same version',
      () async {
        await setUpContainer();
        service.outcome = AppUpdateCheckOutcome(
          fakeRelease(),
          AppUpdateSource.direct,
        );
        final first = await controller().autoCheck(languageCode: 'zh');
        controller().markPrompted(first!);

        now = now.add(const Duration(minutes: 90));
        expect(await controller().autoCheck(languageCode: 'zh'), isNull);
        expect(service.fetchCount, 1, reason: 'not due yet');

        now = now.add(const Duration(minutes: 40));
        expect(await controller().autoCheck(languageCode: 'zh'), isNull);
        expect(service.fetchCount, 2, reason: 'due, but already prompted');

        service.outcome = AppUpdateCheckOutcome(
          fakeRelease(version: '0.6.2+19'),
          AppUpdateSource.direct,
        );
        now = now.add(const Duration(hours: 2));
        final newer = await controller().autoCheck(languageCode: 'zh');
        expect(newer?.version, AppVersion.tryParse('0.6.2+19'));
      },
    );

    test(
      'a silent check keeps the current phase until it has a result',
      () async {
        await setUpContainer();
        service.outcome = AppUpdateCheckOutcome(
          fakeRelease(),
          AppUpdateSource.direct,
        );
        await controller().check(languageCode: 'zh');
        expect(state().phase, AppUpdatePhase.available);

        now = now.add(const Duration(hours: 3));
        service.fetchGate = Completer<void>();
        final pending = controller().autoCheck(languageCode: 'zh');
        await Future<void>.delayed(Duration.zero);
        expect(service.fetchCount, 2);
        expect(state().phase, AppUpdatePhase.available);

        service.fetchGate!.complete();
        await pending;
        expect(state().phase, AppUpdatePhase.available);
        expect(stored().lastCheckedAt, now);
      },
    );

    test(
      'a silent result does not undo a download started meanwhile',
      () async {
        await setUpContainer();
        service.outcome = AppUpdateCheckOutcome(
          fakeRelease(),
          AppUpdateSource.direct,
        );
        await controller().check(languageCode: 'zh');

        now = now.add(const Duration(hours: 3));
        service
          ..fetchGate = Completer<void>()
          ..downloadCompleter = Completer<File>();
        final pending = controller().autoCheck(languageCode: 'zh');
        await Future<void>.delayed(Duration.zero);
        unawaited(controller().download());
        await Future<void>.delayed(Duration.zero);
        expect(state().phase, AppUpdatePhase.downloading);

        service.fetchGate!.complete();
        await pending;
        expect(state().phase, AppUpdatePhase.downloading);
      },
    );

    test('leaves a downloaded update waiting to be installed alone', () async {
      await setUpContainer();
      service
        ..outcome = AppUpdateCheckOutcome(fakeRelease(), AppUpdateSource.direct)
        ..alreadyDownloaded = File('/cache/app_update/0.6.1+18-arm64-v8a.apk');
      await controller().check(languageCode: 'zh');
      expect(state().phase, AppUpdatePhase.readyToInstall);

      now = now.add(const Duration(hours: 3));
      expect(await controller().autoCheck(languageCode: 'zh'), isNull);
      expect(service.fetchCount, 1);
    });

    test('never runs where in-app installs are unsupported', () async {
      service.supportsInAppInstall = false;
      await setUpContainer();
      service.outcome = AppUpdateCheckOutcome(
        fakeRelease(),
        AppUpdateSource.direct,
      );
      expect(await controller().autoCheck(languageCode: 'zh'), isNull);
      expect(service.fetchCount, 0);
    });
  });

  group('desktop', () {
    /// 以桌面平台运行（不支持应用内安装）；测试结束时还原目标平台。
    Future<void> setUpDesktop(TargetPlatform platform) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      service.supportsInAppInstall = false;
      service.abis = const <String>[];
      await setUpContainer();
    }

    test(
      'Linux picks the tarball and opens it on the route that answered',
      () async {
        await setUpDesktop(TargetPlatform.linux);
        final mirror = AppUpdateSource.builtInSources[1];
        service.outcome = AppUpdateCheckOutcome(
          fakeRelease(desktop: true),
          mirror,
        );

        await controller().check(languageCode: 'zh');

        expect(state().desktopTarget, AppUpdateDesktopTarget.linux);
        expect(state().phase, AppUpdatePhase.available);
        expect(state().asset, isNull);
        expect(state().desktopAsset?.name, 'jotsy-v0.6.1-linux-x64.tar.gz');
        expect(
          controller().desktopDownloadUri(),
          mirror.wrap(state().desktopAsset!.url),
        );
        expect(
          controller().desktopDownloadUri().toString(),
          '${mirror.prefix}https://github.com/CikeSeven/jotsy/releases/'
          'download/v0.6.1/jotsy-v0.6.1-linux-x64.tar.gz',
        );
      },
    );

    test('Windows picks the installer, not the portable zip', () async {
      await setUpDesktop(TargetPlatform.windows);
      service.outcome = AppUpdateCheckOutcome(
        fakeRelease(desktop: true),
        AppUpdateSource.direct,
      );

      await controller().check(languageCode: 'zh');

      expect(state().desktopTarget, AppUpdateDesktopTarget.windows);
      expect(state().desktopAsset?.name, 'jotsy-v0.6.1-windows-x64-setup.exe');
      expect(controller().desktopDownloadUri(), state().desktopAsset!.url);
    });

    test('an APK-only release falls back to its release page', () async {
      await setUpDesktop(TargetPlatform.linux);
      service.outcome = AppUpdateCheckOutcome(
        fakeRelease(),
        AppUpdateSource.direct,
      );

      await controller().check(languageCode: 'zh');

      expect(state().hasUpdate, isTrue);
      expect(state().desktopAsset, isNull);
      expect(controller().desktopDownloadUri(), fakeRelease().pageUrl);
    });

    test('auto-checks once per interval like Android', () async {
      await setUpDesktop(TargetPlatform.windows);
      service.outcome = AppUpdateCheckOutcome(
        fakeRelease(desktop: true),
        AppUpdateSource.direct,
      );

      final release = await controller().autoCheck(languageCode: 'zh');
      expect(release?.version, fakeRelease().version);
      expect(service.fetchCount, 1);

      now = now.add(const Duration(minutes: 30));
      expect(await controller().autoCheck(languageCode: 'zh'), isNull);
      expect(service.fetchCount, 1);
    });
  });

  test('old mirror index preference is removed on startup', () async {
    await setUpContainer(
      prefs: <String, Object>{'app.settings.release_mirror_start_index': 2},
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey('app.settings.release_mirror_start_index'),
      isFalse,
    );
  });
}
