import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_update_http.dart';
import 'app_update_models.dart';
import 'app_update_release_parsers.dart';
import 'app_update_sources.dart';

/// 检查结果：最新版本，以及拿到它的线路（下次优先使用）。
class AppUpdateCheckOutcome {
  const AppUpdateCheckOutcome(this.release, this.source);

  final AppUpdateRelease release;

  /// 读到版本信息的线路；经 GitHub 接口直连获得时为直连。
  final AppUpdateSource source;
}

/// 查询最新正式版。
///
/// 面向国内网络，按“一次请求拿全信息、多线路同时发”的思路分两段：
/// 1. 清单：同时经所有线路请求 `releases/latest/download/jotsy-update.json`，
///    取最先成功的一条——版本、分 ABI 的大小与 SHA-256、中英文说明一次到手。
///    任一线路正常返回后立即关闭其余连接。两条以上线路（或直连）都回 404
///    说明该版本没有清单（清单机制之前的旧版本），不再等其余线路超时；
/// 2. 回退：同时请求 GitHub 接口（直连，附件带 digest）与各线路的
///    `releases/latest` 跳转（Location 里带 tag，再经同一线路读取该版本的
///    `SHA256SUMS.txt` 得到安装包与校验值，见 [releaseFromChecksums]）。
/// 没有清单时再按界面语言经各线路读取仓库里的 `docs/releases/<tag>.md`。
///
/// 每个请求单独限时 [requestTimeout]；整个检查最坏约为两段超时之和。
class AppUpdateChecker {
  AppUpdateChecker({
    AppUpdateHttp? http,
    this.requestTimeout = const Duration(seconds: 8),
    Uri? latestManifest,
    Uri? latestReleaseApi,
    Uri? latestReleasePage,
    Uri Function(String tag, {required bool english})? releaseNotesFile,
  }) : _http = http ?? AppUpdateHttp(),
       _latestManifest = latestManifest ?? AppUpdateEndpoints.latestManifest,
       _latestReleaseApi =
           latestReleaseApi ?? AppUpdateEndpoints.latestReleaseApi,
       _latestReleasePage =
           latestReleasePage ?? AppUpdateEndpoints.latestReleasePage,
       _releaseNotesFile =
           releaseNotesFile ?? AppUpdateEndpoints.releaseNotesFile;

  final AppUpdateHttp _http;
  final Duration requestTimeout;
  final Uri _latestManifest;
  final Uri _latestReleaseApi;
  final Uri _latestReleasePage;
  final Uri Function(String tag, {required bool english}) _releaseNotesFile;

  Future<AppUpdateCheckOutcome> fetchLatest({
    required List<AppUpdateSource> sources,
    required String languageCode,
    AppUpdateCancelToken? cancelToken,
  }) async {
    assert(sources.isNotEmpty);
    final manifest = await _race<AppUpdateCheckOutcome>(
      <Future<_Attempt<AppUpdateCheckOutcome>> Function(AppUpdateCancelToken)>[
        for (final source in sources) (token) => _fetchManifest(source, token),
      ],
      definitiveMissThreshold: sources.length < 2 ? 1 : 2,
      cancelToken: cancelToken,
    );
    if (manifest != null) {
      return manifest;
    }
    cancelToken?.throwIfCancelled();

    final fallback = await _race<AppUpdateCheckOutcome>(
      <Future<_Attempt<AppUpdateCheckOutcome>> Function(AppUpdateCancelToken)>[
        _fetchApi,
        for (final source in sources) (token) => _fetchTag(source, token),
      ],
      cancelToken: cancelToken,
    );
    cancelToken?.throwIfCancelled();
    if (fallback == null) {
      throw const AppUpdateException(AppUpdateFailureKind.network);
    }
    final release = await _withLocalizedNotes(
      fallback.release,
      languageCode: languageCode,
      sources: sources,
      cancelToken: cancelToken,
    );
    return AppUpdateCheckOutcome(release, fallback.source);
  }

  Future<_Attempt<AppUpdateCheckOutcome>> _fetchManifest(
    AppUpdateSource source,
    AppUpdateCancelToken token,
  ) async {
    final response = await _http.getText(
      source.wrap(_latestManifest),
      timeout: requestTimeout,
      accept: 'application/json',
      cancelToken: token,
    );
    if (response.statusCode == HttpStatus.notFound) {
      return const _Attempt<AppUpdateCheckOutcome>.miss();
    }
    if (!response.ok) {
      return const _Attempt<AppUpdateCheckOutcome>.failed();
    }
    final release = AppUpdateManifest.parse(_decodeJson(response.body));
    return release == null
        ? const _Attempt<AppUpdateCheckOutcome>.failed()
        : _Attempt<AppUpdateCheckOutcome>.ok(
            AppUpdateCheckOutcome(release, source),
          );
  }

  Future<_Attempt<AppUpdateCheckOutcome>> _fetchApi(
    AppUpdateCancelToken token,
  ) async {
    final response = await _http.getText(
      _latestReleaseApi,
      timeout: requestTimeout,
      accept: 'application/vnd.github+json',
      cancelToken: token,
    );
    final release = response.ok
        ? parseGitHubRelease(_decodeJson(response.body))
        : null;
    return release == null
        ? const _Attempt<AppUpdateCheckOutcome>.failed()
        : _Attempt<AppUpdateCheckOutcome>.ok(
            AppUpdateCheckOutcome(release, AppUpdateSource.direct),
          );
  }

