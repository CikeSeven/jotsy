import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/image_dimensions.dart';
import 'package:path/path.dart' as p;

import '../../support/export_test_images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUp(() async {
    ImageDimensions.debugReset();
    root = await Directory.systemTemp.createTemp('jotsy_image_dimensions_');
  });

  tearDown(() async {
    ImageDimensions.debugReset();
    await root.delete(recursive: true);
  });

  Future<String> write(String name, List<int> bytes) async {
    final file = File(p.join(root.path, name));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  test('reads pixel size from the file header and caches it', () async {
    final path = await write('a.png', base64Decode(pngBase64));
    expect(ImageDimensions.isResolved(path), isFalse);

    expect(await ImageDimensions.resolve(path), const Size(3, 2));
    expect(ImageDimensions.isResolved(path), isTrue);
    expect(ImageDimensions.peek(path), const Size(3, 2));
  });

  test('reports the displayed size of an EXIF-rotated JPEG', () async {
    // 存储为 4×2，EXIF 方向 6：显示（与 Flutter 解码结果）为 2×4。
    final path = await write('rotated.jpg', base64Decode(jpgRotatedBase64));

    expect(await ImageDimensions.resolve(path), const Size(2, 4));
  });

  test('a large file is measured from its head without a full read', () async {
    // 头部之后补上大量无关字节：文件超过只读头部的阈值，尺寸仍可读出。
    final bytes = <int>[
      ...base64Decode(pngBase64),
      ...List<int>.filled(700 * 1024, 0),
    ];
    final path = await write('big.png', bytes);

    expect(await ImageDimensions.resolve(path), const Size(3, 2));
  });

  test('data URIs are measured and network images are left alone', () async {
    expect(
      await ImageDimensions.resolve('data:image/png;base64,$pngBase64'),
      const Size(3, 2),
    );
    expect(await ImageDimensions.resolve('https://example.com/a.png'), isNull);
  });

  test('missing or undecodable files resolve to null once', () async {
    final missing = p.join(root.path, 'missing.png');
    final junk = await write('junk.png', utf8.encode('not an image'));

    expect(await ImageDimensions.resolve(missing), isNull);
    expect(await ImageDimensions.resolve(junk), isNull);
    // 失败也记为已解析，图片组件不会每次重建都重读文件。
    expect(ImageDimensions.isResolved(missing), isTrue);
    expect(ImageDimensions.isResolved(junk), isTrue);
  });
}
