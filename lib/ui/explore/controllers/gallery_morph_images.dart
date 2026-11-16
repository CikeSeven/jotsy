import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 换档过渡里每张图的画面（按整体下标），一次手势（可连跨几档）共用。
///
/// - 网格正在显示的图直接取它已解码的画面（[liveImageOf]，克隆一个句柄），
///   不再读文件、不再解码，过渡一开始就有画面；
/// - 其余的（只在目标档露出的）按目标档的解码尺寸加载：每帧最多发起
///   [_perFrame] 个，避免手势开始那一帧一次解析几百张；解码完成后通知重画。
///   这些加载同时为换档后的网格预热了缓存；
/// - 网格已有画面的图同样按目标档加载一份（换档后网格直接命中），但过渡
///   里仍用已有的那张，不来回替换；
/// - [dispose] 时移除全部监听、释放全部克隆。没听完的加载由图像缓存自己
///   跑完并存下。
class GalleryMorphImages {
  GalleryMorphImages({
    required this.liveImageOf,
    required this.configuration,
    required this.onChanged,
  });

  static const int _perFrame = 40;

  final ui.Image? Function(String source) liveImageOf;
  final ImageConfiguration configuration;
  final VoidCallback onChanged;

  final Map<int, ui.Image> _images = <int, ui.Image>{};
  final Set<int> _requested = <int>{};
  final List<(int, ImageProvider)> _queue = <(int, ImageProvider)>[];
  final List<(ImageStream, ImageStreamListener)> _listening =
      <(ImageStream, ImageStreamListener)>[];
  bool _scheduled = false;
  bool _disposed = false;

  ui.Image? operator [](int index) => _images[index];

  /// 第 [index] 张（来源 [source]）需要画面：先取网格里的，再按 [provider]
  /// （目标档的解码尺寸）排队加载。同一张只处理一次。
  void request(int index, String source, ImageProvider provider) {
    if (_disposed || !_requested.add(index)) return;
    if (!_images.containsKey(index)) {
      final live = liveImageOf(source);
      if (live != null) _images[index] = live.clone();
    }
    _queue.add((index, provider));
    _schedule();
  }

  void _schedule() {
    if (_scheduled || _queue.isEmpty) return;
    _scheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _scheduled = false;
      _pump();
    });
  }

  void _pump() {
    if (_disposed) return;
    final count = _queue.length < _perFrame ? _queue.length : _perFrame;
    for (final (index, provider) in _queue.take(count).toList()) {
      final stream = provider.resolve(configuration);
      final listener = ImageStreamListener((ImageInfo info, bool _) {
        if (_disposed || _images.containsKey(index)) {
          info.dispose();
          return;
        }
        _images[index] = info.image.clone();
        info.dispose();
        onChanged();
      }, onError: (Object _, StackTrace? _) {});
      _listening.add((stream, listener));
      stream.addListener(listener);
    }
    _queue.removeRange(0, count);
    _schedule();
  }

  void dispose() {
    _disposed = true;
    for (final (stream, listener) in _listening) {
      stream.removeListener(listener);
    }
    _listening.clear();
    _queue.clear();
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
  }
}