  /// `releases/latest` 不跟随跳转，从 Location 取 tag（镜像会把 Location
  /// 改写成带自身前缀的地址，tag 仍在路径末尾），再读取该版本的校验文件。
  Future<_Attempt<AppUpdateCheckOutcome>> _fetchTag(
    AppUpdateSource source,
    AppUpdateCancelToken token,
  ) async {
    final response = await _http.getText(
      source.wrap(_latestReleasePage),
      timeout: requestTimeout,
      followRedirects: false,
      accept: 'text/html',
      cancelToken: token,
    );
    final tag = extractReleaseTag(response.location ?? '');
    if (tag == null) {
      return const _Attempt<AppUpdateCheckOutcome>.failed();
    }
    final checksums = await _http.getText(
      source.wrap(
        AppUpdateEndpoints.assetUrl(tag, AppUpdateEndpoints.checksumsFileName),
      ),
      timeout: requestTimeout,
      accept: 'text/plain',
      maxBytes: 64 << 10,
      cancelToken: token,
    );
    final release = checksums.ok
        ? releaseFromChecksums(tag, checksums.body)
        : null;
    return release == null
        ? const _Attempt<AppUpdateCheckOutcome>.failed()
        : _Attempt<AppUpdateCheckOutcome>.ok(
            AppUpdateCheckOutcome(release, source),
          );
  }

  /// 没有清单的版本按界面语言读取仓库里的说明文件：英文界面先读英文；
  /// 手里没有 Release 正文（经跳转只拿到 tag）时再读中文文件。
  Future<AppUpdateRelease> _withLocalizedNotes(
    AppUpdateRelease release, {
    required String languageCode,
    required List<AppUpdateSource> sources,
    AppUpdateCancelToken? cancelToken,
  }) async {
    final english = languageCode == 'en';
    for (final (code, isEnglish) in <(String, bool)>[
      if (english) ('en', true),
      if (release.fallbackNotes == null) ('zh', false),
    ]) {
      final notes = await _race<String>(
        <Future<_Attempt<String>> Function(AppUpdateCancelToken)>[
          for (final source in sources)
            (token) => _fetchNotesFile(
              source.wrap(_releaseNotesFile(release.tag, english: isEnglish)),
              token,
            ),
        ],
        cancelToken: cancelToken,
      );
      if (notes != null) {
        return release.copyWith(
          notes: <String, String>{...release.notes, code: notes},
        );
      }
    }
    return release;
  }

  Future<_Attempt<String>> _fetchNotesFile(
    Uri uri,
    AppUpdateCancelToken token,
  ) async {
    final response = await _http.getText(
      uri,
      timeout: requestTimeout,
      accept: 'text/plain',
      maxBytes: 256 << 10,
      cancelToken: token,
    );
    if (response.statusCode == HttpStatus.notFound) {
      return const _Attempt<String>.miss();
    }
    // 镜像异常时可能以 200 返回 HTML 页面，不当作说明显示。
    final body = response.body.trimLeft();
    if (!response.ok || body.startsWith('<')) {
      return const _Attempt<String>.failed();
    }
    final cleaned = cleanReleaseNotes(response.body);
    return cleaned.isEmpty
        ? const _Attempt<String>.failed()
        : _Attempt<String>.ok(cleaned);
  }

  /// 同时发起 [attempts]，返回最先成功的结果；全部失败返回 null。
  ///
  /// 收到 [definitiveMissThreshold] 个“确实不存在”（404）即提前结束，
  /// 不再等其余线路超时；阈值为 null 时 404 与普通失败相同。结束时
  /// 关闭所有仍在进行的连接。外部取消经 [cancelToken] 传入。
  Future<T?> _race<T>(
    List<Future<_Attempt<T>> Function(AppUpdateCancelToken token)> attempts, {
    int? definitiveMissThreshold,
    AppUpdateCancelToken? cancelToken,
  }) async {
    if (attempts.isEmpty) {
      return null;
    }
    cancelToken?.throwIfCancelled();
    final group = AppUpdateCancelToken();
    final completer = Completer<T?>();
    var pending = attempts.length;
    var misses = 0;

    void settle(T? value) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }

    unawaited(cancelToken?.whenCancelled.then((_) => settle(null)));

    for (final attempt in attempts) {
      unawaited(
        attempt(group)
            .then<_Attempt<T>>(
              (result) => result,
              onError: (Object _) => _Attempt<T>.failed(),
            )
            .then((result) {
              pending--;
              if (result.isOk) {
                settle(result.value);
                return;
              }
              if (result.isMiss) {
                misses++;
              }
              final threshold = definitiveMissThreshold;
              if (pending == 0 || (threshold != null && misses >= threshold)) {
                settle(null);
              }
            }),
      );
    }
    try {
      return await completer.future;
    } finally {
      group.cancel();
    }
  }

  static Object? _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}

/// 从 `.../releases/tag/v0.6.1` 形式的地址里取出 tag。
String? extractReleaseTag(String raw) {
  final match = RegExp("/releases/tag/([^\"'\\s?#]+)").firstMatch(raw);
  final token = match?.group(1);
  if (token == null || token.trim().isEmpty) {
    return null;
  }
  try {
    return Uri.decodeComponent(token).trim();
  } on ArgumentError {
    return null;
  }
}

/// 一次尝试的结果：成功、确实不存在（404）或其他失败。
class _Attempt<T> {
  const _Attempt.ok(T this.value) : isOk = true, isMiss = false;
  const _Attempt.miss() : value = null, isOk = false, isMiss = true;
  const _Attempt.failed() : value = null, isOk = false, isMiss = false;

  final T? value;
  final bool isOk;
  final bool isMiss;
}
