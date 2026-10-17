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
///   内存 LRU 中，同一来源的并发请求合并为一次。
///
/// 正文图片导入时已复制为不可变的私有文件，来源路径不变即内容不变，因此只按
/// 路径缓存，不比对修改时间。
abstract final class ImageDimensions {
  static const int _capacity = 512;

  static final LinkedHashMap<String, Size?> _cache =
      LinkedHashMap<String, Size?>();
  static final Map<String, Future<Size?>> _pending = <String, Future<Size?>>{};

  /// 是否已有结果（含“读取失败”的 null 结果）。
  static bool isResolved(String source) => _cache.containsKey(source);

  /// 已缓存的尺寸；未读取或读取失败都返回 null，用 [isResolved] 区分。
  static Size? peek(String source) => _cache[source];

  /// 读取尺寸；已缓存时直接返回。
  static Future<Size?> resolve(String source) {
    if (_cache.containsKey(source)) {
      return Future<Size?>.value(_cache[source]);
    }
    return _pending[source] ??= _read(source).then((size) {
      _pending.remove(source);
      _remember(source, size);
      return size;
    });
  }

  /// 测试用：清空缓存。
  static void debugReset() {
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

  static Future<Size?> _read(String source) async {
    final uri = Uri.tryParse(source);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }
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
      // 先只读文件开头：JPEG/PNG/WebP 的尺寸都在头部（JPEG 的 EXIF 缩略图
      // 也在前 64KB 左右），不必为了尺寸把整张照片读进内存。头部解析失败
      // （少数 HEIF 把尺寸放在文件后部）再整份读取。
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

  static const int _headBytes = 512 * 1024;

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
