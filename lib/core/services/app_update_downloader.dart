import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_update_download_progress.dart';
import 'app_update_http.dart';
import 'app_update_models.dart';
import 'app_update_sources.dart';

export 'app_update_download_progress.dart' show AppUpdateDownloadProgress;

/// 下载并校验安装包，暂存在缓存目录 `app_update/`（`AppUpdateFileProvider`
/// 只对系统安装器暴露这个目录）。
///
/// 流程与国内网络的取舍：
/// 1. 测速：所有线路同时取前 [probeBytes] 字节，按实测速度排序并去掉不通的
///    线路——镜像时好时坏，挑当下最快的比固定顺序可靠得多；
/// 2. 下载：按排序依次尝试，写入 `.part`；换线路时用 Range 从已下载处续传，
///    服务器不支持 Range（返回 200）才从头写；
/// 3. 失速切换：[stallTimeout] 内收不到数据，或连续 [lowSpeedWindow] 平均
///    速度低于 [lowSpeedBytesPerSecond]（且还有其他线路）时，放弃当前线路
///    续传到下一条。直连 GitHub 在国内常是“开头快、随后被限到几 KB/s”；
/// 4. 校验：大小与 SHA-256（清单或接口给出时）不符即删除并报错，避免把
///    截断或被篡改的文件交给系统安装器；通过后改名为 `.apk`。
/// 取消时保留 `.part`，下次继续。所有线路连续失败且没有任何进展时放弃。
class AppUpdateDownloader {
  AppUpdateDownloader({
    AppUpdateHttp? http,
    Future<Directory> Function()? cacheDirectory,
    this.connectTimeout = const Duration(seconds: 10),
    this.probeTimeout = const Duration(seconds: 6),
    this.probeBytes = 192 << 10,
    this.stallTimeout = const Duration(seconds: 20),
    this.lowSpeedWindow = const Duration(seconds: 15),
    this.lowSpeedBytesPerSecond = 24 << 10,
    this.progressInterval = const Duration(milliseconds: 250),
  }) : _http = http ?? AppUpdateHttp(),
       _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;

  static const String directoryName = 'app_update';

  final AppUpdateHttp _http;
  final Future<Directory> Function() _cacheDirectory;
  final Duration connectTimeout;
  final Duration probeTimeout;
  final int probeBytes;
  final Duration stallTimeout;
  final Duration lowSpeedWindow;
  final int lowSpeedBytesPerSecond;
  final Duration progressInterval;

  Future<Directory> updateDirectory() async {
    final root = await _cacheDirectory();
    return Directory(p.join(root.path, directoryName));
  }

  /// 本地文件名：`<版本>-<ABI>.apk`，清理时据此判断版本。
  static String fileNameFor(AppUpdateRelease release, AppUpdateAsset asset) =>
      '${release.version}-${asset.abi ?? 'universal'}.apk';

  static final RegExp _fileNamePattern = RegExp(
    r'^(.+?)-(arm64-v8a|armeabi-v7a|x86_64|x86|universal)\.apk(?:\.part)?$',
  );

  /// 已下载且校验通过的安装包；没有则返回 null。
  Future<File?> findDownloaded(
    AppUpdateRelease release,
    AppUpdateAsset asset,
  ) async {
    final dir = await updateDirectory();
    final file = File(p.join(dir.path, fileNameFor(release, asset)));
    if (!await file.exists()) {
      return null;
    }
    try {
      await _verify(file, asset);
      return file;
    } on AppUpdateException {
      await _deleteQuietly(file);
      return null;
    }
  }

