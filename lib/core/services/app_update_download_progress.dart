import 'app_update_sources.dart';

/// 下载进度。
class AppUpdateDownloadProgress {
  const AppUpdateDownloadProgress({
    required this.received,
    required this.total,
    required this.bytesPerSecond,
    required this.source,
  });

  final int received;

  /// 总字节数；服务器与清单都没给出时为 null（界面显示不定进度）。
  final int? total;

  /// 平滑后的下载速度。
  final double bytesPerSecond;

  /// 当前使用的线路。
  final AppUpdateSource source;

  double? get fraction {
    final total = this.total;
    if (total == null || total <= 0) {
      return null;
    }
    return (received / total).clamp(0.0, 1.0);
  }
}

/// 速度估计：按秒滑动，指数平滑，避免数字每次刷新都大幅跳动。
class AppUpdateSpeedMeter {
  final DateTime _start = DateTime.now();
  DateTime lastChunkAt = DateTime.now();
  DateTime _bucketStart = DateTime.now();
  int _bucketBytes = 0;
  int _total = 0;
  double? _smoothed;

  void add(int bytes) {
    final now = DateTime.now();
    lastChunkAt = now;
    _total += bytes;
    _bucketBytes += bytes;
    final elapsed = now.difference(_bucketStart).inMilliseconds;
    if (elapsed >= 1000) {
      final instant = _bucketBytes * 1000 / elapsed;
      final previous = _smoothed;
      _smoothed = previous == null ? instant : previous * 0.6 + instant * 0.4;
      _bucketStart = now;
      _bucketBytes = 0;
    }
  }

  double get bytesPerSecond {
    final smoothed = _smoothed;
    if (smoothed != null) {
      return smoothed;
    }
    final elapsed = DateTime.now().difference(_start).inMilliseconds;
    return elapsed <= 0 ? 0 : _total * 1000 / elapsed;
  }
}
