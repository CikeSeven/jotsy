import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/image_export_service.dart';

/// ImageExportService 纯逻辑单测。
///
/// 说明：保存相册（gal）与网络下载依赖平台通道 / 真实网络，无法在纯单测中触发，
/// 这里只覆盖不依赖外部副作用的判定与入参校验逻辑。
void main() {
  group('isRemoteSource', () {
    test('识别 http/https 为网络源', () {
      expect(ImageExportService.isRemoteSource('http://a.com/x.jpg'), isTrue);
      expect(ImageExportService.isRemoteSource('https://a.com/x.png'), isTrue);
    });

    test('本地文件路径不是网络源', () {
      expect(
        ImageExportService.isRemoteSource('/data/app/diary_images/x.jpg'),
        isFalse,
      );
      expect(ImageExportService.isRemoteSource('file:///tmp/x.png'), isFalse);
    });

    test('前后空白不影响判定', () {
      expect(
        ImageExportService.isRemoteSource('  https://a.com/x.jpg  '),
        isTrue,
      );
    });
  });

  group('入参校验', () {
    const service = ImageExportService();

    test('空源保存时抛 invalidSource', () async {
      await expectLater(
        service.saveToGallery('   '),
        throwsA(
          isA<ImageExportException>().having(
            (ImageExportException e) => e.type,
            'type',
            ImageExportErrorType.invalidSource,
          ),
        ),
      );
    });

    test('空源分享时抛 invalidSource', () async {
      await expectLater(
        service.shareImage(''),
        throwsA(
          isA<ImageExportException>().having(
            (ImageExportException e) => e.type,
            'type',
            ImageExportErrorType.invalidSource,
          ),
        ),
      );
    });
  });
}
