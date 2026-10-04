import 'dart:convert';

const String diaryAudioEmbedType = 'audio';

/// Audio embeds store a managed file path and duration, never recognized text.
class DiaryAudioAttachment {
  const DiaryAudioAttachment({required this.path, required this.duration});

  final String path;
  final Duration duration;

  String encode() => jsonEncode(<String, Object>{
    'path': path,
    'durationMs': duration.inMilliseconds,
  });

  static DiaryAudioAttachment? tryDecode(Object? data) {
    if (data is! String) return null;
    try {
      final value = jsonDecode(data);
      if (value is! Map || value['path'] is! String) return null;
      final path = (value['path'] as String).trim();
      if (path.isEmpty) return null;
      final milliseconds = value['durationMs'];
      return DiaryAudioAttachment(
        path: path,
        duration: Duration(
          milliseconds: milliseconds is num && milliseconds.isFinite
              ? milliseconds.toInt().clamp(0, 86400000)
              : 0,
        ),
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
