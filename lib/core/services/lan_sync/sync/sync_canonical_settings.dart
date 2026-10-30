import 'dart:convert';

import 'package:meta/meta.dart';

import '../../app_background_storage_service.dart';
import '../../app_features.dart';
import '../../backup_settings.dart';
import '../../settings_service.dart';
import '../../tag_order_codec.dart';
import 'sync_media_refs.dart';
import 'sync_model.dart';

/// 设置 ↔ 规范记录（规格 §2.2 的 settings 与 prefs 行）。
///
/// - 取值（[syncCaptureSettings]，主 isolate）：`BackupSettings.capture` 的键，
///   去掉 `appLockEnabled`（应用锁是本机安全设置）与
///   `rememberedTagFilterIdsRaw`（本地标签 id、本机的筛选记忆）；
/// - prefs 记录（[syncPrefsRecord]，始终同步）：标签顺序 `tagOrderRaw`（本地
///   标签 id 串）换成按名称的列表 `tagOrderNames`（经标签表换算，查不到的 id
///   丢掉）；数据类功能开关（[kSyncDataFeatures]：日记本、纪念日、日记模板、
///   时间胶囊、留言）每项一个分面 `feature.<字段>` → `{"on": bool}`，取
///   `AppFeatures.decode` 之后的值（没存过开关时即默认值）；
/// - settings 记录（[syncSettingsRecord]，只在两端都开启“同步设置”时）：其余
///   每个键一个分面 `{"value": …}`；`appFeaturesRaw` 只留界面类开关
///   （[kSyncUiFeatures]：日历 Tab、探索 Tab、侧滑归档），值为字段 → bool 的
///   对象；`appSurfaceRaw` 里的背景文件名换成媒体引用
///   `jotsy-media:app_backgrounds/<文件名>`；
/// - 反向（[syncSettingsRestoreNode] / [syncPrefsRestoreNode]）：给出
///   `BackupSettings.restore` 能直接使用的部分节点，只含调用方要应用的分面；
///   功能开关与本机当前的开关合并成整份 `appFeaturesRaw`（另一类开关保持
///   本机值），数据类开关只会被打开、从不被关掉（用户的决定：对方关掉某个
///   功能不该连带藏起本机的内容，关闭“日记本”在本机有私密本子时还必须先确认，
///   同步里弹不了确认）。
///
/// 无副作用（[syncCaptureSettings] 只读设置服务）。

/// 不参与同步的设置键。
const Set<String> kSyncExcludedSettingsKeys = <String>{
  'appLockEnabled',
  'rememberedTagFilterIdsRaw',
};

/// 始终同步、只同步“开启”的数据类功能（`AppFeatures` 的字段名）。
const List<String> kSyncDataFeatures = <String>[
  'notebooks',
  'anniversaries',
  'templates',
  'timeCapsules',
  'comments',
];

/// 随“同步设置”同步的界面类功能（`AppFeatures` 的字段名）。
const List<String> kSyncUiFeatures = <String>[
  'calendar',
  'explore',
  'swipeArchive',
];

const String _kTagOrderRawKey = 'tagOrderRaw';
const String _kAppSurfaceRawKey = 'appSurfaceRaw';
const String _kAppFeaturesRawKey = 'appFeaturesRaw';

/// 一次读出的设置原值（纯 JSON 值，可以送进后台 isolate）。
///
/// prefs 记录总是由它生成；settings 记录只在 [includeSettings]（本次两端都
/// 开启“同步设置”）时生成。
@immutable
class SyncSettingsCapture {
  const SyncSettingsCapture(this.values, {required this.includeSettings});

  /// 参与同步的设置键 → 原值（[BackupSettings.capture] 的口径）。
  final Map<String, Object?> values;
  final bool includeSettings;
}

/// 读出参与同步的设置原值。
SyncSettingsCapture syncCaptureSettings(
  SettingsService settings, {
  required bool includeSettings,
}) => SyncSettingsCapture(<String, Object?>{
  for (final entry in BackupSettings.capture(settings).entries)
    if (!kSyncExcludedSettingsKeys.contains(entry.key)) entry.key: entry.value,
}, includeSettings: includeSettings);

/// 由 [syncCaptureSettings] 的原值生成 prefs 记录。[tagNamesById] 为本机标签
/// 本地 id → 名称。
SyncRecord syncPrefsRecord(
  Map<String, Object?> captured,
  Map<int, String> tagNamesById,
) {
  final rawOrder = captured[_kTagOrderRawKey];
  final features = _decodeFeatures(captured[_kAppFeaturesRawKey]);
  return SyncRecord(const SyncKey(SyncEntity.prefs, kSyncPrefsId), {
    SyncPrefsFacet.tagOrder: <String, Object?>{
      'value': <String>[
        for (final id in decodeTagOrder(rawOrder is String ? rawOrder : null))
          ?tagNamesById[id],
      ],
    },
    for (final name in kSyncDataFeatures)
      SyncPrefsFacet.feature(name): SyncPrefsFacet.featureValue(
        features[name]!,
      ),
  });
}

