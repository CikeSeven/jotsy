// 一次性功能提示的进度（例如首页标签栏“下拉展开”的提示）。
//
// 职责：记下每条提示在这台设备上是否已学会（用户自己用过这个功能）、出现过
// 几次，据此决定还要不要再提示。这里只是数据模型；何时出现、怎样呈现由各
// 功能自己的控制器负责（标签栏见 `TagFilterPullHintController`）。
//
// 存储：单个 JSON 设置键 `app.settings.feature_tips`（经
// `SettingsService.setFeatureTipsRaw`），形如
// `{"tagFilterPull":{"learned":false,"shown":1}}`，逐字段容错解析。本机偏好：
// 记的是用这台设备的人见过、用过没有，不随备份导出、不参与同步。以后新增的
// 功能提示都收进这个键，不另加设置键。

import 'dart:convert';

/// 可提示的功能。
enum FeatureTip {
  /// 首页标签筛选栏可以下拉展开成多行。
  tagFilterPull('tagFilterPull', maxShows: 3),

  /// 首页标签单击只切换一个，长按（桌面 Ctrl / ⌘ + 点击）才同时选多个
  /// （#196）：在单击把已选的标签换掉时提示，用过长按即学会。
  tagFilterMultiSelect('tagFilterMultiSelect', maxShows: 2);

  const FeatureTip(this.storageKey, {required this.maxShows});

  /// 在设置 JSON 里的键名。改名会让已经学会的用户重新看到提示，不要改。
  final String storageKey;

  /// 用户一直没用过时最多出现几次；到了就不再打扰。
  final int maxShows;
}

/// 一条提示的进度。不可变。
class FeatureTipRecord {
  const FeatureTipRecord({this.learned = false, this.shown = 0});

  /// 从没出现过、也没用过。
  static const FeatureTipRecord initial = FeatureTipRecord();

  /// 用户自己用过这个功能（不论有没有看到提示）：之后永不再提示。
  final bool learned;

  /// 已经出现过几次。
  final int shown;

  static const _keyLearned = 'learned';
  static const _keyShown = 'shown';

  /// 类型不对的字段各自回到初始值，不连累另一个字段。
  static FeatureTipRecord _decode(Object? node) {
    if (node is! Map) return initial;
    final learned = node[_keyLearned];
    final shown = node[_keyShown];
    return FeatureTipRecord(
      learned: learned is bool && learned,
      shown: shown is int && shown > 0 ? shown : 0,
    );
  }

  Map<String, Object> _encode() => <String, Object>{
    _keyLearned: learned,
    _keyShown: shown,
  };

  @override
  bool operator ==(Object other) =>
      other is FeatureTipRecord &&
      other.learned == learned &&
      other.shown == shown;

  @override
  int get hashCode => Object.hash(learned, shown);

  @override
  String toString() => 'FeatureTipRecord(learned: $learned, shown: $shown)';
}

/// 全部功能提示的进度。不可变；修改经 [markShown] / [markLearned] 得到新值
/// 后整份保存（[encode]）。
class FeatureTips {
  const FeatureTips._(this._records, this._unknown);

  /// 从没设置过、读不出时的值：每条提示都是 [FeatureTipRecord.initial]。
  static const FeatureTips empty = FeatureTips._(
    <FeatureTip, FeatureTipRecord>{},
    <String, Object?>{},
  );

  final Map<FeatureTip, FeatureTipRecord> _records;

  /// 认不出的条目（较新版本写入的提示）原样保留：换回旧版本再升级时，已经
  /// 学会的提示不会因为旧版本整份写回而被清掉。
  final Map<String, Object?> _unknown;

  FeatureTipRecord recordOf(FeatureTip tip) =>
      _records[tip] ?? FeatureTipRecord.initial;

  /// 还没学会、出现次数也没到上限。
  bool shouldShow(FeatureTip tip) {
    final record = recordOf(tip);
    return !record.learned && record.shown < tip.maxShows;
  }

  /// 又出现了一次。
  FeatureTips markShown(FeatureTip tip) {
    final record = recordOf(tip);
    return _with(
      tip,
      FeatureTipRecord(learned: record.learned, shown: record.shown + 1),
    );
  }

  /// 用户用过了这个功能；已经学会时原样返回，调用方据此省掉一次写入。
  FeatureTips markLearned(FeatureTip tip) {
    final record = recordOf(tip);
    if (record.learned) return this;
    return _with(tip, FeatureTipRecord(learned: true, shown: record.shown));
  }

  /// 把 [tip] 的进度换成 [record]，其余条目不变：各提示的控制器只改自己
  /// 那一条，写回前经它合进设置里最新的整份进度（见
  /// `SettingsService.updateFeatureTips`）。
  FeatureTips withRecord(FeatureTip tip, FeatureTipRecord record) =>
      recordOf(tip) == record ? this : _with(tip, record);

  FeatureTips _with(FeatureTip tip, FeatureTipRecord record) => FeatureTips._(
    <FeatureTip, FeatureTipRecord>{..._records, tip: record},
    _unknown,
  );

  /// 解析设置原文。空值、坏 JSON 或不是对象时为 [empty]；每条提示单独
  /// 读取，一条坏值只让这一条回到初始值。
  static FeatureTips decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return empty;
    final Object? node;
    try {
      node = jsonDecode(raw);
    } on FormatException {
      return empty;
    }
    if (node is! Map) return empty;
    final known = <String, FeatureTip>{
      for (final tip in FeatureTip.values) tip.storageKey: tip,
    };
    final records = <FeatureTip, FeatureTipRecord>{};
    final unknown = <String, Object?>{};
    for (final entry in node.entries) {
      final key = entry.key;
      if (key is! String) continue;
      final tip = known[key];
      if (tip == null) {
        unknown[key] = entry.value;
      } else {
        records[tip] = FeatureTipRecord._decode(entry.value);
      }
    }
    return FeatureTips._(records, unknown);
  }

  /// 编码为设置原文：认不出的条目在前原样写回，已知提示只写有记录的。
  String encode() {
    return jsonEncode(<String, Object?>{
      ..._unknown,
      for (final entry in _records.entries)
        entry.key.storageKey: entry.value._encode(),
    });
  }
}
