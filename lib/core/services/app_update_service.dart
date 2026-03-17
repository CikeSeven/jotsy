import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'settings_service.dart';

enum AppUpdateCheckStatus { upToDate, updateAvailable, failed }

class AppUpdateCheckResult {
  const AppUpdateCheckResult._({
    required this.status,
    this.latestVersion,
    this.downloadUrl,
    this.releaseNotes,
  });

  factory AppUpdateCheckResult.upToDate({required String latestVersion}) {
    return AppUpdateCheckResult._(
      status: AppUpdateCheckStatus.upToDate,
      latestVersion: latestVersion,
    );
  }

  factory AppUpdateCheckResult.updateAvailable({
    required String latestVersion,
    required String downloadUrl,
    String? releaseNotes,
  }) {
    return AppUpdateCheckResult._(
      status: AppUpdateCheckStatus.updateAvailable,
      latestVersion: latestVersion,
      downloadUrl: downloadUrl,
      releaseNotes: releaseNotes,
    );
  }

  factory AppUpdateCheckResult.failed() {
    return const AppUpdateCheckResult._(status: AppUpdateCheckStatus.failed);
  }

  final AppUpdateCheckStatus status;
  final String? latestVersion;
  final String? downloadUrl;
  final String? releaseNotes;
}

/// 应用更新检查服务。
///
/// 处理链路：
/// 1) 解析 `releases/latest` 获取最新 tag；
/// 2) 抓取 release 页面并提取 APK 资源链接；
/// 3) 直连优先，失败时自动回退镜像；
/// 4) 记录可用入口索引，下次从上次可用入口开始轮询。
class AppUpdateService {
  AppUpdateService({HttpClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? HttpClient.new;

  static const String _repoOwner = 'CikeSeven';
  static const String _repoName = 'jotsy';
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const String _userAgent = 'jotsy-app-update-checker/1.0';

  static final Uri _latestReleaseApiUri = Uri.https(
    'api.github.com',
    '/repos/$_repoOwner/$_repoName/releases/latest',
  );

  static final Uri _latestReleaseUri = Uri.https(
    'github.com',
    '/$_repoOwner/$_repoName/releases/latest',
  );

  static final List<_ReleaseAccessChannel> _channels = <_ReleaseAccessChannel>[
    const _ReleaseAccessChannel(
      index: 0,
      id: 'direct',
      proxyPrefix: null,
      supportsLatestLookup: true,
    ),
    const _ReleaseAccessChannel(
      index: 1,
      id: 'ghfast',
      proxyPrefix: 'https://ghfast.top/',
      supportsLatestLookup: true,
    ),
    // 该镜像在 APK 下载可用，但 latest 跳转页返回 502，因此仅参与下载回退。
    const _ReleaseAccessChannel(
      index: 2,
      id: 'ghproxy_net',
      proxyPrefix: 'https://ghproxy.net/',
      supportsLatestLookup: false,
    ),
  ];

  final HttpClient Function() _clientFactory;

  Future<AppUpdateCheckResult> checkLatestRelease({
    required SettingsService settingsService,
  }) async {
    final currentVersion = await _readCurrentVersion();
    final latestRelease = await _resolveLatestRelease(
      settingsService: settingsService,
    );
    if (latestRelease == null) {
      return AppUpdateCheckResult.failed();
    }

    if (_compareVersion(currentVersion, latestRelease.tagName) >= 0) {
      return AppUpdateCheckResult.upToDate(
        latestVersion: latestRelease.tagName,
      );
    }

    final downloadUrl = await _resolveDownloadUrl(
      settingsService: settingsService,
      apkUrls: latestRelease.apkUrls,
    );
    if (downloadUrl == null) {
      return AppUpdateCheckResult.failed();
    }
    return AppUpdateCheckResult.updateAvailable(
      latestVersion: latestRelease.tagName,
      downloadUrl: downloadUrl,
      releaseNotes: latestRelease.releaseNotes,
    );
  }

  Future<String> _readCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.trim();
    if (build.isEmpty) {
      return info.version;
    }
    return '${info.version}+$build';
  }

  Future<_ResolvedRelease?> _resolveLatestRelease({
    required SettingsService settingsService,
  }) async {
    final apiRelease = await _fetchLatestReleaseByApi();
    if (apiRelease != null) {
      await settingsService.setReleaseMirrorStartIndex(0);
      return apiRelease;
    }

    final startIndex = _normalizeStartIndex(
      settingsService.releaseMirrorStartIndexRaw,
    );
    final lookupChannels = _lookupChannelsInOrder(
      startIndex: startIndex,
      latestOnly: true,
    );

    for (final channel in lookupChannels) {
      final latestTag = await _fetchLatestTag(channel.wrap(_latestReleaseUri));
      if (latestTag == null || latestTag.isEmpty) {
        continue;
      }
      final tagPageUri = Uri.https(
        'github.com',
        '/$_repoOwner/$_repoName/releases/tag/${Uri.encodeComponent(latestTag)}',
      );
      final apkUrls = await _fetchApkLinks(channel.wrap(tagPageUri));
      if (apkUrls.isEmpty) {
        continue;
      }
      await settingsService.setReleaseMirrorStartIndex(channel.index);
      return _ResolvedRelease(
        tagName: latestTag,
        apkUrls: apkUrls,
        releaseNotes: null,
      );
    }
    return null;
  }

  Future<_ResolvedRelease?> _fetchLatestReleaseByApi() async {
    final client = _clientFactory();
    try {
      client.connectionTimeout = _requestTimeout;
      final request = await client
          .getUrl(_latestReleaseApiUri)
          .timeout(_requestTimeout);
      _applyHeaders(request, expectJson: true);
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 400) {
        await response.drain<void>();
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final latestTag = decoded['tag_name']?.toString().trim();
      if (latestTag == null || latestTag.isEmpty) {
        return null;
      }
      final assets = decoded['assets'];
      if (assets is! List) {
        return null;
      }
      final apkUrls = <Uri>[];
      for (final item in assets.whereType<Map>()) {
        final value = item['browser_download_url']?.toString().trim();
        if (value == null || !value.toLowerCase().endsWith('.apk')) {
          continue;
        }
        final uri = Uri.tryParse(value);
        if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
          continue;
        }
        apkUrls.add(uri);
      }
      if (apkUrls.isEmpty) {
        return null;
      }
      final releaseNotes = decoded['body']?.toString();
      return _ResolvedRelease(
        tagName: latestTag,
        apkUrls: apkUrls,
        releaseNotes: releaseNotes,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> _resolveDownloadUrl({
    required SettingsService settingsService,
    required List<Uri> apkUrls,
  }) async {
    final prioritizedApkUrls = _sortApkUrls(apkUrls);
    final startIndex = _normalizeStartIndex(
      settingsService.releaseMirrorStartIndexRaw,
    );
    final channels = _lookupChannelsInOrder(
      startIndex: startIndex,
      latestOnly: false,
    );

    for (final channel in channels) {
      for (final source in prioritizedApkUrls) {
        final candidate = channel.wrap(source);
        if (await _isReachable(candidate)) {
          await settingsService.setReleaseMirrorStartIndex(channel.index);
          return candidate.toString();
        }
      }
    }
    return null;
  }

  int _normalizeStartIndex(int raw) {
    if (_channels.isEmpty) {
      return 0;
    }
    final normalized = raw % _channels.length;
    return normalized < 0 ? normalized + _channels.length : normalized;
  }

  List<_ReleaseAccessChannel> _lookupChannelsInOrder({
    required int startIndex,
    required bool latestOnly,
  }) {
    final ordered = <_ReleaseAccessChannel>[];
    for (var offset = 0; offset < _channels.length; offset++) {
      final index = (startIndex + offset) % _channels.length;
      final channel = _channels[index];
      if (latestOnly && !channel.supportsLatestLookup) {
        continue;
      }
      ordered.add(channel);
    }
    return ordered;
  }

  Future<String?> _fetchLatestTag(Uri latestUri) async {
    final client = _clientFactory();
    try {
      client.connectionTimeout = _requestTimeout;
      final request = await client.getUrl(latestUri).timeout(_requestTimeout);
      _applyHeaders(request);
      request.followRedirects = false;
      final response = await request.close().timeout(_requestTimeout);
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location != null && location.isNotEmpty) {
        await response.drain<void>();
        return _extractTag(location);
      }
      final body = await response.transform(utf8.decoder).join();
      return _extractTag(body);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<Uri>> _fetchApkLinks(Uri releasePageUri) async {
    final client = _clientFactory();
    try {
      client.connectionTimeout = _requestTimeout;
      final request = await client
          .getUrl(releasePageUri)
          .timeout(_requestTimeout);
      _applyHeaders(request);
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 400) {
        await response.drain<void>();
        return const <Uri>[];
      }
      final body = await response.transform(utf8.decoder).join();
      final exp = RegExp(r'href="([^"]+\.apk[^"]*)"');
      final links = <Uri>[];
      final seen = <String>{};
      for (final match in exp.allMatches(body)) {
        final raw = (match.group(1) ?? '').replaceAll('&amp;', '&').trim();
        if (raw.isEmpty) {
          continue;
        }
        Uri? parsed;
        if (raw.startsWith('/')) {
          parsed = Uri.parse('https://github.com$raw');
        } else {
          final uri = Uri.tryParse(raw);
          if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
            parsed = uri;
          }
        }
        if (parsed == null) {
          continue;
        }
        final key = parsed.toString();
        if (seen.add(key)) {
          links.add(parsed);
        }
      }
      return links;
    } catch (_) {
      return const <Uri>[];
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _isReachable(Uri uri) async {
    final client = _clientFactory();
    try {
      client.connectionTimeout = _requestTimeout;
      final request = await client.headUrl(uri).timeout(_requestTimeout);
      _applyHeaders(request);
      request.followRedirects = true;
      final response = await request.close().timeout(_requestTimeout);
      final ok = response.statusCode >= 200 && response.statusCode < 400;
      await response.drain<void>();
      if (ok) {
        return true;
      }
      if (response.statusCode != HttpStatus.methodNotAllowed) {
        return false;
      }
    } catch (_) {
      // HEAD 被网关拒绝时，降级为小范围 GET 探测，避免直接下载完整 APK。
    } finally {
      client.close(force: true);
    }

    final fallbackClient = _clientFactory();
    try {
      fallbackClient.connectionTimeout = _requestTimeout;
      final request = await fallbackClient.getUrl(uri).timeout(_requestTimeout);
      _applyHeaders(request);
      request.followRedirects = true;
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final response = await request.close().timeout(_requestTimeout);
      final ok =
          response.statusCode == HttpStatus.partialContent ||
          (response.statusCode >= 200 && response.statusCode < 400);
      await response.drain<void>();
      return ok;
    } catch (_) {
      return false;
    } finally {
      fallbackClient.close(force: true);
    }
  }

  void _applyHeaders(HttpClientRequest request, {bool expectJson = false}) {
    request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    request.headers.set(
      HttpHeaders.acceptHeader,
      expectJson ? 'application/vnd.github+json' : 'text/html,*/*;q=0.9',
    );
  }

  String? _extractTag(String raw) {
    final match = RegExp("/releases/tag/([^\"'\\s?#]+)").firstMatch(raw);
    if (match == null) {
      return null;
    }
    final token = match.group(1);
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    return Uri.decodeComponent(token).trim();
  }

  List<Uri> _sortApkUrls(List<Uri> urls) {
    final copied = List<Uri>.from(urls);
    copied.sort((a, b) {
      final rankA = _apkRank(a.path.toLowerCase());
      final rankB = _apkRank(b.path.toLowerCase());
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }
      return a.path.compareTo(b.path);
    });
    return copied;
  }

  int _apkRank(String path) {
    if (path.contains('universal')) {
      return 0;
    }
    if (path.contains('arm64-v8a')) {
      return 1;
    }
    if (path.contains('armeabi-v7a')) {
      return 2;
    }
    if (path.contains('x86_64')) {
      return 3;
    }
    return 4;
  }

  int _compareVersion(String current, String latest) {
    final currentVersion = _parseVersion(current);
    final latestVersion = _parseVersion(latest);
    final majorCmp = currentVersion.major.compareTo(latestVersion.major);
    if (majorCmp != 0) {
      return majorCmp;
    }
    final minorCmp = currentVersion.minor.compareTo(latestVersion.minor);
    if (minorCmp != 0) {
      return minorCmp;
    }
    final patchCmp = currentVersion.patch.compareTo(latestVersion.patch);
    if (patchCmp != 0) {
      return patchCmp;
    }
    return currentVersion.build.compareTo(latestVersion.build);
  }

  _VersionNumber _parseVersion(String raw) {
    final normalized = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final plusParts = normalized.split('+');
    final corePart = plusParts.first.split('-').first;
    final buildPart = plusParts.length > 1 ? plusParts[1] : '0';
    final coreNumbers = corePart
        .split('.')
        .map((segment) => int.tryParse(segment) ?? 0)
        .toList(growable: false);

    int at(int index) {
      if (index < 0 || index >= coreNumbers.length) {
        return 0;
      }
      return coreNumbers[index];
    }

    return _VersionNumber(
      major: at(0),
      minor: at(1),
      patch: at(2),
      build: int.tryParse(buildPart) ?? 0,
    );
  }
}

class _ResolvedRelease {
  const _ResolvedRelease({
    required this.tagName,
    required this.apkUrls,
    this.releaseNotes,
  });

  final String tagName;
  final List<Uri> apkUrls;
  final String? releaseNotes;
}

class _ReleaseAccessChannel {
  const _ReleaseAccessChannel({
    required this.index,
    required this.id,
    required this.proxyPrefix,
    required this.supportsLatestLookup,
  });

  final int index;
  final String id;
  final String? proxyPrefix;
  final bool supportsLatestLookup;

  Uri wrap(Uri source) {
    if (proxyPrefix == null) {
      return source;
    }
    return Uri.parse('$proxyPrefix${source.toString()}');
  }
}

class _VersionNumber {
  const _VersionNumber({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
  });

  final int major;
  final int minor;
  final int patch;
  final int build;
}
