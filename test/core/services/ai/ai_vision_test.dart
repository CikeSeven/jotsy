import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:node_diary/core/services/ai/ai_vision.dart';

import '../../../support/export_test_images.dart';

/// 发给视觉模型的图片：小图原样、大的照片缩小后编 JPEG、带透明的编 PNG，
/// 同一张图每次给出逐字节相同的结果（智能体每轮原样重发，提示缓存按前缀
/// 命中），文件变了重新读。
void main() {
  late Directory temp;

  setUp(() {
    AiVisionImages.debugClearCache();
    temp = Directory.systemTemp.createTempSync('ai_vision_test_');
  });
  tearDown(() => temp.deleteSync(recursive: true));

  /// [width]×[height] 的 PNG；[transparent] 时左上角一块半透明。
  Future<Uint8List> png(
    int width,
    int height, {
    bool transparent = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const Color(0xFF3366CC),
    );
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width / 2, height / 2),
      ui.Paint()
        ..color = const Color(0x8040A060)
        ..blendMode = transparent ? BlendMode.src : BlendMode.srcOver,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }

  File write(String name, List<int> bytes) =>
      File('${temp.path}/$name')..writeAsBytesSync(bytes);

  testWidgets('a small JPEG is sent untouched', (tester) async {
    await tester.runAsync(() async {
      final bytes = base64Decode(jpgBase64);
      final file = write('small.jpg', bytes);
      final part = await AiVisionImages.load(file.path);
      expect(part!.mimeType, 'image/jpeg');
      expect(part.bytes, bytes);
    });
  });

  testWidgets('a large opaque image is scaled down and sent as JPEG', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final file = write('big.png', await png(1200, 600));
      final part = await AiVisionImages.load(file.path, maxSide: 512);
      expect(part!.mimeType, 'image/jpeg');
      final decoded = img.decodeJpg(part.bytes)!;
      expect(decoded.width, 512);
      expect(decoded.height, 256);
    });
  });

  testWidgets('an image with transparency stays PNG', (tester) async {
    await tester.runAsync(() async {
      final file = write('alpha.png', await png(1200, 600, transparent: true));
      final part = await AiVisionImages.load(file.path, maxSide: 512);
      expect(part!.mimeType, 'image/png');
      final decoded = img.decodePng(part.bytes)!;
      expect(decoded.width, 512);
      expect(decoded.hasAlpha, isTrue);
    });
  });

  testWidgets('the same image gives the same bytes; a changed file is reread', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final file = write('photo.png', await png(1200, 600));
      final first = await AiVisionImages.load(file.path, maxSide: 512);
      final second = await AiVisionImages.load(file.path, maxSide: 512);
      expect(second!.bytes, first!.bytes);

      // 换了尺寸是另一份结果。
      final larger = await AiVisionImages.load(file.path, maxSide: 1024);
      expect(img.decodeJpg(larger!.bytes)!.width, 1024);

      // 文件被替换（压缩、恢复备份）后重新读取。
      file.writeAsBytesSync(await png(600, 1200));
      file.setLastModifiedSync(DateTime.now().add(const Duration(minutes: 1)));
      final reread = await AiVisionImages.load(file.path, maxSide: 512);
      final decoded = img.decodeJpg(reread!.bytes)!;
      expect((decoded.width, decoded.height), (256, 512));
    });
  });

  testWidgets('missing files, network images and broken bytes give null', (
    tester,
  ) async {
    await tester.runAsync(() async {
      expect(await AiVisionImages.load('${temp.path}/none.jpg'), isNull);
      expect(await AiVisionImages.load('https://example.com/a.jpg'), isNull);
      final broken = write('broken.jpg', utf8.encode('not an image'));
      expect(await AiVisionImages.load(broken.path), isNull);
      // 坏文件的结果也记住，第二次同样为 null。
      expect(await AiVisionImages.load(broken.path), isNull);
    });
  });

  test('sources are in document order without duplicates', () {
    String image(String url) => '{"type":"image","data":{"url":"$url"}}';
    final content =
        '{"document":{"type":"page","children":['
        '${image('/a.jpg')},'
        '{"type":"paragraph","data":{"delta":[{"insert":"x"}]}},'
        '${image('/b.jpg')},'
        '{"type":"bulleted_list","children":[${image('/a.jpg')},'
        '${image('/c.jpg')}]}'
        ']}}';
    expect(AiVisionImages.sourcesOf(content), ['/a.jpg', '/b.jpg', '/c.jpg']);
  });
}