/// 由 [syncCaptureSettings] 的原值生成 settings 记录（不含 prefs 的内容）。
SyncRecord syncSettingsRecord(Map<String, Object?> captured) {
  final facets = <String, Object?>{};
  for (final entry in captured.entries) {
    if (kSyncExcludedSettingsKeys.contains(entry.key)) continue;
    if (entry.key == _kTagOrderRawKey) continue;
    if (entry.key == _kAppFeaturesRawKey) {
      final features = _decodeFeatures(entry.value);
      facets[entry.key] = <String, Object?>{
        'value': <String, Object?>{
          for (final name in kSyncUiFeatures) name: features[name],
        },
      };
      continue;
    }
    var value = syncNormalizeMediaRefs(entry.value);
    if (entry.key == _kAppSurfaceRawKey && value is String) {
      value = _mapAppSurfaceImages(value, _backgroundNameToRef);
    }
    facets[entry.key] = <String, Object?>{'value': value};
  }
  return SyncRecord(
    const SyncKey(SyncEntity.settings, kSyncSettingsId),
    facets,
  );
}

/// 由 settings 记录生成 `BackupSettings.restore` 的部分节点。
///
/// [facets] 为要应用的分面（规划出的“本次有变化的键”）；为 null 时给出全部。
/// [dataRoot] 用于还原设置值里可能出现的日记媒体引用。界面类功能开关与
/// [localAppFeaturesRaw]（本机当前的原文）合并成整份原文，数据类开关保持
/// 本机值；合并后与本机相同时不放进节点。
///
/// 注意 `BackupSettings.restore` 对部分键的空值不做任何事（如
/// `diarySortModeRaw` 为 null 时保留本机值），写入层需要单独处理“清空”这种
/// 变化，见 docs/lan_sync.md §6 第 5 步。
Map<String, Object?> syncSettingsRestoreNode(
  SyncRecord record, {
  Iterable<String>? facets,
  required String dataRoot,
  required String? localAppFeaturesRaw,
}) {
  if (record.key.entity != SyncEntity.settings) {
    throw ArgumentError.value(record.key, 'record', '不是设置记录');
  }
  final wanted = facets?.toSet() ?? record.facets.keys.toSet();
  final node = <String, Object?>{};
  for (final entry in record.facets.entries) {
    if (!wanted.contains(entry.key)) continue;
    final value = _facetField(entry.key, entry.value, 'value');
    if (entry.key == _kAppFeaturesRawKey) {
      if (value is! Map) {
        throw FormatException('设置分面 ${entry.key} 格式不对', value);
      }
      final merged = _mergeFeatures(localAppFeaturesRaw, {
        for (final name in kSyncUiFeatures)
          if (value[name] case final bool on) name: on,
      }, onlyEnable: false);
      if (merged != null) node[entry.key] = merged;
      continue;
    }
    var restored = value;
    if (entry.key == _kAppSurfaceRawKey && restored is String) {
      restored = _mapAppSurfaceImages(restored, _backgroundRefToName);
    }
    node[entry.key] = syncRebindMediaRefs(restored, dataRoot);
  }
  return node;
}

/// 由 prefs 记录生成 `BackupSettings.restore` 的部分节点。
///
/// [tagIdsByName] 为本机（写入标签之后的）标签名称 → 本地 id，
/// `tagOrderNames` 据此换回 `tagOrderRaw`，本机没有的名称丢掉（换出空串时
/// 写入层另行清空，见 docs/lan_sync.md §6 第 5 步）。数据类功能开关只打开
/// 本机关着的（见文件头），与 [localAppFeaturesRaw] 合并成整份原文；没有要
/// 打开的就不放进节点。
Map<String, Object?> syncPrefsRestoreNode(
  SyncRecord record, {
  Iterable<String>? facets,
  required Map<String, int> tagIdsByName,
  required String? localAppFeaturesRaw,
}) {
  if (record.key.entity != SyncEntity.prefs) {
    throw ArgumentError.value(record.key, 'record', '不是 prefs 记录');
  }
  final wanted = facets?.toSet() ?? record.facets.keys.toSet();
  final node = <String, Object?>{};
  final enable = <String, bool>{};
  for (final entry in record.facets.entries) {
    if (!wanted.contains(entry.key)) continue;
    if (entry.key == SyncPrefsFacet.tagOrder) {
      final names = _facetField(entry.key, entry.value, 'value');
      node[_kTagOrderRawKey] = encodeTagOrder(<int>[
        for (final name in names is List ? names : const <Object?>[])
          ?tagIdsByName[name],
      ]);
      continue;
    }
    if (!SyncPrefsFacet.isFeature(entry.key)) continue;
    final name = entry.key.substring(SyncPrefsFacet.featurePrefix.length);
    if (!kSyncDataFeatures.contains(name)) continue;
    if (_facetField(entry.key, entry.value, 'on') == true) enable[name] = true;
  }
  if (enable.isNotEmpty) {
    final merged = _mergeFeatures(
      localAppFeaturesRaw,
      enable,
      onlyEnable: true,
    );
    if (merged != null) node[_kAppFeaturesRawKey] = merged;
  }
  return node;
}

