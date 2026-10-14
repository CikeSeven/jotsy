import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/image_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/image_viewer_export_controller.dart';

class _FakeExportService extends ImageExportService {
  _FakeExportService();

  Completer<void> pending = Completer<void>();
  int saveCalls = 0;
  int shareCalls = 0;

  @override
  Future<void> saveToGallery(String source) {
    saveCalls++;
    return pending.future;
  }

  @override
  Future<void> shareImage(String source) {
    shareCalls++;
    return pending.future;
  }
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test(
    'saving reports progress, ignores repeated taps and hints success',
    () async {
      final service = _FakeExportService();
      final controller = ImageViewerExportController(service: service);
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      final first = controller.saveToGallery('/a.png', l10n);
      expect(controller.isBusy, isTrue);
      expect(controller.busyLabel, l10n.imageViewerSaving);
      // 忙碌中重复触发直接忽略，不会并发调用服务。
      expect(await controller.saveToGallery('/a.png', l10n), isNull);
      expect(await controller.share('/a.png', l10n), isNull);
      expect(service.saveCalls, 1);
      expect(service.shareCalls, 0);

      service.pending.complete();
      expect(await first, l10n.imageViewerSaveSuccess);
      expect(controller.isBusy, isFalse);
      // 文案保留，随遮罩一起淡出。
      expect(controller.busyLabel, l10n.imageViewerSaving);
      expect(notifications, 2);
    },
  );

  test('share stays quiet on success and maps failures to hints', () async {
    final service = _FakeExportService();
    final controller = ImageViewerExportController(service: service);
    addTearDown(controller.dispose);

    final ok = controller.share('/a.png', l10n);
    service.pending.complete();
    expect(await ok, isNull);

    service.pending = Completer<void>();
    final failed = controller.share('/a.png', l10n);
    service.pending.completeError(
      const ImageExportException(
        type: ImageExportErrorType.unknown,
        message: 'boom',
      ),
    );
    expect(await failed, l10n.imageViewerShareFailed('boom'));
    expect(controller.isBusy, isFalse);
  });

  test('finishing after dispose does not notify', () async {
    final service = _FakeExportService();
    final controller = ImageViewerExportController(service: service);
    final pending = controller.saveToGallery('/a.png', l10n);
    controller.dispose();
    service.pending.complete();
    expect(await pending, l10n.imageViewerSaveSuccess);
  });
}
