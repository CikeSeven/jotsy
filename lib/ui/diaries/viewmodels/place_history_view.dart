import 'package:flutter/foundation.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/utils/pinyin/name_index.dart';

/// 地点文案拆成两段显示：[name] 是最具体的一级（与收起栏摘要 `shortPlace`
/// 同一口径），[region] 是它前面的上级（自动定位的文案形如“杭州 · 西湖区 ·
/// 文三路”）；手填的地点没有分隔符，整段都是名称，[region] 为 null。
@immutable
class PlaceLabelParts {
  const PlaceLabelParts._(this.name, this.region);

  factory PlaceLabelParts.of(String label) {
    final parts = label
        .split('·')
        .map((String part) => part.trim())
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length < 2) {
      return PlaceLabelParts._(
        parts.isEmpty ? label.trim() : parts.single,
        null,
      );
    }
    return PlaceLabelParts._(
      parts.last,
      parts.sublist(0, parts.length - 1).join(' · '),
    );
  }

  final String name;
  final String? region;
}

/// “最近”条带上各地点的文字：一般只写最具体的一级，省地方；同一屏里有两个
/// 地点最具体的一级相同（如两座城市都有“朝阳区”）时，这几个写全称，免得
/// 认错。与 [places] 一一对应。纯函数。
List<String> placeChipLabels(List<DiaryPlaceUsage> places) {
  final names = <String>[
    for (final place in places) PlaceLabelParts.of(place.label).name,
  ];
  final counts = <String, int>{};
  for (final name in names) {
    counts[name] = (counts[name] ?? 0) + 1;
  }
  return <String>[
    for (var i = 0; i < places.length; i++)
      counts[names[i]]! > 1 ? places[i].label : names[i],
  ];
}

/// 按检索词筛选用过的地点，保持原顺序（最近使用在前）。检索词与标签子页
/// 同一套规则（[NameIndexKey]）：名称包含（忽略大小写与全角），或拼音——
/// 全拼从任一字开始，或首字母。空检索词返回原列表。
List<DiaryPlaceUsage> filterPlaces(List<DiaryPlaceUsage> places, String raw) {
  final query = normalizeNameQuery(raw);
  if (query.isEmpty) return places;
  return <DiaryPlaceUsage>[
    for (final place in places)
      if (NameIndexKey.of(place.label).matches(query)) place,
  ];
}
