/// 第三方附件的类型与扩展名识别。只检查元数据和文件头，不读写文件；
/// MIME 可区分共享同一种 3GP 容器的录音和视频。
library;

enum JournalMediaKind { image, video, audio, attachment }

/// 按文件头识别常见媒体格式，用于没有扩展名的导出文件（如 Daylio 照片）。
String? sniffJournalMediaBytes(List<int> bytes) {
  bool startsWith(List<int> magic, [int offset = 0]) {
    if (bytes.length < offset + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[offset + i] != magic[i]) return false;
    }
    return true;
  }

  String ascii(int start, int end) =>
      bytes.length < end ? '' : String.fromCharCodes(bytes.sublist(start, end));

  if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'jpg';
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47])) return 'png';
  if (ascii(0, 4) == 'GIF8') return 'gif';
  if (ascii(0, 4) == 'RIFF' && ascii(8, 12) == 'WEBP') return 'webp';
  if (ascii(0, 4) == 'RIFF' && ascii(8, 12) == 'WAVE') return 'wav';
  if (ascii(0, 4) == '%PDF') return 'pdf';
  if (ascii(0, 4) == 'OggS') return 'ogg';
  // 手机录音常见的 AMR（窄带 `#!AMR\n`、宽带 `#!AMR-WB\n`）。
  if (ascii(0, 5) == '#!AMR') return 'amr';
  if (ascii(0, 3) == 'ID3' ||
      (bytes.length > 1 && bytes[0] == 0xFF && bytes[1] & 0xE0 == 0xE0)) {
    return 'mp3';
  }
  if (ascii(4, 8) == 'ftyp') {
    final brand = ascii(8, 12);
    if (const {
      'heic',
      'heix',
      'hevc',
      'heim',
      'heis',
      'mif1',
      'msf1',
    }.contains(brand)) {
      return 'heic';
    }
    if (brand == 'M4A ') return 'm4a';
    if (brand == 'qt  ') return 'mov';
    return 'mp4';
  }
  return null;
}

/// 常见媒体 MIME 对应的扩展名；未知或不是媒体时返回 null。
String? journalMediaExtensionForMime(String? mime) {
  final type = mime?.split(';').first.trim().toLowerCase() ?? '';
  return switch (type) {
    'image/jpeg' || 'image/jpg' => 'jpg',
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    'image/heic' || 'image/heif' => 'heic',
    'video/mp4' => 'mp4',
    'video/quicktime' => 'mov',
    'video/3gpp' => '3gp',
    'video/webm' => 'webm',
    'audio/mp4' ||
    'audio/m4a' ||
    'audio/x-m4a' ||
    'audio/aac' ||
    'audio/3gpp' => 'm4a',
    'audio/mpeg' || 'audio/mp3' => 'mp3',
    'audio/amr' || 'audio/amr-wb' => 'amr',
    'audio/wav' || 'audio/x-wav' || 'audio/wave' => 'wav',
    'audio/ogg' => 'ogg',
    'audio/opus' => 'opus',
    'audio/flac' => 'flac',
    'application/pdf' => 'pdf',
    _ => null,
  };
}

/// 按扩展名（不含点，小写）判断媒体类型，未知扩展名按附件处理。
JournalMediaKind journalMediaKindOf(String? extension) {
  return switch (extension) {
    'jpg' ||
    'jpeg' ||
    'png' ||
    'gif' ||
    'webp' ||
    'heic' ||
    'heif' ||
    'bmp' => JournalMediaKind.image,
    'mp4' ||
    'm4v' ||
    'mov' ||
    '3gp' ||
    'webm' ||
    'mkv' ||
    'avi' => JournalMediaKind.video,
    'm4a' ||
    'aac' ||
    'mp3' ||
    'wav' ||
    'ogg' ||
    'oga' ||
    'opus' ||
    'flac' ||
    'amr' ||
    'caf' => JournalMediaKind.audio,
    _ => JournalMediaKind.attachment,
  };
}
