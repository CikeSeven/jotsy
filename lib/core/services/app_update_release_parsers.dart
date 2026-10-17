/// 清单之外的两种版本来源：GitHub 接口返回与 Release 的校验文件。
/// 纯 Dart，供 `AppUpdateChecker` 使用。
library;

import 'app_update_models.dart';

/// 解析 GitHub `releases/latest` 接口的返回。附件的 `digest` 字段
/// （`sha256:...`）用于下载后校验。
AppUpdateRelease? parseGitHubRelease(Object? json) {
  if (json is! Map) {
    return null;
  }
  final tag = json['tag_name']?.toString().trim();
  final version = AppVersion.tryParse(tag);
  if (tag == null || version == null) {
    return null;
  }
  final assets = <AppUpdateAsset>[];
  final rawAssets = json['assets'];
  if (rawAssets is List) {
    for (final raw in rawAssets.whereType<Map>()) {
      final name = raw['name']?.toString() ?? '';
      if (!name.toLowerCase().endsWith('.apk')) {
        continue;
      }
      final size = raw['size'];
      assets.add(
        AppUpdateAsset(
          name: name,
          url: AppUpdateEndpoints.assetUrl(tag, name),
          size: size is int && size > 0 ? size : null,
          sha256: AppUpdateAsset.normalizeSha256(raw['digest']),
        ),
      );
    }
  }
  if (assets.isEmpty) {
    return null;
  }
  final body = cleanReleaseNotes(json['body']?.toString() ?? '');
  return AppUpdateRelease(
    version: version,
    tag: tag,
    assets: assets,
    publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
    fallbackNotes: body.isEmpty ? null : body,
  );
}

/// 只知道 tag 时（清单与接口都不可用），由该版本的 `SHA256SUMS.txt`
/// （`sha256sum` 输出：`<64 位十六进制>  <文件名>`）得到安装包列表与校验值。
///
/// 为什么不按命名规则直接推出地址：Release 发布后 `releases/latest` 立刻指向
/// 新 tag，而签名安装包要等构建完成（数十分钟）才上传；校验文件与安装包同批
/// 上传，读得到它才说明安装包已就绪，否则会提示一个下载必然 404 的版本。
AppUpdateRelease? releaseFromChecksums(String tag, String checksums) {
  final version = AppVersion.tryParse(tag);
  if (version == null) {
    return null;
  }
  final line = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(\S+\.apk)\s*$');
  final assets = <AppUpdateAsset>[];
  for (final raw in checksums.split('\n')) {
    final match = line.firstMatch(raw.trim());
    if (match == null) {
      continue;
    }
    final name = match.group(2)!;
    assets.add(
      AppUpdateAsset(
        name: name,
        url: AppUpdateEndpoints.assetUrl(tag, name),
        sha256: match.group(1)!.toLowerCase(),
      ),
    );
  }
  if (assets.isEmpty) {
    return null;
  }
  return AppUpdateRelease(version: version, tag: tag, assets: assets);
}
