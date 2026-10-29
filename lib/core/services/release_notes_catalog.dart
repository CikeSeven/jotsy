/// 打包进应用的各版本更新说明（仓库的 `docs/releases/`，在 pubspec 的
/// assets 里登记），供设置 → 关于 → 更新日志离线阅读。
///
/// 输入：资源包（`rootBundle`，测试可替换）与界面语言；输出：按版本从新到
/// 旧排列的说明，正文已经 [cleanReleaseNotes] 去掉只对网页有意义的标题与
/// 语言切换行。只读资源，不联网、不写任何文件。
///
/// 文件命名沿用发布流程（AGENTS.md：每个版本在 `docs/releases/` 写好
/// `<tag>.md` / `<tag>.en.md`）：`<tag>.md` 为中文、`<tag>.en.md` 为英文；
/// 早期个别版本另有一份与 `<tag>.md` 相同的 `<tag>.zh.md`，同一版本两份中文
/// 时取 `<tag>.md`。文件名不是合法版本号的一律忽略，新版本的说明随下次构建
/// 自动出现，不需要另外维护目录。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_update_models.dart';

/// 更新说明在资源包里的目录（与 pubspec 的 assets 条目一致）。
const String kReleaseNotesAssetDir = 'docs/releases/';

/// 一个版本选定语言后的说明文件。
@immutable
class ReleaseNotesAsset {
  const ReleaseNotesAsset({
    required this.tag,
    required this.version,
    required this.path,
  });

  /// 文件名里的版本标记，如 `v0.9.0`、`v0.4.5+11`。
  final String tag;
  final AppVersion version;

  /// 资源路径。
  final String path;
}

/// 一个版本的说明正文（Markdown，已清理）。
@immutable
class BundledReleaseNotes {
  const BundledReleaseNotes({
    required this.tag,
    required this.version,
    required this.markdown,
  });

  final String tag;
  final AppVersion version;
  final String markdown;
}

/// 从资源清单的全部路径里挑出更新说明：每个版本按 [languageCode] 选一份
/// （中文界面依次取 `<tag>.md`、`<tag>.zh.md`、`<tag>.en.md`，其余语言先取
/// 英文），缺少这种语言时回落到另一种，版本从新到旧排列。
List<ReleaseNotesAsset> pickReleaseNotesAssets(
  Iterable<String> assetPaths, {
  required String languageCode,
}) {
  // tag → 语言变体 → 路径；同一语言里的优先级见下面的 order。
  final byTag = <String, Map<_NotesVariant, String>>{};
  final versions = <String, AppVersion>{};
  for (final path in assetPaths) {
    final parsed = _parseNotesPath(path);
    if (parsed == null) {
      continue;
    }
    versions[parsed.tag] = parsed.version;
    byTag.putIfAbsent(
      parsed.tag,
      () => <_NotesVariant, String>{},
    )[parsed.variant] = path;
  }
  final order = languageCode == 'zh'
      ? const <_NotesVariant>[
          _NotesVariant.zh,
          _NotesVariant.zhAlias,
          _NotesVariant.en,
        ]
      : const <_NotesVariant>[
          _NotesVariant.en,
          _NotesVariant.zh,
          _NotesVariant.zhAlias,
        ];
  final picked = <ReleaseNotesAsset>[
    for (final MapEntry(key: tag, value: variants) in byTag.entries)
      ReleaseNotesAsset(
        tag: tag,
        version: versions[tag]!,
        path: variants[order.firstWhere(variants.containsKey)]!,
      ),
  ];
  // 版本相同（只差构建号且一边没写）时按 tag 排，保证顺序稳定。
  picked.sort((a, b) {
    final byVersion = b.version.compareTo(a.version);
    return byVersion != 0 ? byVersion : b.tag.compareTo(a.tag);
  });
  return picked;
}

/// 读取 [bundle] 里全部版本的说明（语言见 [pickReleaseNotesAssets]）。
///
/// 单个文件读不出或清理后为空时跳过这一版，不影响其余版本；资源清单本身
/// 读不出时照常抛出，由调用方决定如何呈现。
Future<List<BundledReleaseNotes>> loadBundledReleaseNotes(
  AssetBundle bundle, {
  required String languageCode,
}) async {
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final assets = pickReleaseNotesAssets(
    manifest.listAssets(),
    languageCode: languageCode,
  );
  final loaded = await Future.wait(<Future<BundledReleaseNotes?>>[
    for (final asset in assets) _loadOne(bundle, asset),
  ]);
  return List<BundledReleaseNotes>.unmodifiable(loaded.nonNulls);
}

Future<BundledReleaseNotes?> _loadOne(
  AssetBundle bundle,
  ReleaseNotesAsset asset,
) async {
  try {
    final markdown = cleanReleaseNotes(await bundle.loadString(asset.path));
    if (markdown.isEmpty) {
      return null;
    }
    return BundledReleaseNotes(
      tag: asset.tag,
      version: asset.version,
      markdown: markdown,
    );
  } catch (error) {
    debugPrint('Release notes ${asset.path} failed to load: $error');
    return null;
  }
}

/// 同一版本的说明文件：中文（`<tag>.md`）、早期重复的中文（`<tag>.zh.md`）
/// 与英文（`<tag>.en.md`）。
enum _NotesVariant { zh, zhAlias, en }

({String tag, AppVersion version, _NotesVariant variant})? _parseNotesPath(
  String path,
) {
  if (!path.startsWith(kReleaseNotesAssetDir) || !path.endsWith('.md')) {
    return null;
  }
  final name = path.substring(
    kReleaseNotesAssetDir.length,
    path.length - '.md'.length,
  );
  if (name.contains('/')) {
    return null;
  }
  final (tag, variant) = switch (name) {
    _ when name.endsWith('.en') => (
      name.substring(0, name.length - 3),
      _NotesVariant.en,
    ),
    _ when name.endsWith('.zh') => (
      name.substring(0, name.length - 3),
      _NotesVariant.zhAlias,
    ),
    _ => (name, _NotesVariant.zh),
  };
  final version = AppVersion.tryParse(tag);
  if (version == null) {
    return null;
  }
  return (tag: tag, version: version, variant: variant);
}
