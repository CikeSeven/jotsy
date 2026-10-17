/// 应用更新的数据模型：地址、Release、安装包与更新清单（版本号见
/// `app_update_version.dart`，接口与校验文件的解析见
/// `app_update_release_parsers.dart`）。
///
/// 纯 Dart（不依赖 Flutter），发布流程的 `tool/write_update_manifest.dart`
/// 也引用这里写出清单，应用与发布脚本共用同一份 schema，不会各写各的。
library;

import 'package:meta/meta.dart';

import 'app_update_version.dart';

export 'app_update_version.dart';

/// 仓库与各类地址。Release 附件、源码文件都走 github.com / raw 域名，
/// 便于整体套上镜像前缀（国内网络下 api.github.com 与附件直连常不可用）。
abstract final class AppUpdateEndpoints {
  static const String owner = 'CikeSeven';
  static const String repo = 'jotsy';

  /// 随 Release 发布的更新清单文件名（见 `release-apk.yml`）。
  static const String manifestFileName = 'jotsy-update.json';

  /// 随 Release 发布的校验文件（`sha256sum` 输出）。
  static const String checksumsFileName = 'SHA256SUMS.txt';

  /// 最新正式版的清单：GitHub 把 `releases/latest/download/<文件>` 跳转到
  /// 最新非预发布版本的同名附件，一个请求即可拿到版本、说明与校验值。
  static final Uri latestManifest = Uri.https(
    'github.com',
    '/$owner/$repo/releases/latest/download/$manifestFileName',
  );

  /// 最新正式版页面；不跟随跳转时 Location 里带有 tag。
  static final Uri latestReleasePage = Uri.https(
    'github.com',
    '/$owner/$repo/releases/latest',
  );

  static final Uri latestReleaseApi = Uri.https(
    'api.github.com',
    '/repos/$owner/$repo/releases/latest',
  );

  static Uri releasePage(String tag) => Uri.https(
    'github.com',
    '/$owner/$repo/releases/tag/${Uri.encodeComponent(tag)}',
  );

  static Uri assetUrl(String tag, String name) => Uri.https(
    'github.com',
    '/$owner/$repo/releases/download/${Uri.encodeComponent(tag)}/'
        '${Uri.encodeComponent(name)}',
  );

  /// 仓库里按版本存放的更新说明：`docs/releases/<tag>.md`（中文）与
  /// `<tag>.en.md`（英文）。
  static Uri releaseNotesFile(String tag, {required bool english}) {
    final file = english ? '$tag.en.md' : '$tag.md';
    return Uri.https(
      'raw.githubusercontent.com',
      '/$owner/$repo/${Uri.encodeComponent(tag)}/docs/releases/'
          '${Uri.encodeComponent(file)}',
    );
  }
}

/// Release 里的一个安装包。
@immutable
class AppUpdateAsset {
  const AppUpdateAsset({
    required this.name,
    required this.url,
    this.size,
    this.sha256,
  });

  final String name;

  /// github.com 上的原始下载地址；镜像线路在下载时再套前缀。
  final Uri url;

  /// 字节数；只从校验文件得到安装包列表时未知。
  final int? size;

  /// 小写十六进制 SHA-256；未知时安装前只校验签名。
  final String? sha256;

  /// 安装包对应的 ABI，从文件名推断；不带 ABI 的视为通用包。
  String? get abi => abiFromName(name);

  /// 识别文件名里的 ABI。`x86_64` 须先于 `x86` 判断。
  static String? abiFromName(String name) {
    final lower = name.toLowerCase();
    for (final abi in supportedAbiNames) {
      if (lower.contains(abi)) {
        return abi;
      }
    }
    return null;
  }

  static const List<String> supportedAbiNames = <String>[
    'arm64-v8a',
    'armeabi-v7a',
    'x86_64',
    'x86',
  ];

  static String? normalizeSha256(Object? raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    final hex = value.startsWith('sha256:') ? value.substring(7) : value;
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(hex) ? hex : null;
  }
}

/// 一个可供更新的版本。
@immutable
class AppUpdateRelease {
  const AppUpdateRelease({
    required this.version,
    required this.tag,
    required this.assets,
    this.publishedAt,
    this.notes = const <String, String>{},
    this.fallbackNotes,
  });

  final AppVersion version;
  final String tag;
  final List<AppUpdateAsset> assets;
  final DateTime? publishedAt;

  /// 按语言代码（`zh`、`en`）存放的更新说明（Markdown，已清理）。
  final Map<String, String> notes;

  /// 不知道语言的说明（Release 正文），找不到对应语言时使用。
  final String? fallbackNotes;

  Uri get pageUrl => AppUpdateEndpoints.releasePage(tag);

