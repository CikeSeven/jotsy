import 'package:flutter/painting.dart';

/// 节点文字的排版缓存：同一文字 + 样式 + 最大宽度只排版一次。
///
/// 布局测量与绘制共用同一个 [TextPainter]，画布逐帧绘制时不再排版。按“代”
/// 回收：每次布局开始调 [beginGeneration]，布局中用到的条目记为这一代；
/// 连续 [_keepGenerations] 代没用到的条目释放（转场动画里上一份布局的节点
/// 还在画，所以多留两代）。缓存属于一个画布（或一次缩略图绘制），随之
/// [dispose]。
final class MindMapTextCache {
  static const int _keepGenerations = 3;

  final Map<_TextKey, _TextEntry> _entries = <_TextKey, _TextEntry>{};
  int _generation = 0;
  bool _disposed = false;

  /// 开始新一次布局，并回收太久没用的条目。
  void beginGeneration() {
    _generation++;
    final stale = <_TextKey>[
      for (final entry in _entries.entries)
        if (_generation - entry.value.generation > _keepGenerations) entry.key,
    ];
    for (final key in stale) {
      _entries.remove(key)!.painter.dispose();
    }
  }

  /// 排好版的文字。[text] 为空时调用方应传占位文字。
  TextPainter painterFor(
    String text,
    TextStyle style, {
    required double maxWidth,
    TextAlign align = TextAlign.start,
  }) {
    assert(!_disposed);
    final key = _TextKey(text, style, maxWidth, align);
    final cached = _entries[key];
    if (cached != null) {
      cached.generation = _generation;
      return cached.painter;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: maxWidth);
    _entries[key] = _TextEntry(painter, _generation);
    return painter;
  }

  void dispose() {
    _disposed = true;
    for (final entry in _entries.values) {
      entry.painter.dispose();
    }
    _entries.clear();
  }
}

final class _TextEntry {
  _TextEntry(this.painter, this.generation);

  final TextPainter painter;
  int generation;
}

final class _TextKey {
  const _TextKey(this.text, this.style, this.maxWidth, this.align);

  final String text;
  final TextStyle style;
  final double maxWidth;
  final TextAlign align;

  @override
  bool operator ==(Object other) =>
      other is _TextKey &&
      other.text == text &&
      other.style == style &&
      other.maxWidth == maxWidth &&
      other.align == align;

  @override
  int get hashCode => Object.hash(text, style, maxWidth, align);
}
