import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../app_background_storage_service.dart';
import '../../backup_constants.dart';
import '../../diary_media_references.dart';
import 'sync_model.dart';

/// 规范值里的托管媒体路径归一与还原（规格 §2.3）。
///
/// - 归一（[syncNormalizeMediaRefs]）：本机绝对路径 / `file:` URI →
///   `jotsy-media:<键>`。与 [DiaryMediaReferences] 同一口径：遍历值里的每个
///   字符串，本身是 JSON 对象 / 数组的字符串（附件 metadata 等再编码一层的
///   JSON）解码后递归处理、再按规范 JSON 编码回字符串；**整串**是托管媒体路径
///   （[diaryMediaKeyOf] 非空）才替换，正文文字里顺带提到的路径不动；
/// - 还原（[syncRebindMediaRefs]）：`jotsy-media:<键>` → 本机
///   `<dataRoot>/<键>`（平台分隔符）；原来是 `file:` URI 的同样写成绝对路径。
///
/// 两个方向都只做纯数据变换，不读写文件；文件是否存在由传输层负责。
/// 同一个键在每台设备上都映射到各自的数据根目录，所以 A 的记录写到 B 后，
/// B 再归一出来的值与 A 的逐字节相同。

/// 只有提到托管目录名的字符串才可能是媒体路径（快速路径，与
/// [DiaryMediaReferences] 相同的预筛）。
bool _mentionsManagedDirectory(String value) =>
    backupMediaDirectories.any(value.contains);

/// 返回 [value] 的深拷贝，其中的托管媒体路径都换成 `jotsy-media:<键>`。
Object? syncNormalizeMediaRefs(Object? value) {
  if (value is String) return _normalizeString(value);
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key as String: syncNormalizeMediaRefs(entry.value),
    };
  }
  if (value is List) {
    return <Object?>[for (final item in value) syncNormalizeMediaRefs(item)];
  }
  return value;
}

String _normalizeString(String value) {
  if (!_mentionsManagedDirectory(value)) return value;
  final trimmed = value.trim();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      return syncCanonicalJson(syncNormalizeMediaRefs(jsonDecode(trimmed)));
    } on FormatException {
      // 不是合法 JSON，按普通字符串继续判断。
    }
  }
  final key = syncMediaKeyOfLocalPath(trimmed);
  return key == null ? value : '$kSyncMediaRefPrefix$key';
}

/// 整串是托管媒体路径时返回它的键，否则为 null。
///
/// 只认绝对路径（POSIX `/…`、Windows 盘符 `C:\…` / `C:/…`、UNC `\\…`）与
/// `file:` URI：相对路径与 http(s) 地址里即使出现 `diary_images/` 也不是本机
/// 托管文件。
String? syncMediaKeyOfLocalPath(String value) {
  if (value.startsWith('file:')) {
    try {
      return diaryMediaKeyOf(Uri.decodeComponent(Uri.parse(value).path));
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }
  final isAbsolute =
      value.startsWith('/') ||
      value.startsWith(r'\\') ||
      RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value);
  return isAbsolute ? diaryMediaKeyOf(value) : null;
}

/// 返回 [value] 的深拷贝，其中的 `jotsy-media:<键>` 都换成
/// `<dataRoot>/<键>`。
Object? syncRebindMediaRefs(Object? value, String dataRoot) {
  if (value is String) return _rebindString(value, dataRoot);
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key as String: syncRebindMediaRefs(entry.value, dataRoot),
    };
  }
  if (value is List) {
    return <Object?>[
      for (final item in value) syncRebindMediaRefs(item, dataRoot),
    ];
  }
  return value;
}

String _rebindString(String value, String dataRoot) {
  if (!value.contains(kSyncMediaRefPrefix)) return value;
  if (value.startsWith(kSyncMediaRefPrefix)) {
    final path = syncDiaryMediaPathFor(
      dataRoot,
      value.substring(kSyncMediaRefPrefix.length),
    );
    // 键不合法（对方数据损坏或恶意构造）时原样保留，不拼出逃出数据根的路径。
    return path ?? value;
  }
  if (value.startsWith('{') || value.startsWith('[')) {
    try {
      return syncCanonicalJson(
        syncRebindMediaRefs(jsonDecode(value), dataRoot),
      );
    } on FormatException {
      // 普通文字恰好含有前缀：原样保留。
    }
  }
  return value;
}

/// 日记媒体键（`diary_images/…` 等）在本机的绝对路径；键不合法时为 null。
///
/// 合法 = [diaryMediaKeyOf] 认它就是它自己：以托管目录名开头、后面还有
/// 文件名、不含 `..` 与第二个托管目录名。这同时挡住了目录穿越。
String? syncDiaryMediaPathFor(String dataRoot, String key) {
  if (key.contains('\\') || diaryMediaKeyOf(key) != key) return null;
  return p.joinAll(<String>[dataRoot, ...key.split('/')]);
}

/// 设置背景图的媒体键：`app_backgrounds/<文件名>`。
const String kSyncBackgroundKeyPrefix =
    '${AppBackgroundStorageService.directoryName}/';

/// 任一媒体键（日记媒体或背景图）在本机的绝对路径；键不合法时为 null。
/// 供传输与媒体索引按键定位文件。
String? syncMediaPathFor(String dataRoot, String key) {
  if (key.startsWith(kSyncBackgroundKeyPrefix)) {
    final name = key.substring(kSyncBackgroundKeyPrefix.length);
    if (!AppBackgroundStorageService.isValidName(name)) return null;
    return p.join(dataRoot, AppBackgroundStorageService.directoryName, name);
  }
  return syncDiaryMediaPathFor(dataRoot, key);
}
