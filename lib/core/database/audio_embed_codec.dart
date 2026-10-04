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

  static DiaryAudioAttachment? tryDecode(Object? data) {
    if (data is! String) return null;
    try {
      final value = jsonDecode(data);
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

Set<String> extractDiaryAudioPaths(String content) {
  try {
    final delta = jsonDecode(content);
    if (delta is! List) return <String>{};
    return <String>{
      for (final op in delta)
        if (op is Map && op['insert'] is Map)
          if (DiaryAudioAttachment.tryDecode(
                (op['insert'] as Map)[diaryAudioEmbedType],
              )
              case final audio?)
            audio.path,
    };
  } on FormatException {
    return <String>{};
  }
}
