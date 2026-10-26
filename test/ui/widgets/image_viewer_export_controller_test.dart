import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/image_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_share_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_share_target.dart';
import 'package:node_diary/ui/widgets/image_viewer_export_controller.dart';

class _FakeExportService extends ImageExportService {
  _FakeExportService();

  Completer<void> pending = Completer<void>();
  int saveCalls = 0;
  String? savedPath;
  final List<String> fileSaves = <String>[];

  @override
  Future<void> saveToGallery(String source) {
    saveCalls++;
    return pending.future;
  }

  @override
  Future<String?> saveToFile(
    String source, {
    required String dialogTitle,
  }) async {
    fileSaves.add(source);
    return savedPath;
  }
}

/// 记录每次分享的参数，按 [next] 给出结果（或抛出异常）。
class _FakeShareController extends DiaryShareController {
  _FakeShareController();

  Completer<DiaryShareResult> next = Completer<DiaryShareResult>();
  final List<({DiaryShareTarget target, String text, List<String> images})>
  calls = <({DiaryShareTarget target, String text, List<String> images})>[];

  @override
  Future<DiaryShareResult> share(
    DiaryShareTarget target, {
    required String text,
    required List<String> images,
    String? chooserTitle,
  }) {
    calls.add((target: target, text: text, images: images));
    return next.future;
  }
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test(
    'saving reports progress, ignores repeated taps and hints success',
    () async {
      final service = _FakeExportService();
      final share = _FakeShareController();
      final controller = ImageViewerExportController(
        service: service,
        share: share,
      );
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      final first = controller.saveToGallery('/a.png', l10n);
      expect(controller.isBusy, isTrue);
      expect(controller.busyLabel, l10n.imageViewerSaving);
      // 忙碌中重复触发直接忽略，不会并发调用服务。
      expect(await controller.saveToGallery('/a.png', l10n), isNull);
      expect(
        await controller.shareTo(DiaryShareTarget.system, '/a.png', l10n),
        isNull,
      );
      expect(service.saveCalls, 1);
      expect(share.calls, isEmpty);

      service.pending.complete();
      expect(await first, l10n.imageViewerSaveSuccess);
      expect(controller.isBusy, isFalse);
      // 文案保留，随遮罩一起淡出。
      expect(controller.busyLabel, l10n.imageViewerSaving);
      expect(notifications, 2);
    },
  );

  test('saving maps a denied gallery permission to its own hint', () async {
    final service = _FakeExportService();
    final controller = ImageViewerExportController(
      service: service,
      share: _FakeShareController(),
    );
    addTearDown(controller.dispose);

    final pending = controller.saveToGallery('/a.png', l10n);
    service.pending.completeError(
      const ImageExportException(
        type: ImageExportErrorType.permissionDenied,
        message: 'denied',
      ),
    );
    expect(await pending, l10n.imageViewerGalleryPermissionDenied);
    expect(controller.isBusy, isFalse);
  });

  test(
    'sharing sends only the image and stays quiet once handed over',
    () async {
      final share = _FakeShareController();
      final controller = ImageViewerExportController(
        service: _FakeExportService(),
        share: share,
      );
      addTearDown(controller.dispose);

      final pending = controller.shareTo(
        DiaryShareTarget.wechat,
        '/diary_images/a.png',
        l10n,
      );
      expect(controller.isBusy, isTrue);
      expect(controller.busyLabel, l10n.imageViewerSharing);
      share.next.complete(const DiaryShareResult(DiaryShareOutcome.shared));

      expect(await pending, isNull);
      expect(controller.isBusy, isFalse);
      expect(share.calls.single.target, DiaryShareTarget.wechat);
      // 看图页只分享图片本身，不带文字（也就不会写剪贴板）。
      expect(share.calls.single.text, isEmpty);
      expect(share.calls.single.images, <String>['/diary_images/a.png']);
    },
  );

  test('sharing failures become hints', () async {
    final share = _FakeShareController();
    final controller = ImageViewerExportController(
      service: _FakeExportService(),
      share: share,
    );
    addTearDown(controller.dispose);

    Future<String?> run(
      DiaryShareTarget target,
      String source,
      FutureOr<DiaryShareResult> Function() result,
    ) {
      share.next = Completer<DiaryShareResult>();
      final pending = controller.shareTo(target, source, l10n);
      try {
        share.next.complete(result());
      } on Object catch (error) {
        share.next.completeError(error);
      }
      return pending;
    }

    expect(
      await run(
        DiaryShareTarget.weibo,
        '/a.png',
        () => const DiaryShareResult(DiaryShareOutcome.appUnavailable),
      ),
      l10n.diaryShareAppUnavailable(l10n.diaryShareTargetWeibo),
    );
    expect(
      await run(
        DiaryShareTarget.system,
        '/gone.png',
        () => const DiaryShareResult(
          DiaryShareOutcome.nothingToShare,
          missingImages: 1,
        ),
      ),
      l10n.imageViewerImageUnreadable,
    );
    expect(
      await run(
        DiaryShareTarget.system,
        'https://example.com/a.png',
        () => const DiaryShareResult(
          DiaryShareOutcome.nothingToShare,
          missingImages: 1,
        ),
      ),
      l10n.imageViewerDownloadFailed,
    );
    expect(
      await run(
        DiaryShareTarget.qq,
        '/a.png',
        () => throw PlatformException(code: 'boom'),
      ),
      l10n.imageViewerShareFailed(PlatformException(code: 'boom').toString()),
    );
    expect(controller.isBusy, isFalse);
  });

  test('finishing after dispose does not notify', () async {
    final service = _FakeExportService();
    final controller = ImageViewerExportController(
      service: service,
      share: _FakeShareController(),
    );
    final pending = controller.saveToGallery('/a.png', l10n);
    controller.dispose();
    service.pending.complete();
    expect(await pending, l10n.imageViewerSaveSuccess);
  });

  group('on desktop', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.linux);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('saving opens Save as… and hints the saved path', () async {
      final service = _FakeExportService()..savedPath = '/home/me/a.png';
      final controller = ImageViewerExportController(
        service: service,
        share: _FakeShareController(),
      );
      addTearDown(controller.dispose);

      expect(
        await controller.saveToGallery('/a.png', l10n),
        'Saved to /home/me/a.png',
      );
      expect(service.fileSaves, <String>['/a.png']);
      expect(service.saveCalls, 0);
    });

    test('cancelling the save dialog shows no hint', () async {
      final service = _FakeExportService();
      final controller = ImageViewerExportController(
        service: service,
        share: _FakeShareController(),
      );
      addTearDown(controller.dispose);

      expect(await controller.saveToGallery('/a.png', l10n), isNull);
      expect(controller.isBusy, isFalse);
    });
  });
}
