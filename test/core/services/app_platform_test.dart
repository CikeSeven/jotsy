import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_data_directory.dart';
import 'package:node_diary/core/services/app_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('AppPlatform', () {
    test('widget tests default to Android with every mobile capability', () {
      expect(AppPlatform.isAndroid, isTrue);
      expect(AppPlatform.isMobile, isTrue);
      expect(AppPlatform.isDesktop, isFalse);
      expect(AppPlatform.supportsDeviceAuth, isTrue);
      expect(AppPlatform.supportsShareTargets, isTrue);
      expect(AppPlatform.supportsSystemFileShare, isTrue);
      expect(AppPlatform.savesImagesToGallery, isTrue);
      expect(AppPlatform.supportsInlineVideo, isTrue);
      expect(AppPlatform.supportsNativeLongImageMerge, isTrue);
      expect(AppPlatform.supportsCloudNotesLogin, isTrue);
      expect(AppPlatform.supportsInAppInstall, isTrue);
      expect(AppPlatform.supportsAutoLocation, isTrue);
      expect(AppPlatform.supportsAudioRecording, isTrue);
    });

    test('Linux lacks device auth, file share, inline video and recording', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(AppPlatform.isLinux, isTrue);
      expect(AppPlatform.isDesktop, isTrue);
      expect(AppPlatform.isMobile, isFalse);
      expect(AppPlatform.supportsDeviceAuth, isFalse);
      expect(AppPlatform.supportsShareTargets, isFalse);
      expect(AppPlatform.supportsSystemFileShare, isFalse);
      expect(AppPlatform.savesImagesToGallery, isFalse);
      expect(AppPlatform.supportsInlineVideo, isFalse);
      expect(AppPlatform.supportsNativeLongImageMerge, isFalse);
      expect(AppPlatform.supportsCloudNotesLogin, isFalse);
      expect(AppPlatform.supportsInAppInstall, isFalse);
      expect(AppPlatform.supportsAutoLocation, isFalse);
      expect(AppPlatform.supportsAudioRecording, isFalse);
    });

    test('Windows keeps device auth, system share and recording', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(AppPlatform.isWindows, isTrue);
      expect(AppPlatform.isDesktop, isTrue);
      expect(AppPlatform.supportsDeviceAuth, isTrue);
      expect(AppPlatform.supportsSystemFileShare, isTrue);
      expect(AppPlatform.supportsAudioRecording, isTrue);
      expect(AppPlatform.supportsShareTargets, isFalse);
      expect(AppPlatform.savesImagesToGallery, isFalse);
      expect(AppPlatform.supportsInlineVideo, isFalse);
      expect(AppPlatform.supportsNativeLongImageMerge, isFalse);
    });

    test('iOS is mobile but has no direct-to-app share or in-app install', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AppPlatform.isIOS, isTrue);
      expect(AppPlatform.isMobile, isTrue);
      expect(AppPlatform.supportsShareTargets, isFalse);
      expect(AppPlatform.supportsInAppInstall, isFalse);
      expect(AppPlatform.supportsAutoLocation, isFalse);
      expect(AppPlatform.savesImagesToGallery, isTrue);
    });
  });

  group('AppPlatform LAN sync', () {
    test('Android supports LAN sync and QR scanning', () {
      expect(AppPlatform.supportsLanSync, isTrue);
      expect(AppPlatform.supportsQrScan, isTrue);
    });

    test('desktops support LAN sync but only display the QR code', () {
      for (final platform in [
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(AppPlatform.supportsLanSync, isTrue, reason: '$platform');
        expect(AppPlatform.supportsQrScan, isFalse, reason: '$platform');
      }
    });

    test('iOS has neither LAN sync nor QR scanning', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AppPlatform.supportsLanSync, isFalse);
      expect(AppPlatform.supportsQrScan, isFalse);
    });
  });

  group('appDataRootDirectory', () {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory sandbox;
    late String documents;
    late String support;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('app_data_root_test_');
      documents = '${sandbox.path}/documents';
      support = '${sandbox.path}/support/app';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            return switch (call.method) {
              'getApplicationDocumentsDirectory' => documents,
              'getApplicationSupportDirectory' => support,
              _ => null,
            };
          });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await sandbox.delete(recursive: true);
    });

    test(
      'mobile keeps the documents directory existing users rely on',
      () async {
        expect((await appDataRootDirectory()).path, documents);
      },
    );

    test('desktop uses the support directory and creates it', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final root = await appDataRootDirectory();
      expect(root.path, support);
      expect(await root.exists(), isTrue);
    });
  });
}
