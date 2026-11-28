import 'dart:async';
import 'dart:collection';
import 'dart:convert' show base64Decode;
import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Size;

/// 图片的像素尺寸（已按 EXIF 方向换算），只解析编码头，不解码像素。
///
/// 长图在解码前就要决定怎么显示（正文折叠、看图页竖向滚动、是否分片），
/// 不能等整张解码完再看比例：那样超长图已经吃掉几十 MB 内存，且超过 GPU
/// 纹理上限的一边会被引擎单独压缩而变形。
///
/// - 输入：图片来源字符串，支持本地文件路径与 `data:` URI；网络图返回 null，
///   由调用方按普通图片显示；
/// - 输出：像素尺寸，读取失败（文件不存在、格式不支持）为 null；
/// - 副作用：读取文件开头（必要时整份）交给引擎解析编码头；结果按来源缓存在
///   内存 LRU 中，同一来源的并发请求合并为一次，且限制同时进行的磁盘与
///   头部解析并发数，避免多图正文触发 I/O 与缓冲尖峰。
///
/// 正文图片导入时已复制为不可变的私有文件，来源路径不变即内容不变，因此只按
/// 路径缓存，不比对修改时间。
abstract final class ImageDimensions {
  static const int _capacity = 512;
  static const int _maxConcurrent = 4;

  static final LinkedHashMap<String, Size?> _cache =
      LinkedHashMap<String, Size?>();
  static final Map<String, Future<Size?>> _pending = <String, Future<Size?>>{};
  static final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  static int _running = 0;
  static int _epoch = 0;

  /// 是否已有结果（含“读取失败”的 null 结果）。
  static bool isResolved(String source) => _cache.containsKey(source);

  /// 已缓存的尺寸；未读取或读取失败都返回 null，用 [isResolved] 区分。
  static Size? peek(String source) => _cache[source];

  /// 读取尺寸；已缓存时直接返回。
  static Future<Size?> resolve(String source) {
    if (_cache.containsKey(source)) {
      return Future<Size?>.value(_cache[source]);
    }
    final epoch = _epoch;
    return _pending[source] ??= _read(source).then((size) {
      if (_epoch == epoch) {
        _pending.remove(source);
        _remember(source, size);
      }
      return size;
    });
  }

  /// 测试用：清空缓存。
  static void debugReset() {
    _epoch++;
    _cache.clear();
    _pending.clear();
  }

  static void _remember(String source, Size? size) {
    _cache.remove(source);
    _cache[source] = size;
    while (_cache.length > _capacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  static Future<Size?> _read(String source) {
    final uri = Uri.tryParse(source);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      return Future<Size?>.value();
    }
    // 文件与解码器头探测不依赖调用方 Zone；放在 root Zone 执行，保证即使外层
    // 子 Zone（如测试 FakeAsync）提前结束，并发信号量的 finally 仍会归还许可。
    return Zone.root.run(() => _withPermit(() => _readLocal(source)));
  }

  static Future<Size?> _readLocal(String source) async {
    const marker = 'base64,';
    final index = source.indexOf(marker);
    if (index >= 0) {
      try {
        final bytes = base64Decode(source.substring(index + marker.length));
        return await _describe(await ui.ImmutableBuffer.fromUint8List(bytes));
      } on FormatException {
        return null;
      }
    }
    try {
      // 先只读文件开头：JPEG/PNG/WebP 的尺寸与 EXIF 通常都在前 64–128KB，
      // 不必为了尺寸把整张照片读进内存。头部解析失败（少数 HEIF 把尺寸放
      // 在文件后部）再整份读取。
      final head = await _readHead(source);
      if (head != null) {
        final size = await _describe(
          await ui.ImmutableBuffer.fromUint8List(head),
        );
        if (size != null) {
          return size;
        }
      }
      return await _describe(await ui.ImmutableBuffer.fromFilePath(source));
    } catch (_) {
      // 文件被删、无读权限或格式不受支持：交给图片组件自己的失败占位。
      return null;
    }
  }

  static Future<T> _withPermit<T>(Future<T> Function() action) async {
    if (_running >= _maxConcurrent) {
      final waiter = Completer<void>();
      _waiters.addLast(waiter);
      await waiter.future;
    }
    _running++;
    try {
      return await action();
    } finally {
      _running--;
      if (_waiters.isNotEmpty) {
        _waiters.removeFirst().complete();
      }
    }
  }

  static const int _headBytes = 128 * 1024;

  /// 文件不大于 [_headBytes] 时返回 null，直接整份读取。
  static Future<Uint8List?> _readHead(String path) async {
    final file = await File(path).open();
    try {
      if (await file.length() <= _headBytes) {
        return null;
      }
      return await file.read(_headBytes);
    } finally {
      await file.close();
    }
  }

  static Future<Size?> _describe(ui.ImmutableBuffer buffer) async {
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width <= 0 || descriptor.height <= 0) {
        return null;
      }
      return Size(descriptor.width.toDouble(), descriptor.height.toDouble());
    } catch (_) {
      return null;
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
