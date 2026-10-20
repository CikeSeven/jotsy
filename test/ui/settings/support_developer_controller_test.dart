import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/image_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/controllers/support_developer_controller.dart';
import 'package:node_diary/ui/settings/models/support_channel.dart';

/// 记录写入相册的图片；[failure] 不为空时按它失败，[pending] 可让保存悬而未决。
class _FakeExportService extends ImageExportService {
  _FakeExportService();

  final List<({Uint8List bytes, String name})> saved =
      <({Uint8List bytes, String name})>[];
  ImageExportException? failure;
  Completer<void>? pending;

  @override
  Future<void> saveBytesToGallery(
    Uint8List bytes, {
    required String name,
  }) async {
    saved.add((bytes: bytes, name: name));
    await pending?.future;
    if (failure != null) {
      throw failure!;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = lookupAppLocalizations(const Locale('zh'));
  const pngSignature = <int>[0x89, 0x50, 0x4E, 0x47];

  late _FakeExportService service;
  late List<Uri> launched;
  late bool launchSucceeds;

  SupportDeveloperController controller() {
    final controller = SupportDeveloperController(
      service: service,
      launcher: (Uri uri) async {
        launched.add(uri);
        return launchSucceeds;
      },
    );
    addTearDown(controller.dispose);
    return controller;
  }

  setUp(() {
    service = _FakeExportService();
    launched = <Uri>[];
    launchSucceeds = true;
  });

  test('the Alipay link opens the payment code in Alipay scan', () {
    expect(
      alipayLaunchUri.toString(),
      'alipays://platformapi/startapp?saId=10000007'
      '&qrcode=https%3A%2F%2Fqr.alipay.com%2Ffkx112949yjleherrvp3m48',
    );
    expect(alipayLaunchUri.queryParameters['qrcode'], alipayPaymentCodeUrl);
  });

  test('opening Alipay hands off without a message when it launches', () async {
    final result = await controller().openAlipay(l10n);

    expect(launched, <Uri>[alipayLaunchUri]);
    expect(result, isNotNull);
    expect(result!.message, isNull);
  });

  test('opening Alipay explains how to pay when Alipay is missing', () async {
    launchSucceeds = false;

    final result = await controller().openAlipay(l10n);

    expect(result!.isError, isTrue);
    expect(result.message, l10n.supportDeveloperAlipayUnavailable);
  });

  test(
    'opening WeChat launches the WeChat home and reports failures',
    () async {
      final subject = controller();
      expect((await subject.openWeChat(l10n))!.message, isNull);

      launchSucceeds = false;
      final failed = await subject.openWeChat(l10n);

      expect(launched, <Uri>[weChatLaunchUri, weChatLaunchUri]);
      expect(failed!.isError, isTrue);
      expect(failed.message, l10n.supportDeveloperWeChatUnavailable);
    },
  );

  test('saving writes the bundled code image under its gallery name', () async {
    final subject = controller();

    final wechat = await subject.saveCode(SupportChannel.wechat, l10n);
    final alipay = await subject.saveCode(SupportChannel.alipay, l10n);

    expect(wechat!.isError, isFalse);
    expect(wechat.message, l10n.imageViewerSaveSuccess);
    expect(alipay!.message, l10n.imageViewerSaveSuccess);
    expect(service.saved.map((s) => s.name), <String>[
      'jotsy_support_wechat',
      'jotsy_support_alipay',
    ]);
    for (final saved in service.saved) {
      expect(saved.bytes.take(4), pngSignature);
    }
  });

  test('saving maps a denied gallery permission to its hint', () async {
    service.failure = const ImageExportException(
      type: ImageExportErrorType.permissionDenied,
      message: 'gallery access denied',
    );

    final result = await controller().saveCode(SupportChannel.wechat, l10n);

    expect(result!.isError, isTrue);
    expect(result.message, l10n.imageViewerGalleryPermissionDenied);
  });

  test('repeated taps while busy are ignored and busy is reported', () async {
    service.pending = Completer<void>();
    final subject = controller();
    final states = <bool>[];
    subject.addListener(() => states.add(subject.isBusy));

    final first = subject.saveCode(SupportChannel.wechat, l10n);
    await pumpEventQueue();
    expect(subject.isBusy, isTrue);
    expect(await subject.saveCode(SupportChannel.wechat, l10n), isNull);
    expect(await subject.openAlipay(l10n), isNull);
    expect(launched, isEmpty);

    service.pending!.complete();
    expect((await first)!.message, l10n.imageViewerSaveSuccess);
    expect(service.saved, hasLength(1));
    expect(states, <bool>[true, false]);
    expect(subject.isBusy, isFalse);
  });
}