  /// [languageCode] 的说明，依次回落到 Release 正文与任一语言。
  String? notesFor(String languageCode) {
    final exact = notes[languageCode];
    if (exact != null && exact.isNotEmpty) {
      return exact;
    }
    final fallback = fallbackNotes;
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    for (final value in notes.values) {
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  /// 按设备支持的 ABI 顺序（`Build.SUPPORTED_ABIS`，首选在前）挑安装包；
  /// 都不匹配时用通用包。分包发布没有通用包，挑错 ABI 的包装不上，
  /// 所以宁可返回 null 让用户去 Release 页手动选择。
  AppUpdateAsset? assetFor(List<String> supportedAbis) {
    for (final abi in supportedAbis) {
      for (final asset in assets) {
        if (asset.abi == abi) {
          return asset;
        }
      }
    }
    for (final asset in assets) {
      if (asset.abi == null) {
        return asset;
      }
    }
    return null;
  }

  AppUpdateRelease copyWith({
    Map<String, String>? notes,
    String? fallbackNotes,
  }) {
    return AppUpdateRelease(
      version: version,
      tag: tag,
      assets: assets,
      publishedAt: publishedAt,
      notes: notes ?? this.notes,
      fallbackNotes: fallbackNotes ?? this.fallbackNotes,
    );
  }
}

/// Release 附件 `jotsy-update.json` 的读写。
///
/// ```json
/// {"schema":1,"version":"0.6.1+18","tag":"v0.6.1",
///  "publishedAt":"2026-10-20T08:00:00Z",
///  "notes":{"zh":"...","en":"..."},
///  "assets":[{"name":"jotsy-v0.6.1-arm64-v8a.apk","size":1,"sha256":"..."}]}
/// ```
/// 下载地址由 tag 与文件名推出，不写进清单，镜像前缀由应用决定。
abstract final class AppUpdateManifest {
  static const int schema = 1;

  static Map<String, Object?> toJson({
    required String version,
    required String tag,
    required List<AppUpdateAsset> assets,
    DateTime? publishedAt,
    Map<String, String> notes = const <String, String>{},
  }) {
    return <String, Object?>{
      'schema': schema,
      'version': version,
      'tag': tag,
      if (publishedAt != null)
        'publishedAt': publishedAt.toUtc().toIso8601String(),
      'notes': notes,
      'assets': <Map<String, Object?>>[
        for (final asset in assets)
          <String, Object?>{
            'name': asset.name,
            if (asset.abi != null) 'abi': asset.abi,
            if (asset.size != null) 'size': asset.size,
            if (asset.sha256 != null) 'sha256': asset.sha256,
          },
      ],
    };
  }

  /// 解析清单；schema 更高（未来格式）或缺少必要字段时返回 null，
  /// 由调用方回落到其他途径。单个附件字段不合法时只跳过该附件。
  static AppUpdateRelease? parse(Object? json) {
    if (json is! Map) {
      return null;
    }
    final schemaValue = json['schema'];
    if (schemaValue is! int || schemaValue > schema) {
      return null;
    }
    final tag = json['tag'];
    final version = AppVersion.tryParse(json['version']?.toString());
    if (tag is! String || tag.trim().isEmpty || version == null) {
      return null;
    }
    final assets = <AppUpdateAsset>[];
    final rawAssets = json['assets'];
    if (rawAssets is List) {
      for (final raw in rawAssets.whereType<Map>()) {
        final name = raw['name'];
        if (name is! String || !name.toLowerCase().endsWith('.apk')) {
          continue;
        }
        final size = raw['size'];
        assets.add(
          AppUpdateAsset(
            name: name,
            url: AppUpdateEndpoints.assetUrl(tag, name),
            size: size is int && size > 0 ? size : null,
            sha256: AppUpdateAsset.normalizeSha256(raw['sha256']),
          ),
        );
      }
    }
    if (assets.isEmpty) {
      return null;
    }
    final notes = <String, String>{};
    final rawNotes = json['notes'];
    if (rawNotes is Map) {
      for (final MapEntry(:key, :value) in rawNotes.entries) {
        if (key is String && value is String) {
          final cleaned = cleanReleaseNotes(value);
          if (cleaned.isNotEmpty) {
            notes[key] = cleaned;
          }
        }
      }
    }
    return AppUpdateRelease(
      version: version,
      tag: tag.trim(),
      assets: assets,
      publishedAt: DateTime.tryParse(json['publishedAt']?.toString() ?? ''),
      notes: notes,
    );
  }
}

/// 清理本项目 Release 说明里只对网页有意义的部分：开头的
/// `# Release vX` 标题（页面已显示版本号）、语言切换行
/// （`[English](...) | 简体中文`）与 `**Full Changelog**` 链接。
String cleanReleaseNotes(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final kept = <String>[];
  var sawContent = false;
  for (final line in lines) {
    final trimmed = line.trim();
    if (!sawContent && trimmed.startsWith('# ')) {
      sawContent = true;
      continue;
    }
    if (trimmed.isNotEmpty) {
      sawContent = true;
    }
    final isLanguageSwitch =
        trimmed.contains('|') &&
        trimmed.contains('English') &&
        trimmed.contains('简体中文');
    if (isLanguageSwitch || trimmed.startsWith('**Full Changelog**')) {
      continue;
    }
    kept.add(line.trimRight());
  }
  return kept.join('\n').trim();
}
