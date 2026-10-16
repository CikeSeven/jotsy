import 'dart:convert';
import 'dart:typed_data';

/// 可导入的字体容器格式（均为 sfnt 结构，Flutter 引擎可直接注册）。
enum FontFileFormat { trueType, openType, collection }

/// 字体文件的最小只读解析结果：格式与 name 表里的字族名。
///
/// 只读取文件头、表目录与 name 表，不校验字形数据；字形损坏的文件会在注册
/// 时由引擎拒绝，界面层据此回落到内置字体。WOFF / WOFF2 等压缩格式不是 sfnt，
/// [readFontFileInfo] 直接返回 null。
class FontFileInfo {
  const FontFileInfo({required this.format, required this.familyNames});

  final FontFileFormat format;

  /// 语言（`zh` / `en` / `und`）→ 字族名，优先排版字族名（nameID 16）。
  final Map<String, String> familyNames;

  String get fileExtension => switch (format) {
    FontFileFormat.trueType => 'ttf',
    FontFileFormat.openType => 'otf',
    FontFileFormat.collection => 'ttc',
  };

  /// 按界面语言取字族名：中文界面优先中文名（“霞鹜文楷”而不是
  /// “LXGW WenKai”），其余语言优先英文名，都没有时取任意一个。
  String? familyNameFor(String languageCode) {
    final order = languageCode == 'zh'
        ? const <String>['zh', 'en', 'und']
        : const <String>['en', 'und', 'zh'];
    for (final language in order) {
      final name = familyNames[language];
      if (name != null) {
        return name;
      }
    }
    return familyNames.values.firstOrNull;
  }
}

const int _tagTtcf = 0x74746366; // 'ttcf'
const int _tagOtto = 0x4F54544F; // 'OTTO'
const int _tagTrue = 0x74727565; // 'true'（旧版 Mac TrueType）
const int _tagName = 0x6E616D65; // 'name'
const int _versionTrueType = 0x00010000;

const int _nameIdFamily = 1;
const int _nameIdTypographicFamily = 16;

/// 解析字体文件；不是受支持的 sfnt 字体或结构越界时返回 null。
///
/// TTC 字体集合只读第一个字面：引擎注册集合时同样只取第一个字面。
FontFileInfo? readFontFileInfo(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  try {
    var fontOffset = 0;
    var format = FontFileFormat.trueType;
    if (data.getUint32(0) == _tagTtcf) {
      final fontCount = data.getUint32(8);
      if (fontCount == 0) {
        return null;
      }
      fontOffset = data.getUint32(12);
      format = FontFileFormat.collection;
    }
    final version = data.getUint32(fontOffset);
    if (version == _tagOtto) {
      if (format != FontFileFormat.collection) {
        format = FontFileFormat.openType;
      }
    } else if (version != _versionTrueType && version != _tagTrue) {
      return null;
    }
    final tableCount = data.getUint16(fontOffset + 4);
    for (var index = 0; index < tableCount; index += 1) {
      final record = fontOffset + 12 + index * 16;
      if (data.getUint32(record) != _tagName) {
        continue;
      }
      // 表偏移相对文件开头（TTC 中也是），不是相对当前字面。
      final tableOffset = data.getUint32(record + 8);
      return FontFileInfo(
        format: format,
        familyNames: _readFamilyNames(data, tableOffset),
      );
    }
    // 没有 name 表的字体仍可注册，显示名交由调用方用文件名兜底。
    return FontFileInfo(format: format, familyNames: const <String, String>{});
  } on RangeError {
    return null;
  }
}

Map<String, String> _readFamilyNames(ByteData data, int tableOffset) {
  final recordCount = data.getUint16(tableOffset + 2);
  final storageOffset = tableOffset + data.getUint16(tableOffset + 4);
  // 同一语言可能有多条候选：按（字族名类型, 地区精确度）取最优一条。
  final best = <String, (int, String)>{};
  for (var index = 0; index < recordCount; index += 1) {
    final record = tableOffset + 6 + index * 12;
    final platformId = data.getUint16(record);
    final encodingId = data.getUint16(record + 2);
    final languageId = data.getUint16(record + 4);
    final nameId = data.getUint16(record + 6);
    if (nameId != _nameIdFamily && nameId != _nameIdTypographicFamily) {
      continue;
    }
    final language = _languageOf(platformId, encodingId, languageId);
    if (language == null) {
      continue;
    }
    final length = data.getUint16(record + 8);
    final start = storageOffset + data.getUint16(record + 10);
    final raw = Uint8List.sublistView(data, start, start + length);
    final name = (platformId == 1 ? latin1.decode(raw) : _decodeUtf16Be(raw))
        .trim();
    if (name.isEmpty) {
      continue;
    }
    final rank =
        (nameId == _nameIdTypographicFamily ? 0 : 10) +
        _regionRank(platformId, languageId);
    final current = best[language];
    if (current == null || rank < current.$1) {
      best[language] = (rank, name);
    }
  }
  return <String, String>{
    for (final entry in best.entries) entry.key: entry.value.$2,
  };
}

/// Windows 平台（3）按语言 ID 的主语言区分中 / 英文；Unicode 平台（0）不带
/// 语言；Mac 平台（1）只取罗马字编码（0）的英文名，其他 Mac 编码不解码。
String? _languageOf(int platformId, int encodingId, int languageId) {
  switch (platformId) {
    case 0:
      return 'und';
    case 1:
      return encodingId == 0 && languageId == 0 ? 'en' : null;
    case 3:
      if (encodingId != 0 && encodingId != 1 && encodingId != 10) {
        return null;
      }
      return switch (languageId & 0x3FF) {
        0x04 => 'zh',
        0x09 => 'en',
        _ => 'und',
      };
    default:
      return null;
  }
}

/// 简体中文（0x0804）、美式英文（0x0409）优先于同语言的其他地区。
int _regionRank(int platformId, int languageId) {
  if (platformId != 3) {
    return 2;
  }
  return languageId == 0x0804 || languageId == 0x0409 ? 0 : 1;
}

String _decodeUtf16Be(Uint8List raw) {
  final units = <int>[
    for (var index = 0; index + 1 < raw.length; index += 2)
      (raw[index] << 8) | raw[index + 1],
  ];
  return String.fromCharCodes(units);
}
