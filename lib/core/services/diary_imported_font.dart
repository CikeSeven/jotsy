import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// 用户导入的一款正文字体（`DiaryFontStorageService` 清单 `fonts.json` 的一项）。
@immutable
class DiaryImportedFont {
  const DiaryImportedFont({
    required this.id,
    required this.name,
    required this.fileName,
    this.sha256,
  });

  /// 写入 `DiaryTypography.fontId` 的标识，同时决定引擎里的字族名。
  ///
  /// 导入那一刻在本机生成，两台设备导入同一个文件得到的 id 不同；跨设备
  /// 认同一款字体只能看 [sha256]。
  final String id;

  /// 显示名：导入时按界面语言取自字体 name 表，取不到时用原文件名。
  final String name;

  /// 字体目录下的文件名（`<id>.<ttf|otf|ttc>`）。
  final String fileName;

  /// 字体文件内容的 SHA-256（小写十六进制），局域网同步据此在两台设备之间
  /// 认出同一款字体（`DiaryFontStorageService.contentFingerprints`）。
  ///
  /// 第一次需要时才算并写回清单，之前为 null；文件写入后不再改动（id 唯一，
  /// 同一 id 不会换文件），算过一次即可一直沿用。
  final String? sha256;

  static final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

  DiaryImportedFont withSha256(String value) =>
      DiaryImportedFont(id: id, name: name, fileName: fileName, sha256: value);

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'fileName': fileName,
    'sha256': ?sha256,
  };

  /// 清单条目缺字段或文件名试图越出字体目录时返回 null（整条忽略）。
  /// 指纹格式不对时只丢掉指纹（之后重算），条目照常可用。
  static DiaryImportedFont? tryParse(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = json['id'];
    final name = json['name'];
    final fileName = json['fileName'];
    if (id is! String || name is! String || fileName is! String) {
      return null;
    }
    if (id.isEmpty || fileName != p.basename(fileName)) {
      return null;
    }
    final sha256 = json['sha256'];
    return DiaryImportedFont(
      id: id,
      name: name,
      fileName: fileName,
      sha256: sha256 is String && _sha256Pattern.hasMatch(sha256)
          ? sha256
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryImportedFont &&
      other.id == id &&
      other.name == name &&
      other.fileName == fileName &&
      other.sha256 == sha256;

  @override
  int get hashCode => Object.hash(id, name, fileName, sha256);
}
