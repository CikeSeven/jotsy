/// 生成应用内更新清单 `jotsy-update.json`（schema 见 `AppUpdateManifest`），
/// 供 `tool/write_update_manifest.dart` 与测试共用。
///
/// 输入：pubspec 文本、发布 tag、存放安装包（签名 APK 与桌面安装包）的目录与
/// 版本说明目录；
/// 输出：清单 JSON 文本。只读文件，不依赖 Flutter——清单的读写共用应用里的
/// `AppUpdateManifest`，发布脚本与应用的 schema 不会各写各的。
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:node_diary/core/services/app_update_models.dart';
import 'package:path/path.dart' as p;

/// pubspec.yaml 的 `version`（含构建号）；只取单行写法，避免为脚本引入 yaml。
String? readPubspecVersion(String pubspec) {
  final match = RegExp(
    r'''^version:\s*["']?([^\s"']+)''',
    multiLine: true,
  ).firstMatch(pubspec);
  return match?.group(1);
}

/// [directory] 下的全部安装包（按文件名排序）：Android 的 `.apk` 与桌面的
/// 安装程序 / 便携版 / 压缩包（`AppUpdateAsset.isPackageName`），逐个流式
/// 计算 SHA-256。校验文件与清单本身不算。
Future<List<AppUpdateAsset>> collectReleaseAssets(
  Directory directory,
  String tag,
) async {
  final files =
      directory
          .listSync()
          .whereType<File>()
          .where((file) => AppUpdateAsset.isPackageName(p.basename(file.path)))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return <AppUpdateAsset>[
    for (final file in files)
      AppUpdateAsset(
        name: p.basename(file.path),
        url: AppUpdateEndpoints.assetUrl(tag, p.basename(file.path)),
        size: await file.length(),
        sha256: (await sha256.bind(file.openRead()).first).toString(),
      ),
  ];
}

/// 仓库里该版本的说明：`<tag>.md` 为中文、`<tag>.en.md` 为英文。中文文件
/// 不存在时使用 [fallbackZh]（Release 正文）。
Map<String, String> collectReleaseNotes({
  required Directory directory,
  required String tag,
  String? fallbackZh,
}) {
  String? read(String name) {
    final file = File(p.join(directory.path, name));
    if (!file.existsSync()) {
      return null;
    }
    final text = file.readAsStringSync().trim();
    return text.isEmpty ? null : text;
  }

  final zh = read('$tag.md') ?? fallbackZh?.trim();
  final en = read('$tag.en.md');
  return <String, String>{if (zh != null && zh.isNotEmpty) 'zh': zh, 'en': ?en};
}

/// 组装清单 JSON。版本取 pubspec（含构建号，应用据此精确比较）；tag 若是
/// 版本号，须与 pubspec 一致（发布流程的 check-version 也会拦下）。桌面安装包
/// 与 APK 写进同一个 `assets` 列表（旧版应用只认 `.apk`，其余跳过）；没有
/// APK（旧版应用会把清单当作无效）、版本无法解析时抛出 [StateError]。
Future<String> buildUpdateManifest({
  required String pubspec,
  required String tag,
  required Directory artifacts,
  required Directory releaseNotes,
  DateTime? publishedAt,
  String? fallbackNotes,
}) async {
  final version = readPubspecVersion(pubspec);
  final parsed = AppVersion.tryParse(version);
  if (version == null || parsed == null) {
    throw StateError('Cannot read a version from pubspec.yaml');
  }
  final tagVersion = AppVersion.tryParse(tag);
  if (tagVersion != null && tagVersion.compareTo(parsed) != 0) {
    throw StateError('Tag $tag does not match pubspec version $version');
  }
  final assets = await collectReleaseAssets(artifacts, tag);
  if (!assets.any((asset) => AppUpdateAsset.isApkName(asset.name))) {
    throw StateError('No APK found in ${artifacts.path}');
  }
  final json = AppUpdateManifest.toJson(
    version: version,
    tag: tag,
    publishedAt: publishedAt,
    notes: collectReleaseNotes(
      directory: releaseNotes,
      tag: tag,
      fallbackZh: fallbackNotes,
    ),
    assets: assets,
  );
  // 写出前用应用的解析器读一遍：解析不了的清单不发布。
  if (AppUpdateManifest.parse(json) == null) {
    throw StateError('Generated manifest cannot be parsed by the app');
  }
  return '${const JsonEncoder.withIndent('  ').convert(json)}\n';
}
