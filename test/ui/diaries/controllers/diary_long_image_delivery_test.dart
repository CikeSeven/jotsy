import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/desktop_save_service.dart';
import 'package:node_diary/core/services/image_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_long_image_delivery.dart';
import 'package:path/path.dart' as p;

/// 记录存进相册的图片；[failure] 不为 null 时改为抛出它。
class _FakeGallery extends ImageExportService {
  _FakeGallery({this.failure});

  final ImageExportException? failure;
  final List<({Uint8List bytes, String name})> saved =
      <({Uint8List bytes, String name})>[];

  @override
  Future<void> saveBytesToGallery(Uint8List bytes, {required String name}) {
    final failure = this.failure;
    if (failure != null) throw failure;
    saved.add((bytes: bytes, name: name));
    return Future<void>.value();
  }
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('zh'));
  final png = Uint8List.fromList(<int>[137, 80, 78, 71]);

  test('saving to the gallery stores the bytes and confirms', () async {
    final gallery = _FakeGallery();
    final delivery = DiaryLongImageDelivery(images: gallery);

    final message = await delivery.deliver(
      png,
      destination: DiaryLongImageDestination.gallery,
      l10n: l10n,
    );

    expect(message, l10n.imageViewerSaveSuccess);
    expect(gallery.saved, hasLength(1));
    expect(gallery.saved.single.bytes, png);
    expect(gallery.saved.single.name, startsWith('jotsy_diary_'));
  });

  test('a denied gallery permission becomes its own hint', () async {
    final delivery = DiaryLongImageDelivery(
      images: _FakeGallery(
        failure: const ImageExportException(
          type: ImageExportErrorType.permissionDenied,
          message: 'gallery access denied',
        ),
      ),
    );

    final message = await delivery.deliver(
      png,
      destination: DiaryLongImageDestination.gallery,
      l10n: l10n,
    );

    expect(message, l10n.imageViewerGalleryPermissionDenied);
  });

  test('other gallery failures carry the reason', () async {
    final delivery = DiaryLongImageDelivery(
      images: _FakeGallery(
        failure: const ImageExportException(
          type: ImageExportErrorType.unknown,
          message: 'disk full',
        ),
      ),
    );

    final message = await delivery.deliver(
      png,
      destination: DiaryLongImageDestination.gallery,
      l10n: l10n,
    );

    expect(message, l10n.imageViewerSaveFailed('disk full'));
  });

  group('desktop Save as…', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('long_image_delivery');
    });
    tearDown(() => dir.delete(recursive: true));

    test('writes the PNG where the user chose and says where', () async {
      final target = p.join(dir.path, 'diary.png');
      String? suggested;
      final delivery = DiaryLongImageDelivery(
        images: _FakeGallery(),
        desktopSaver: DesktopSaveService(
          pickPath:
              ({
                required String dialogTitle,
                required String fileName,
                required String extension,
              }) async {
                suggested = fileName;
                return target;
              },
        ),
      );

      final message = await delivery.deliver(
        png,
        destination: DiaryLongImageDestination.file,
        l10n: l10n,
      );

      expect(suggested, allOf(startsWith('jotsy_diary_'), endsWith('.png')));
      expect(File(target).readAsBytesSync(), png);
      expect(message, l10n.desktopSavedTo(target));
    });

    test('cancelling the dialog stays quiet', () async {
      final gallery = _FakeGallery();
      final delivery = DiaryLongImageDelivery(
        images: gallery,
        desktopSaver: DesktopSaveService(
          pickPath:
              ({
                required String dialogTitle,
                required String fileName,
                required String extension,
              }) async => null,
        ),
      );

      final message = await delivery.deliver(
        png,
        destination: DiaryLongImageDestination.file,
        l10n: l10n,
      );

      expect(message, isNull);
      expect(gallery.saved, isEmpty);
      expect(dir.listSync(), isEmpty);
    });
  });
}
