import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'diary_imported_font.dart';
import 'font_file_info.dart';

export 'diary_imported_font.dart';

/// 导入失败原因，界面据此给出具体提示。
enum DiaryFontImportFailure { unsupportedFormat, unreadable }

class DiaryFontImportException implements Exception {
  const DiaryFontImportException(this.failure);

  final DiaryFontImportFailure failure;

  @override
  String toString() => 'DiaryFontImportException($failure)';
}

/// 管理导入的正文字体：复制文件、维护清单、向引擎注册。
///
/// - 存储：应用支持目录下的 `diary_fonts/`，不在文档目录，因此不会被日记媒体
///   回收或完整备份打包；备份只带排版偏好里的字体 id，换机后需重新导入。
/// - 清单：同目录 `fonts.json`。写入经临时文件再改名，进程中断时不会留下半份
///   清单；清单与文件不一致时（文件被系统清理）以文件为准，缺文件的条目不列出。
/// - 注册：`FontLoader` 的注册是进程级的且无法撤销，同一字体每个进程只注册
///   一次（静态缓存）；删除字体后已注册的字面留到进程结束，不影响正确性。
/// - 指纹：清单条目可带文件内容的 SHA-256（[contentFingerprints] 第一次需要
///   时补算并写回），局域网同步靠它在两台设备之间认出同一款字体。
/// - 并发：导入、删除与补写指纹串行执行，避免两次写清单互相覆盖。
class DiaryFontStorageService {
  DiaryFontStorageService({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory;

  static const String directoryName = 'diary_fonts';
  static const String _manifestFileName = 'fonts.json';

  /// 引擎字族名前缀；与内置字体、系统字体名都不会冲突。
  static const String _familyPrefix = 'JotsyDiaryFont_';

  static final Map<String, Future<String>> _registrations =
      <String, Future<String>>{};

  final Future<Directory> Function() _baseDirectory;
  Future<void> _writeQueue = Future<void>.value();

  static String familyFor(String fontId) => '$_familyPrefix$fontId';

  Future<List<DiaryImportedFont>> listFonts() async {
    final directory = await _fontDirectory();
    final fonts = await _readManifest(directory);
    final present = <DiaryImportedFont>[];
    for (final font in fonts) {
      if (await File(p.join(directory.path, font.fileName)).exists()) {
        present.add(font);
      }
    }
    return present;
  }

  /// 本机导入字体的 id → 文件内容的 SHA-256（小写十六进制），只含文件还在
  /// 的字体。局域网同步据此把设置里只在本机有效的字体 id 换成跨设备的
  /// 引用：两台设备导入同一个文件时 id 不同、指纹相同（#288）。
  ///
  /// 清单里还没有指纹的条目在这里流式计算（不把十几 MB 的中文字体整个读进
  /// 内存），再合进**此刻**的清单写回：写回与导入 / 删除串行，计算期间新
  /// 导入的字体不会被覆盖掉，被删掉的字体也不会被写回来。单个文件读不了时
  /// 跳过这一款（它本来也显示不出来）；写回失败不影响结果，下次再算。
  Future<Map<String, String>> contentFingerprints() async {
    final directory = await _fontDirectory();
    final result = <String, String>{};
    final computed = <String, String>{};
    for (final font in await listFonts()) {
      final known = font.sha256;
      if (known != null) {
        result[font.id] = known;
        continue;
      }
      try {
        final file = File(p.join(directory.path, font.fileName));
        final digest = await crypto.sha256.bind(file.openRead()).first;
        result[font.id] = computed[font.id] = digest.toString();
      } on FileSystemException catch (error) {
        debugPrint('Diary font ${font.id} fingerprint failed: $error');
      }
    }
    if (computed.isEmpty) {
      return result;
    }
    try {
      await _serialized(() async {
        final current = await _readManifest(directory);
        await _writeManifest(directory, <DiaryImportedFont>[
          for (final font in current)
            if (computed[font.id] case final hash? when font.sha256 == null)
              font.withSha256(hash)
            else
              font,
        ]);
      });
    } on Object catch (error) {
      debugPrint('Diary font fingerprints not saved: $error');
    }
    return result;
  }

  /// 校验并复制字体文件，返回新条目；同名且同大小的字体已存在时直接返回
  /// 已有条目，重复选择同一个文件不会堆出多份。
  Future<DiaryImportedFont> importFont(
    String sourcePath, {
    required String languageCode,
  }) {
    return _serialized(() async {
      final Uint8List bytes;
      try {
        bytes = await File(sourcePath).readAsBytes();
      } on FileSystemException {
        throw const DiaryFontImportException(DiaryFontImportFailure.unreadable);
      }
      final info = readFontFileInfo(bytes);
      if (info == null) {
        throw const DiaryFontImportException(
          DiaryFontImportFailure.unsupportedFormat,
        );
      }
      final name =
          info.familyNameFor(languageCode) ??
          p.basenameWithoutExtension(sourcePath);
      final directory = await _fontDirectory();
      final fonts = await _readManifest(directory);
      for (final font in fonts) {
        final file = File(p.join(directory.path, font.fileName));
        if (font.name == name &&
            await file.exists() &&
            await file.length() == bytes.length) {
          return font;
        }
      }
      final id = 'f${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
      final font = DiaryImportedFont(
        id: id,
        name: name,
        fileName: '$id.${info.fileExtension}',
      );
      final target = File(p.join(directory.path, font.fileName));
      await target.writeAsBytes(bytes, flush: true);
      try {
        await _writeManifest(directory, <DiaryImportedFont>[...fonts, font]);
      } catch (_) {
        // 清单没写成功时删掉刚复制的文件，不留下清单之外的孤儿文件。
        await _deleteQuietly(target);
        rethrow;
      }
      return font;
    });
  }

  Future<void> deleteFont(String fontId) {
    return _serialized(() async {
      final directory = await _fontDirectory();
      final fonts = await _readManifest(directory);
      final removed = fonts.where((font) => font.id == fontId).toList();
      if (removed.isEmpty) {
        return;
      }
      await _writeManifest(
        directory,
        fonts.where((font) => font.id != fontId).toList(),
      );
      for (final font in removed) {
        await _deleteQuietly(File(p.join(directory.path, font.fileName)));
      }
    });
  }

  /// 读出导入字体的文件内容（导出时嵌入 PDF、读取字族名）；字体不在清单里
  /// 或文件已缺失时返回 null，调用方回落到内置字体。
  Future<Uint8List?> readFontBytes(String fontId) async {
    final directory = await _fontDirectory();
    final font = (await _readManifest(
      directory,
    )).where((font) => font.id == fontId).firstOrNull;
    if (font == null) {
      return null;
    }
    try {
      return await File(p.join(directory.path, font.fileName)).readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  /// 确保字体已向引擎注册并返回字族名；文件缺失或引擎拒绝时抛出，且不缓存
  /// 失败结果，重新导入后可再次尝试。
  Future<String> loadFontFamily(DiaryImportedFont font) {
    final pending = _registrations[font.id];
    if (pending != null) {
      return pending;
    }
    final registration = _register(font);
    _registrations[font.id] = registration;
    // 块体回调不能写成箭头：remove 返回的正是这个失败的 Future，作为
    // onError 的返回值会被 then 再次链接，错误就成了未处理的异步错误。
    unawaited(
      registration.then<void>(
        (_) {},
        onError: (Object _) {
          _registrations.remove(font.id);
        },
      ),
    );
    return registration;
  }

  Future<String> _register(DiaryImportedFont font) async {
    final directory = await _fontDirectory();
    final bytes = await File(
      p.join(directory.path, font.fileName),
    ).readAsBytes();
    final family = familyFor(font.id);
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
    return family;
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _writeQueue.then((_) => action());
    _writeQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Directory> _fontDirectory() async {
    final base = await _baseDirectory();
    final directory = Directory(p.join(base.path, directoryName));
    await directory.create(recursive: true);
    return directory;
  }

  Future<List<DiaryImportedFont>> _readManifest(Directory directory) async {
    final file = File(p.join(directory.path, _manifestFileName));
    if (!await file.exists()) {
      return <DiaryImportedFont>[];
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        return <DiaryImportedFont>[];
      }
      return decoded
          .map(DiaryImportedFont.tryParse)
          .whereType<DiaryImportedFont>()
          .toList();
    } on FormatException {
      // 清单损坏时视为空：字体文件仍在，重新导入即可恢复，不阻断正文显示。
      return <DiaryImportedFont>[];
    }
  }

  Future<void> _writeManifest(
    Directory directory,
    List<DiaryImportedFont> fonts,
  ) async {
    final target = File(p.join(directory.path, _manifestFileName));
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(fonts.map((font) => font.toJson()).toList()),
      flush: true,
    );
    await temporary.rename(target.path);
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // 删除失败只会留下不在清单里的文件，不影响列表与显示。
    }
  }
}
