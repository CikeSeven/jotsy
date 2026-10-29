import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 只含给定文件的资源包：资源清单（`AssetManifest.bin`）按 Flutter 构建产物
/// 的格式由 [files] 的路径生成，[unreadable] 里的路径出现在清单里但读取时
/// 抛错，用来模拟单个文件损坏。
class FakeReleaseNotesBundle extends CachingAssetBundle {
  FakeReleaseNotesBundle(
    this.files, {
    this.unreadable = const <String>{},
    this.manifestFails = false,
  });

  final Map<String, String> files;
  final Set<String> unreadable;

  /// 为 true 时资源清单本身读不出。
  final bool manifestFails;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      if (manifestFails) {
        throw FlutterError('Unable to load asset: $key');
      }
      return const StandardMessageCodec().encodeMessage(<Object?, Object?>{
        for (final path in <String>{...files.keys, ...unreadable})
          path: <Object?>[
            <Object?, Object?>{'asset': path},
          ],
      })!;
    }
    final text = files[key];
    if (text == null || unreadable.contains(key)) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.sublistView(utf8.encode(text));
  }
}

/// 按发布流程格式写的一篇说明：标题、语言切换行与“版本要点”开头。
String releaseNotesMarkdown(
  String tag, {
  bool english = false,
  List<String> highlights = const <String>['A highlight'],
  String rest = '',
}) {
  final buffer = StringBuffer()
    ..writeln('# Release $tag')
    ..writeln()
    ..writeln(
      english
          ? 'English | [简体中文](./$tag.md)'
          : '[English](./$tag.en.md) | 简体中文',
    )
    ..writeln()
    ..writeln(english ? '## Highlights' : '## 版本要点');
  for (final item in highlights) {
    buffer.writeln('- $item');
  }
  if (rest.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(rest);
  }
  return buffer.toString();
}