Object? _facetField(String name, Object? facet, String field) {
  if (facet is! Map || !facet.containsKey(field)) {
    throw FormatException('设置分面 $name 格式不对', facet);
  }
  return facet[field];
}

/// 功能开关原文 → 字段名 → 开关（经 `AppFeatures.decode`，没存过即默认值）。
Map<String, bool> _decodeFeatures(Object? raw) {
  final features = AppFeatures.decode(raw is String ? raw : null);
  return <String, bool>{
    'calendar': features.calendar,
    'explore': features.explore,
    'notebooks': features.notebooks,
    'anniversaries': features.anniversaries,
    'templates': features.templates,
    'timeCapsules': features.timeCapsules,
    'swipeArchive': features.swipeArchive,
    'comments': features.comments,
  };
}

/// 把 [changes] 合进本机的开关，返回整份新原文；与本机相同时为 null（不写，
/// 没存过开关的设备保持“没存过”，见 `keepLegacyAnniversariesVisible`）。
/// [onlyEnable] 时只打开、不关闭。
String? _mergeFeatures(
  String? localRaw,
  Map<String, bool> changes, {
  required bool onlyEnable,
}) {
  final local = AppFeatures.decode(localRaw);
  bool next(String name, bool current) {
    final change = changes[name];
    if (change == null) return current;
    return onlyEnable ? (current || change) : change;
  }

  final merged = local.copyWith(
    calendar: next('calendar', local.calendar),
    explore: next('explore', local.explore),
    notebooks: next('notebooks', local.notebooks),
    anniversaries: next('anniversaries', local.anniversaries),
    templates: next('templates', local.templates),
    timeCapsules: next('timeCapsules', local.timeCapsules),
    swipeArchive: next('swipeArchive', local.swipeArchive),
    comments: next('comments', local.comments),
  );
  return merged == local ? null : merged.encode();
}

const String _kBackgroundRefPrefix =
    '$kSyncMediaRefPrefix$kSyncBackgroundKeyPrefix';

String? _backgroundNameToRef(String name) =>
    AppBackgroundStorageService.isValidName(name)
    ? '$_kBackgroundRefPrefix$name'
    : null;

String? _backgroundRefToName(String ref) {
  if (!ref.startsWith(_kBackgroundRefPrefix)) return null;
  final name = ref.substring(_kBackgroundRefPrefix.length);
  return AppBackgroundStorageService.isValidName(name) ? name : null;
}

/// 改写“背景与材质”设置里的背景图字段：`global.image` 与
/// `areas.<区域>.background.image`（与 `AppSurfaceSettings.referencedImages`
/// 同一范围）。[map] 返回 null 的值不动。
///
/// 能解析成 JSON 对象时按规范 JSON 重新编码（两个方向都如此，往返后逐字节
/// 相同）；不是 JSON 的原文原样返回（应用读取时按默认处理）。
String _mapAppSurfaceImages(String raw, String? Function(String) map) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return raw;
  }
  if (decoded is! Map) return raw;
  final json = decoded.cast<String, Object?>();

  Map<String, Object?>? mapBackground(Object? background) {
    if (background is! Map) return null;
    final image = background['image'];
    if (image is! String) return null;
    final mapped = map(image);
    if (mapped == null) return null;
    return <String, Object?>{
      ...background.cast<String, Object?>(),
      'image': mapped,
    };
  }

  final global = mapBackground(json['global']);
  if (global != null) json['global'] = global;
  final areas = json['areas'];
  if (areas is Map) {
    final mappedAreas = <String, Object?>{};
    for (final entry in areas.entries) {
      final area = entry.value;
      final background = area is Map ? mapBackground(area['background']) : null;
      mappedAreas[entry.key as String] = background == null
          ? area
          : <String, Object?>{
              ...(area as Map).cast<String, Object?>(),
              'background': background,
            };
    }
    json['areas'] = mappedAreas;
  }
  return syncCanonicalJson(json);
}
