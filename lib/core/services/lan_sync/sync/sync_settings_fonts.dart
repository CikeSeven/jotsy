import 'dart:convert';

import 'sync_model.dart';

/// settings 记录里的导入字体（规格 §2.2 settings 行）：本机字体 id ↔ 跨设备
/// 引用 `jotsy-font:<sha256>`。
///
/// 为什么要换：导入字体的 id 是导入那一刻在本机生成的
/// （`DiaryFontStorageService.importFont`），两台设备导入同一个字体文件得到
/// 不同的 id，而字体文件本身不同步。直接同步 id 时，对方的 id 写进本机后
/// 找不到这款字体、界面回落到内置的 HarmonyOS Sans；用户在这台重新选一次，
/// 下次同步又把另一台改掉，两台轮流变回内置字体（#288）。
///
/// 涉及的设置（[kSyncFontSettingsKeys]）：日记排版 `diaryTypography`（对象）
/// 的 `fontId`，代码块样式 `diaryCodeBlockStyleRaw`（JSON 原文）的 `fontId`。
///
/// - 取值（[syncFontIdsToRefs]）：本机导入字体的 id 换成按文件内容的引用；
///   不在表里的 id（内置 / 系统 / 等宽字体、本机已经没有文件的字体、对方
///   传来而本机没有这款字体时原样存下的引用）原样保留；
/// - 写入（[syncFontRefsToIds]）：引用换回本机内容相同的那款字体的 id；本机
///   没有这款字体时原样存下引用——界面照旧回落到内置字体，但之后取值仍是
///   同一个引用，与对方一致，不会再被判成差异来回改；
/// - JSON 原文只在真的换了 `fontId` 时按规范 JSON 重新编码（两个方向都如此：
///   取值时编码的串写入另一台后再取值，逐字节相同），其余原文原样返回。
///
/// 纯函数，参数与结果都可以跨 isolate 传递。

/// 引用前缀；与内置字体 id（`bundled` / `system`）、代码块字体 id
/// （`mono` / `body`）以及本机导入字体的 id（`f…`）都不会冲突。
const String kSyncFontRefPrefix = 'jotsy-font:';

/// 带导入字体 id 的设置键。
const Set<String> kSyncFontSettingsKeys = <String>{
  'diaryTypography',
  'diaryCodeBlockStyleRaw',
};

/// 本机导入字体的 id → 文件内容的 SHA-256（小写十六进制），由装配注入
/// （生产为 `DiaryFontStorageService.contentFingerprints`）。
typedef SyncFontFingerprints = Future<Map<String, String>> Function();

/// 本机导入字体的 id → 跨设备引用。
Map<String, String> syncFontRefsOf(Map<String, String> fingerprints) =>
    <String, String>{
      for (final entry in fingerprints.entries)
        entry.key: '$kSyncFontRefPrefix${entry.value}',
    };

/// 反向表：引用 → 本机 id。同一个文件导入了两份时取 id 较小的一份，
/// 两次同步的结果一致。
Map<String, String> syncFontIdsByRef(Map<String, String> refsById) {
  final ids = refsById.keys.toList()..sort();
  final byRef = <String, String>{};
  for (final id in ids) {
    byRef.putIfAbsent(refsById[id]!, () => id);
  }
  return byRef;
}

/// 取值：设置键 [key] 的原值里本机导入字体的 id 换成引用。
Object? syncFontIdsToRefs(
  String key,
  Object? value,
  Map<String, String> refsById,
) => _mapFontId(key, value, refsById);

/// 写入：设置键 [key] 的值里的引用换回本机字体的 id，本机没有的保持引用。
Object? syncFontRefsToIds(
  String key,
  Object? value,
  Map<String, String> idsByRef,
) => _mapFontId(key, value, idsByRef);

Object? _mapFontId(String key, Object? value, Map<String, String> map) {
  if (map.isEmpty || !kSyncFontSettingsKeys.contains(key)) return value;
  if (value is Map) return _mapFontIdField(value, map) ?? value;
  if (value is! String) return value;
  Object? decoded;
  try {
    decoded = jsonDecode(value);
  } on FormatException {
    return value;
  }
  if (decoded is! Map) return value;
  final mapped = _mapFontIdField(decoded, map);
  return mapped == null ? value : syncCanonicalJson(mapped);
}

/// [json] 的 `fontId` 在 [map] 里时返回换过的副本，否则为 null（不动）。
Map<String, Object?>? _mapFontIdField(Map json, Map<String, String> map) {
  final fontId = json['fontId'];
  if (fontId is! String) return null;
  final mapped = map[fontId];
  if (mapped == null || mapped == fontId) return null;
  return <String, Object?>{...json.cast<String, Object?>(), 'fontId': mapped};
}
