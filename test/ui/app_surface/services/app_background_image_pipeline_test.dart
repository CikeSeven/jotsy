import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/image_dimensions.dart';
import 'package:node_diary/ui/app_surface/services/app_background_image_key.dart';
import 'package:node_diary/ui/app_surface/services/app_background_image_pipeline.dart';

import '../app_surface_test_images.dart';

const Color _red = Color(0xFFFF0000);
const Color _blue = Color(0xFF0000FF);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('size buckets', () {
    test('round each physical side up to a multiple of 256', () {
      expect(
        AppBackgroundImageKey.bucketFor(const Size(360, 800), 3),
        const Size(1280, 2560),
      );
      expect(
        AppBackgroundImageKey.bucketFor(const Size(1024, 512), 1),
        const Size(1024, 512),
      );
      // 首帧之前没有尺寸时也给一档，不产生 0 宽高。
      expect(
        AppBackgroundImageKey.bucketFor(Size.zero, 2),
        const Size(256, 256),
      );
    });

    test(
      'small window drags stay on the same key, crossing a step does not',
      () {
        AppBackgroundImageKey key(Size size) =>
            AppBackgroundImageKey.forDisplay(
              fileName: 'bg.png',
              blur: 0,
              logicalSize: size,
              devicePixelRatio: 1,
            );
        expect(key(const Size(900, 700)), key(const Size(1000, 760)));
        expect(
          key(const Size(900, 700)) == key(const Size(1030, 700)),
          isFalse,
        );
        expect(
          key(const Size(900, 700)).sameImageAs(key(const Size(1030, 700))),
          isTrue,
        );
      },
    );
  });

  group('cover decode size', () {
    test('scales so the shorter side just covers the box, keeping ratio', () {
      final size = AppBackgroundDecodePlan.coverSize(
        image: const Size(4000, 3000),
        box: const Size(1280, 2560),
      );
      expect(size.height, 2560);
      expect(size.width, 3414);
    });

    test('halves the decode when blurred', () {
      final size = AppBackgroundDecodePlan.coverSize(
        image: const Size(4000, 3000),
        box: const Size(1280, 2560),
        scale: AppBackgroundDecodePlan.blurredScale,
      );
      expect(size.width, 1707);
      expect(size.height, 1280);
    });

    test('never upscales a small image and survives a zero size', () {
      final small = AppBackgroundDecodePlan.coverSize(
        image: const Size(800, 600),
        box: const Size(1280, 2560),
      );
      expect((small.width, small.height), (800, 600));
      final empty = AppBackgroundDecodePlan.coverSize(
        image: Size.zero,
        box: const Size(1280, 2560),
      );
      expect((empty.width, empty.height), (1, 1));
    });
  });

  test('blur sigma converts logical radius into decoded pixels', () {
    // 半分辨率解码：一个解码像素在屏幕上占 2 个物理像素。
    expect(
      AppBackgroundDecodePlan.blurSigma(
        blur: 10,
        devicePixelRatio: 3,
        box: const Size(1280, 2560),
        decodedWidth: 640,
        decodedHeight: 1280,
      ),
      15,
    );
    expect(
      AppBackgroundDecodePlan.blurSigma(
        blur: 0,
        devicePixelRatio: 3,
        box: const Size(1280, 2560),
        decodedWidth: 640,
        decodedHeight: 1280,
      ),
      0,
    );
  });

  group('average of premultiplied RGBA', () {
    test('averages opaque pixels', () {
      final color = AppBackgroundImagePipeline.averageOfPremultipliedRgba(
        Uint8List.fromList(<int>[255, 0, 0, 255, 0, 0, 255, 255]),
      );
      expect(color, const Color(0xFF800080));
    });

    test('weights by alpha and un-premultiplies', () {
      // 半透明红（预乘后 128,0,0,128）+ 全透明：颜色仍是纯红，透明度取平均。
      final color = AppBackgroundImagePipeline.averageOfPremultipliedRgba(
        Uint8List.fromList(<int>[128, 0, 0, 128, 0, 0, 0, 0]),
      );
      expect(color, const Color.fromARGB(64, 255, 0, 0));
    });

    test('a fully transparent sample averages to transparent', () {
      final color = AppBackgroundImagePipeline.averageOfPremultipliedRgba(
        Uint8List(8),
      );
      expect(color.a, 0);
    });
  });

  group('real decode', () {
    late Directory directory;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('jotsy_bg_pipeline_');
      ImageDimensions.debugReset();
    });
    tearDown(() async {
      ImageDimensions.debugReset();
      await directory.delete(recursive: true);
    });

    test('decodes at the cover size and reports the average color', () async {
      final file = await writePng(directory, 'halves.png', 64, 32, _red, _blue);
      final decoded = await AppBackgroundImagePipeline.load(
        file,
        AppBackgroundImageKey.forDisplay(
          fileName: 'halves.png',
          blur: 0,
          logicalSize: const Size(100, 100),
          devicePixelRatio: 1,
        ),
      );
      addTearDown(decoded.image.dispose);
      // 原图比 256 档小：按原尺寸解码，不放大。
      expect((decoded.image.width, decoded.image.height), (64, 32));
      final pixel = await pixelReader(decoded.image);
      expect(pixel(0, 0), _red);
      expect(pixel(63, 31), _blue);
      expect(decoded.averageColor.a, closeTo(1, 0.01));
      expect(decoded.averageColor.r, closeTo(0.5, 0.05));
      expect(decoded.averageColor.b, closeTo(0.5, 0.05));
      expect(decoded.averageColor.g, closeTo(0, 0.02));
    });

    test(
      'blurs once off screen at half resolution without dark edges',
      () async {
        final file = await writePng(
          directory,
          'large.png',
          1024,
          512,
          _red,
          _blue,
        );
        final decoded = await AppBackgroundImagePipeline.load(
          file,
          AppBackgroundImageKey.forDisplay(
            fileName: 'large.png',
            blur: 20,
            logicalSize: const Size(256, 256),
            devicePixelRatio: 1,
          ),
        );
        addTearDown(decoded.image.dispose);
        // cover 256×256 需要 0.5 倍，模糊再减半。
        expect((decoded.image.width, decoded.image.height), (256, 128));
        final pixel = await pixelReader(decoded.image);
        // 中缝被模糊成红蓝混合。
        final seam = pixel(128, 64);
        expect(seam.r, greaterThan(0.25));
        expect(seam.b, greaterThan(0.25));
        // 镜像延伸：边缘不透明、不发黑。
        final edge = pixel(0, 64);
        expect(edge.a, closeTo(1, 0.01));
        expect(edge.r, greaterThan(0.9));
        final corner = pixel(255, 0);
        expect(corner.a, closeTo(1, 0.01));
        expect(corner.b, greaterThan(0.9));
      },
    );

    test('an unreadable file throws', () async {
      final file = File('${directory.path}/broken.png');
      await file.writeAsBytes(<int>[1, 2, 3, 4]);
      await expectLater(
        AppBackgroundImagePipeline.load(
          file,
          AppBackgroundImageKey.forDisplay(
            fileName: 'broken.png',
            blur: 0,
            logicalSize: const Size(100, 100),
            devicePixelRatio: 1,
          ),
        ),
        throwsA(anything),
      );
    });
  });
}
