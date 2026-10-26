import 'dart:convert';

const String diaryAudioEmbedType = 'audio';

/// Audio embeds store a managed file path, duration, optional display name,
/// and normalized waveform samples, never recognized text.
class DiaryAudioAttachment {
  const DiaryAudioAttachment({
    required this.path,
    required this.duration,
    this.name,
    this.waveform = const <double>[],
  });

  final String path;
  final Duration duration;
  final String? name;
  final List<double> waveform;

  DiaryAudioAttachment copyWith({
    String? path,
    Duration? duration,
    String? name,
    List<double>? waveform,
  }) {
    return DiaryAudioAttachment(
      path: path ?? this.path,
      duration: duration ?? this.duration,
      name: name ?? this.name,
      waveform: waveform ?? this.waveform,
    );
  }

  String encode() => jsonEncode(<String, Object?>{
    'path': path,
    'durationMs': duration.inMilliseconds,
    if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
    if (waveform.isNotEmpty)
      'waveform': waveform
          .map((w) => double.parse(w.toStringAsFixed(2)))
          .toList(),
  });

  /// 解析录音数据：Quill 嵌入里再编码一层的 JSON 字符串，或块文档 `data`
  /// 里的 Map。
  static DiaryAudioAttachment? tryDecode(Object? data) {
    if (data is! String && data is! Map) return null;
    try {
      final value = data is String ? jsonDecode(data) : data;
      if (value is! Map || value['path'] is! String) return null;
      final path = (value['path'] as String).trim();
      if (path.isEmpty) return null;
      final milliseconds = value['durationMs'];
      final nameRaw = value['name'];
      final name = nameRaw is String && nameRaw.trim().isNotEmpty
          ? nameRaw.trim()
          : null;
      final waveformRaw = value['waveform'];
      final waveform = <double>[];
      if (waveformRaw is List) {
        for (final item in waveformRaw) {
          if (item is num && item.isFinite) {
            waveform.add(item.toDouble().clamp(0.0, 1.0));
          }
        }
      }
      return DiaryAudioAttachment(
        path: path,
        duration: Duration(
          milliseconds: milliseconds is num && milliseconds.isFinite
              ? milliseconds.toInt().clamp(0, 86400000)
              : 0,
        ),
        name: name,
        waveform: waveform,
      );
    } on FormatException {
      return null;
    }
  }
}
