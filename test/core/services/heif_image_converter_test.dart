import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_background_storage_service.dart';
import 'package:node_diary/core/services/diary_cover_storage_service.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/core/services/heif_image_converter.dart';
import 'package:path/path.dart' as p;

/// ISO BMFF `ftyp` 盒：主品牌 + 兼容品牌。
List<int> ftyp(String major, [List<String> compatible = const []]) {
  final size = 16 + 4 * compatible.length;
  return [
    0,
    0,
    (size >> 8) & 0xFF,
    size & 0xFF,
    ...'ftyp'.codeUnits,
    ...major.codeUnits,
    0,
    0,
    0,
    0,
    for (final brand in compatible) ...brand.codeUnits,
    // 盒之后的内容（meta 盒等），判定不应读到这里。
    ...List<int>.filled(24, 7),
  ];
}

const List<int> jpegBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0, 16];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isHeifHeader', () {
    test('recognises HEIC, generic HEIF and AVIF photos', () {
      expect(HeifImageConverter.isHeifHeader(ftyp('heic', ['mif1'])), isTrue);
      expect(HeifImageConverter.isHeifHeader(ftyp('mif1', ['heic'])), isTrue);
      expect(HeifImageConverter.isHeifHeader(ftyp('avif', ['mif1'])), isTrue);
      // 主品牌是通用值时看兼容品牌。
      expect(HeifImageConverter.isHeifHeader(ftyp('iso8', ['mif1'])), isTrue);
    });

    test('rejects videos, other images and truncated headers', () {
      expect(
        HeifImageConverter.isHeifHeader(ftyp('isom', ['iso2', 'mp41'])),
        isFalse,
      );
      expect(HeifImageConverter.isHeifHeader(ftyp('qt  ')), isFalse);
      expect(HeifImageConverter.isHeifHeader(jpegBytes), isFalse);
      expect(HeifImageConverter.isHeifHeader(const [0, 0, 0]), isFalse);
      // 只有 12–15 字节（盒声明更长）也不越界。
      expect(
        HeifImageConverter.isHeifHeader(ftyp('isom', ['mif1']).sublist(0, 14)),
        isFalse,
      );
    });

    test('ignores brands past the end of the ftyp box', () {
      final bytes = ftyp('isom', ['mp41']);
      // 盒之后恰好出现 "mif1" 字样不算兼容品牌。
      bytes.replaceRange(20, 24, 'mif1'.codeUnits);
      expect(HeifImageConverter.isHeifHeader(bytes), isFalse);
    });
  });

  group('importing', () {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory root;
    late List<String> transcoded;
    var succeed = true;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('jotsy_heif_import_test_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => root.path);
      transcoded = <String>[];
      succeed = true;
      HeifImageConverter.debugTranscoder = (source, target) async {
        transcoded.add(source);
        if (!succeed) return false;
        await File(target).writeAsBytes(jpegBytes);
        return true;
      };
    });

    tearDown(() async {
      HeifImageConverter.debugTranscoder = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await root.delete(recursive: true);
    });

    test(
      'a HEIC body image is stored as a JPEG and the copy removed',
      () async {
        final file = await DiaryMediaStorageService.importFile(
          kind: DiaryMediaKind.image,
          fileName: 'IMG_0001.HEIC',
          bytes: ftyp('heic', ['mif1']),
        );
        expect(p.basename(file.path), 'IMG_0001.jpg');
        expect(file.displayName, 'IMG_0001.jpg');
        expect(file.sizeBytes, jpegBytes.length);
        expect(await File(file.path).readAsBytes(), jpegBytes);
        expect(
          await File(p.join(p.dirname(file.path), 'IMG_0001.HEIC')).exists(),
          isFalse,
        );
      },
    );

    test('JPEGs and HEIC attachments are copied untouched', () async {
      final jpeg = await DiaryMediaStorageService.importFile(
        kind: DiaryMediaKind.image,
        fileName: 'a.jpg',
        bytes: jpegBytes,
      );
      final attachment = await DiaryMediaStorageService.importFile(
        kind: DiaryMediaKind.attachment,
        fileName: 'raw.heic',
        bytes: ftyp('heic'),
      );
      expect(p.basename(jpeg.path), 'a.jpg');
      expect(p.basename(attachment.path), 'raw.heic');
      expect(transcoded, isEmpty);
    });

    test('a failed conversion keeps the original HEIC', () async {
      succeed = false;
      final file = await DiaryMediaStorageService.importFile(
        kind: DiaryMediaKind.image,
        fileName: 'IMG_0002.heic',
        bytes: ftyp('heic'),
      );
      expect(p.basename(file.path), 'IMG_0002.heic');
      expect(await File(file.path).exists(), isTrue);
      expect(transcoded, hasLength(1));
    });

    test('covers and backgrounds picked as HEIC become JPEGs', () async {
      final picked = File(p.join(root.path, 'picked.heic'));
      await picked.writeAsBytes(ftyp('heic'));

      final cover = await DiaryCoverStorageService.importCover(picked.path);
      expect(p.extension(cover), '.jpg');
      expect(await File(cover).readAsBytes(), jpegBytes);

      final background = await AppBackgroundStorageService.importImage(
        picked.path,
      );
      expect(p.extension(background), '.jpg');
      expect(await AppBackgroundStorageService.resolve(background), isNotNull);
      // 用户选的原图只读。
      expect(await picked.exists(), isTrue);
    });

    test('the JPEG never overwrites an existing sibling', () async {
      final directory = await Directory(p.join(root.path, 'd')).create();
      await File(p.join(directory.path, 'a.jpg')).writeAsBytes([1]);
      await File(p.join(directory.path, 'a_1.jpg')).writeAsBytes([2]);
      expect(
        HeifImageConverter.jpegSiblingPath(p.join(directory.path, 'a.heic')),
        p.join(directory.path, 'a_2.jpg'),
      );
    });
  });
}
