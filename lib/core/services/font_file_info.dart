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

/// 一个可单独使用的 TrueType 字面必须带的表（glyf / loca 即 TrueType 轮廓，
/// CFF 字体没有）。
const List<int> _trueTypeTables = <int>[
  0x636D6170, // 'cmap'
  0x676C7966, // 'glyf'
  0x68656164, // 'head'
  0x68686561, // 'hhea'
  0x686D7478, // 'hmtx'
  0x6C6F6361, // 'loca'
  0x6D617870, // 'maxp'
  _tagName,
  0x706F7374, // 'post'
];

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

/// 取出可单独使用的 TrueType 字面，交给只认单个 TTF 文件的排版库（PDF 导出
/// 嵌入导入字体）。
///
/// - 普通 TTF 原样返回，不复制（导入的中文字体常有十几 MB）；
/// - TTC 取第一个字面（与引擎注册集合时相同），按它的表目录另拼一份独立的
///   sfnt：集合里的表偏移相对整个文件，单独拿出来必须重排；旧版 Mac 的
///   `true` 版本号也走这条路，改写为 0x00010000；
/// - CFF 轮廓（`OTTO`，多数 .otf）没有 glyf / loca 表，缺少其他必需的表或
///   表越界时同样返回 null，由调用方回落到内置字体。
Uint8List? extractTrueTypeFace(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  try {
    var fontOffset = 0;
    if (data.getUint32(0) == _tagTtcf) {
      if (data.getUint32(8) == 0) {
        return null;
      }
      fontOffset = data.getUint32(12);
    }
    final version = data.getUint32(fontOffset);
    if (version != _versionTrueType && version != _tagTrue) {
      return null;
    }
    final tableCount = data.getUint16(fontOffset + 4);
    final tables = <({int tag, int checksum, int offset, int length})>[];
    for (var index = 0; index < tableCount; index += 1) {
      final record = fontOffset + 12 + index * 16;
      final table = (
        tag: data.getUint32(record),
        checksum: data.getUint32(record + 4),
        offset: data.getUint32(record + 8),
        length: data.getUint32(record + 12),
      );
      if (table.offset + table.length > bytes.length) {
        return null;
      }
      tables.add(table);
    }
    final tags = tables.map((table) => table.tag).toSet();
    if (!_trueTypeTables.every(tags.contains)) {
      return null;
    }
    if (fontOffset == 0 && version == _versionTrueType) {
      return bytes;
    }

    int align(int length) => (length + 3) & ~3;
    final headerLength = 12 + tableCount * 16;
    final face = Uint8List(
      tables.fold<int>(headerLength, (sum, table) => sum + align(table.length)),
    );
    // searchRange / entrySelector / rangeShift 只由表数决定，原样沿用。
    final out = ByteData.sublistView(face)
      ..setUint32(0, _versionTrueType)
      ..setUint16(4, tableCount)
      ..setUint16(6, data.getUint16(fontOffset + 6))
      ..setUint16(8, data.getUint16(fontOffset + 8))
      ..setUint16(10, data.getUint16(fontOffset + 10));
    var offset = headerLength;
    for (var index = 0; index < tables.length; index += 1) {
      final table = tables[index];
      final record = 12 + index * 16;
      out
        ..setUint32(record, table.tag)
        ..setUint32(record + 4, table.checksum)
        ..setUint32(record + 8, offset)
        ..setUint32(record + 12, table.length);
      face.setRange(offset, offset + table.length, bytes, table.offset);
      offset += align(table.length);
    }
    return face;
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
