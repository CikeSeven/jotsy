import 'dart:convert';
import 'dart:typed_data';

/// name 表中的一条记录。
typedef TestFontName = ({
  int platform,
  int encoding,
  int language,
  int nameId,
  String value,
});

/// 构造只含表目录与 name 表的最小 sfnt 字体，用于测试格式识别与字族名
/// 解析；没有字形数据，不能注册到引擎。
///
/// [collection] 为 true 时外包一层只含一个字面的 TTC 头。
Uint8List buildTestFont({
  int version = 0x00010000,
  List<TestFontName> names = const <TestFontName>[],
  bool collection = false,
  bool includeNameTable = true,
}) {
  final fontOffset = collection ? 16 : 0;
  final tableCount = includeNameTable ? 1 : 0;
  final nameTableOffset = fontOffset + 12 + tableCount * 16;

  final encoded = <List<int>>[
    for (final name in names)
      name.platform == 1 ? latin1.encode(name.value) : _utf16Be(name.value),
  ];
  final nameTable = BytesBuilder();
  final header = ByteData(6)
    ..setUint16(0, 0)
    ..setUint16(2, names.length)
    ..setUint16(4, 6 + names.length * 12);
  nameTable.add(header.buffer.asUint8List());
  var stringOffset = 0;
  for (var index = 0; index < names.length; index += 1) {
    final name = names[index];
    final record = ByteData(12)
      ..setUint16(0, name.platform)
      ..setUint16(2, name.encoding)
      ..setUint16(4, name.language)
      ..setUint16(6, name.nameId)
      ..setUint16(8, encoded[index].length)
      ..setUint16(10, stringOffset);
    nameTable.add(record.buffer.asUint8List());
    stringOffset += encoded[index].length;
  }
  for (final bytes in encoded) {
    nameTable.add(bytes);
  }
  final nameBytes = nameTable.toBytes();

  final output = BytesBuilder();
  if (collection) {
    final ttc = ByteData(16)
      ..setUint32(0, 0x74746366)
      ..setUint32(4, 0x00010000)
      ..setUint32(8, 1)
      ..setUint32(12, fontOffset);
    output.add(ttc.buffer.asUint8List());
  }
  final offsetTable = ByteData(12)
    ..setUint32(0, version)
    ..setUint16(4, tableCount);
  output.add(offsetTable.buffer.asUint8List());
  if (includeNameTable) {
    final record = ByteData(16)
      ..setUint32(0, 0x6E616D65)
      ..setUint32(8, nameTableOffset)
      ..setUint32(12, nameBytes.length);
    output.add(record.buffer.asUint8List());
    output.add(nameBytes);
  }
  return output.toBytes();
}

/// 把一个独立的 sfnt 字体包进只含这一个字面的 TTC。集合里的表偏移相对整个
/// 文件，因此每条表记录的偏移都后移 TTC 头的长度。
Uint8List wrapInCollection(Uint8List font) {
  const headerLength = 16;
  final output = Uint8List(headerLength + font.length)
    ..setAll(headerLength, font);
  final view = ByteData.sublistView(output)
    ..setUint32(0, 0x74746366)
    ..setUint32(4, 0x00010000)
    ..setUint32(8, 1)
    ..setUint32(12, headerLength);
  final tableCount = view.getUint16(headerLength + 4);
  for (var index = 0; index < tableCount; index += 1) {
    final record = headerLength + 12 + index * 16;
    view.setUint32(record + 8, view.getUint32(record + 8) + headerLength);
  }
  return output;
}

List<int> _utf16Be(String value) => <int>[
  for (final unit in value.codeUnits) ...<int>[unit >> 8, unit & 0xFF],
];
