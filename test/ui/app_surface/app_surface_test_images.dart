import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:node_diary/ui/app_surface/services/app_background_image_cache.dart';
import 'package:node_diary/ui/app_surface/services/app_background_image_pipeline.dart';
import 'package:path/path.dart' as p;

/// 背景测试共用的图片工具：在测试里画色块生成位图 / PNG 文件。
///
/// 真实解码与 `toImage` 依赖真实的异步：在 widget 测试里要放进
/// `tester.runAsync`，普通 `test` 里直接 await 即可。

/// 画一张 [width]×[height] 的图：左半 [left]，右半 [right]（缺省同 [left]）。
Future<ui.Image> paintedImage(
  int width,
  int height,
  Color left, [
  Color? right,
]) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final half = width / 2;
  canvas
    ..drawRect(
      Rect.fromLTWH(0, 0, half, height.toDouble()),
      Paint()..color = left,
    )
    ..drawRect(
      Rect.fromLTWH(half, 0, width - half, height.toDouble()),
      Paint()..color = right ?? left,
    );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}

/// 把 [paintedImage] 编码成 PNG 写进 [directory]/[name]，返回文件。
Future<File> writePng(
  Directory directory,
  String name,
  int width,
  int height,
  Color left, [
  Color? right,
]) async {
  final image = await paintedImage(width, height, left, right);
  final ByteData? data;
  try {
    data = await image.toByteData(format: ui.ImageByteFormat.png);
  } finally {
    image.dispose();
  }
  final file = File(p.join(directory.path, name));
  await file.writeAsBytes(data!.buffer.asUint8List());
  return file;
}

/// 读回整张图的像素（未预乘 RGBA），按 (x, y) 取颜色。
Future<Color Function(int x, int y)> pixelReader(ui.Image image) async {
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final bytes = data!.buffer.asUint8List();
  return (int x, int y) {
    final i = (y * image.width + x) * 4;
    return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
  };
}

/// 不读文件、直接产出纯色图的加载函数（缓存与渲染测试用）；记录每次请求。
class FakeBackgroundLoader {
  FakeBackgroundLoader({this.color = const Color(0xFF3060C0)});

  final Color color;
  final List<AppBackgroundImageKey> requests = <AppBackgroundImageKey>[];
  final List<ui.Image> produced = <ui.Image>[];

  /// 这里列出的文件名当作缺失文件（加载得到 null）。
  final Set<String> missing = <String>{};

  Future<AppBackgroundDecoded?> call(AppBackgroundImageKey key) async {
    requests.add(key);
    if (missing.contains(key.fileName)) return null;
    final image = await paintedImage(8, 8, color);
    produced.add(image);
    return AppBackgroundDecoded(image, color);
  }
}