  /// 删除已安装（不新于 [installed]）版本的安装包与残留，以及不是 [keep]
  /// 的旧版本残留；目录空了一并删除。
  Future<void> cleanUp({
    required AppVersion installed,
    AppUpdateRelease? keep,
  }) async {
    final dir = await updateDirectory();
    if (!await dir.exists()) {
      return;
    }
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) {
          continue;
        }
        final match = _fileNamePattern.firstMatch(p.basename(entity.path));
        final version = AppVersion.tryParse(match?.group(1));
        final stale =
            version == null ||
            !version.isNewerThan(installed) ||
            (keep != null && version != keep.version);
        if (stale) {
          await _deleteQuietly(entity);
        }
      }
      if (await dir.list().isEmpty) {
        await dir.delete();
      }
    } on FileSystemException {
      // 清理只是回收空间，失败不影响更新流程。
    }
  }

  Future<File> download({
    required AppUpdateRelease release,
    required AppUpdateAsset asset,
    required List<AppUpdateSource> sources,
    required void Function(AppUpdateDownloadProgress progress) onProgress,
    bool probe = true,
    AppUpdateCancelToken? cancelToken,
    void Function(AppUpdateSource source)? onSourceSucceeded,
  }) async {
    assert(sources.isNotEmpty);
    final token = cancelToken ?? AppUpdateCancelToken();
    final existing = await findDownloaded(release, asset);
    if (existing != null) {
      return existing;
    }
    final dir = await updateDirectory();
    final target = File(p.join(dir.path, fileNameFor(release, asset)));
    final part = File('${target.path}.part');
    try {
      await dir.create(recursive: true);
    } on FileSystemException catch (error) {
      throw AppUpdateException(AppUpdateFailureKind.storage, error.message);
    }

    final ordered = probe && sources.length > 1
        ? await _probe(asset.url, sources, token)
        : sources;
    token.throwIfCancelled();
    // 只有还有别的可用线路时才因慢速切换，否则只会在死线路上空转。
    final canSwitch = ordered.length > 1;

    var total = asset.size;
    var received = await part.exists() ? await part.length() : 0;
    if (total != null && received > total) {
      await _deleteQuietly(part);
      received = 0;
    }

    var attempt = 0;
    var failuresWithoutProgress = 0;
    while (total == null || received < total) {
      token.throwIfCancelled();
      final source = ordered[attempt % ordered.length];
      attempt++;
      final before = received;
      final result = await _downloadFrom(
        source: source,
        url: asset.url,
        part: part,
        offset: received,
        knownTotal: total,
        canSwitch: canSwitch,
        token: token,
        onProgress: onProgress,
      );
      token.throwIfCancelled();
      received = result.received;
      total = result.total ?? total;
      if (result.complete) {
        onSourceSucceeded?.call(source);
        break;
      }
      if (received > before) {
        failuresWithoutProgress = 0;
      } else if (++failuresWithoutProgress >= ordered.length) {
        throw const AppUpdateException(AppUpdateFailureKind.network);
      }
    }

    await _verify(part, asset, deleteOnMismatch: true);
    try {
      if (await target.exists()) {
        await target.delete();
      }
      return await part.rename(target.path);
    } on FileSystemException catch (error) {
      throw AppUpdateException(AppUpdateFailureKind.storage, error.message);
    }
  }

  /// 同时测速，只返回测速成功的线路（从快到慢）；全部失败时原样返回，
  /// 可能只是测速请求被拦，仍逐条尝试。
  Future<List<AppUpdateSource>> _probe(
    Uri url,
    List<AppUpdateSource> sources,
    AppUpdateCancelToken token,
  ) async {
    final speeds = await Future.wait<double?>(<Future<double?>>[
      for (final source in sources) _probeOne(source.wrap(url), token),
    ]);
    final indexed = <(AppUpdateSource, double?)>[
      for (var i = 0; i < sources.length; i++) (sources[i], speeds[i]),
    ];
    final reachable =
        indexed.where((entry) => entry.$2 != null).toList(growable: false)
          ..sort((a, b) => b.$2!.compareTo(a.$2!));
    return reachable.isEmpty
        ? sources
        : <AppUpdateSource>[for (final entry in reachable) entry.$1];
  }

  Future<double?> _probeOne(Uri url, AppUpdateCancelToken token) async {
    final stopwatch = Stopwatch()..start();
    AppUpdateStream? stream;
    try {
      return await () async {
        stream = await _http.openStream(
          url,
          connectTimeout: probeTimeout,
          rangeStart: 0,
          rangeEnd: probeBytes - 1,
          cancelToken: token,
        );
        final opened = stream!;
        if ((opened.statusCode != HttpStatus.ok &&
                opened.statusCode != HttpStatus.partialContent) ||
            opened.looksLikeHtml) {
          return null;
        }
        var bytes = 0;
        await for (final chunk in opened.response) {
          bytes += chunk.length;
          if (bytes >= probeBytes) {
            break;
          }
        }
        if (bytes == 0) {
          return null;
        }
        final seconds = stopwatch.elapsedMicroseconds / 1e6;
        return bytes / (seconds <= 0 ? 1e-3 : seconds);
      }().timeout(probeTimeout);
    } catch (_) {
      return null;
    } finally {
      stream?.close();
    }
  }

  Future<_SegmentResult> _downloadFrom({
    required AppUpdateSource source,
    required Uri url,
    required File part,
    required int offset,
    required int? knownTotal,
    required bool canSwitch,
    required AppUpdateCancelToken token,
    required void Function(AppUpdateDownloadProgress progress) onProgress,
  }) async {
    var received = offset;
    var total = knownTotal;
    AppUpdateStream? stream;
    RandomAccessFile? file;
    Timer? watchdog;
    try {
      stream = await _http.openStream(
        source.wrap(url),
        connectTimeout: connectTimeout,
        rangeStart: offset > 0 ? offset : null,
        cancelToken: token,
      );
      final opened = stream;
      final status = opened.statusCode;
      if ((status != HttpStatus.ok && status != HttpStatus.partialContent) ||
          opened.looksLikeHtml) {
        return _SegmentResult(received, total, complete: false);
      }
      var mode = FileMode.append;
      if (status == HttpStatus.ok) {
        // 不支持 Range：只能从头写。
        received = 0;
        mode = FileMode.write;
        total = opened.contentLength ?? total;
      } else {
        total =
            opened.rangeTotal ??
            (opened.contentLength == null
                ? total
                : offset + opened.contentLength!);
      }
      file = await part.open(mode: mode);

      final meter = AppUpdateSpeedMeter();
      var lastEmit = DateTime.now();
      var windowStart = DateTime.now();
      var windowBytes = 0;
      var abandoned = false;
      watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
        final now = DateTime.now();
        final idle = now.difference(meter.lastChunkAt);
        final window = now.difference(windowStart);
        final slow =
            canSwitch &&
            window >= lowSpeedWindow &&
            windowBytes / window.inMilliseconds * 1000 < lowSpeedBytesPerSecond;
        if (idle >= stallTimeout || slow) {
          abandoned = true;
          opened.close();
        }
        if (window >= lowSpeedWindow) {
          windowStart = now;
          windowBytes = 0;
        }
      });

      try {
        await for (final chunk in opened.response) {
          // 逐块等待写入：磁盘写满立即以 FileSystemException 暴露，
          // 也给网络读取施加背压。
          await file.writeFrom(chunk);
          received += chunk.length;
          windowBytes += chunk.length;
          meter.add(chunk.length);
          final now = DateTime.now();
          if (now.difference(lastEmit) >= progressInterval) {
            lastEmit = now;
            onProgress(
              AppUpdateDownloadProgress(
                received: received,
                total: total,
                bytesPerSecond: meter.bytesPerSecond,
                source: source,
              ),
            );
          }
        }
      } on IOException {
        // 断流、超时或被看门狗/取消关闭：保留已写入的部分，交给调用方续传。
        return _SegmentResult(received, total, complete: false);
      }
      if (abandoned) {
        return _SegmentResult(received, total, complete: false);
      }
      onProgress(
        AppUpdateDownloadProgress(
          received: received,
          total: total,
          bytesPerSecond: meter.bytesPerSecond,
          source: source,
        ),
      );
      // 未知总长时以正常结束为准；已知总长时必须收满，否则视为被截断。
      final complete = total == null ? received > 0 : received >= total;
      return _SegmentResult(received, total, complete: complete);
    } on FileSystemException catch (error) {
      throw AppUpdateException(AppUpdateFailureKind.storage, error.message);
    } on IOException {
      return _SegmentResult(received, total, complete: false);
    } on TimeoutException {
      return _SegmentResult(received, total, complete: false);
    } finally {
      watchdog?.cancel();
      stream?.close();
      try {
        await file?.close();
      } on FileSystemException {
        // 内容已逐块写入；关闭失败时由随后的大小与 SHA-256 校验兜底。
      }
    }
  }

  /// 校验大小与 SHA-256（已知时）。流式计算，不把 50 MB 的安装包读进内存。
  Future<void> _verify(
    File file,
    AppUpdateAsset asset, {
    bool deleteOnMismatch = false,
  }) async {
    final length = await file.length();
    final size = asset.size;
    final expected = asset.sha256;
    var mismatch = length == 0 || (size != null && length != size);
    if (!mismatch && expected != null) {
      final digest = await sha256.bind(file.openRead()).first;
      mismatch = digest.toString() != expected;
    }
    if (mismatch) {
      if (deleteOnMismatch) {
        await _deleteQuietly(file);
      }
      throw const AppUpdateException(AppUpdateFailureKind.integrity);
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // 删除失败只会多占一点缓存，下次清理时再试。
    }
  }
}

class _SegmentResult {
  const _SegmentResult(this.received, this.total, {required this.complete});

  final int received;
  final int? total;
  final bool complete;
}
