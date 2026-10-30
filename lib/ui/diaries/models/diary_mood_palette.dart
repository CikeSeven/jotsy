/// 日记心情的颜色：内置 10 档色板与用户在“心情符号”页改过的颜色。
///
/// - 预览页“配色基调 = 心情”（整页主题的种子色）、日记卡片颜色来源“心情”
///   与卡片的心情块只经 [DiaryMoodPalette] 取色；日历年视图与探索页心情图表
///   的分段色仍只经 `MoodBandPalette`；
/// - 颜色按心情槽位（1–10，由低落到高兴）对应，与心情符号的槽位一致：用户
///   改了某一格的符号，颜色跟着这一格走；默认符号作为别名始终认得
///   （`SettingsService.buildMoodWeightMap`），换过符号之前写的日记照样着色；
/// - 用户改过的颜色存于单个 JSON 设置键 `app.settings.mood_colors`
///   （[DiaryMoodColors]），格式 `{"1":"#5B4B9A","10":"#D94E7A"}`：只写与
///   默认不同的槽位，逐项容错（不是 1–10 的键、读不懂的颜色跳过，该槽位回到
///   默认），全部为默认时删除键。与心情符号同为本机偏好，不随备份导出。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/services/settings_service.dart';
import 'style_library/style_json.dart';

/// 内置心情色，槽位 1→10 由冷到暖：靛紫、蓝、钢蓝、青、鼠尾草绿、黄绿、
/// 金黄、橙、珊瑚、玫红。
///
/// 相邻两档的色相（HCT）至少相隔约 20°：预览页的整页主题由 tonalSpot 生成，
/// 它只取种子色的色相，色相分得开，十种心情的整页主题才分得开。
const List<int> kDiaryMoodDefaultColors = <int>[
  0xFF5B4B9A,
  0xFF3B6CB7,
  0xFF3E8AA8,
  0xFF2E9488,
  0xFF6E9B5A,
  0xFF9AA83A,
  0xFFD9A520,
  0xFFEA8A2A,
  0xFFE8654A,
  0xFFD94E7A,
];

/// 十个心情槽位的颜色（不透明 ARGB，下标 0 对应槽位 1）。
@immutable
class DiaryMoodColors {
  const DiaryMoodColors._(this._colors);

  /// 全部为内置色。
  static const DiaryMoodColors defaults = DiaryMoodColors._(
    kDiaryMoodDefaultColors,
  );

  /// 解码设置原文；空值、坏 JSON 或类型不符整份按默认处理，单个槽位读不懂
  /// 时只让这一格回到默认。
  factory DiaryMoodColors.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return defaults;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return defaults;
    }
    final json = StyleJson.map(decoded);
    if (json == null) {
      return defaults;
    }
    final colors = List<int>.of(kDiaryMoodDefaultColors);
    for (final entry in json.entries) {
      final slot = int.tryParse(entry.key);
      final color = StyleJson.argb(entry.value);
      if (slot == null || !_validSlot(slot) || color == null) {
        continue;
      }
      colors[slot - 1] = color;
    }
    return DiaryMoodColors._(List<int>.unmodifiable(colors));
  }

  final List<int> _colors;

  /// 槽位 [slot]（1–10）的颜色。
  int colorOf(int slot) => _colors[slot - 1];

  bool get isDefault => listEquals(_colors, kDiaryMoodDefaultColors);

  /// 把槽位 [slot] 换成 [color]（强制不透明）。
  DiaryMoodColors withColor(int slot, int color) {
    assert(_validSlot(slot));
    final next = List<int>.of(_colors);
    next[slot - 1] = 0xFF000000 | (color & 0x00FFFFFF);
    return DiaryMoodColors._(List<int>.unmodifiable(next));
  }

  /// 编码为设置原文：只写与默认不同的槽位；全部为默认时为 null（删除键）。
  String? encode() {
    final json = <String, Object>{};
    for (var slot = 1; slot <= SettingsService.moodOptionCount; slot += 1) {
      StyleJson.putColor(
        json,
        '$slot',
        colorOf(slot),
        kDiaryMoodDefaultColors[slot - 1],
      );
    }
    return json.isEmpty ? null : jsonEncode(json);
  }

  static bool _validSlot(int slot) =>
      slot >= 1 && slot <= SettingsService.moodOptionCount;

  @override
  bool operator ==(Object other) =>
      other is DiaryMoodColors && listEquals(other._colors, _colors);

  @override
  int get hashCode => Object.hashAll(_colors);
}

/// 心情符号与心情颜色合在一起：由一篇日记的心情符号查到它的颜色。
///
/// - [seedOf]：原色，作预览页整页主题的种子色；
/// - [accentOf]：按明暗取的强调色（见 [accentFor]），卡片的心情色与心情块用它。
///   按（槽位、明暗）记在实例里，实例由 provider 持有，列表滚动时不重复换算。
@immutable
class DiaryMoodPalette {
  DiaryMoodPalette({
    required List<String> moodOptions,
    this.colors = DiaryMoodColors.defaults,
  }) : moodOptions = SettingsService.normalizeMoodOptions(moodOptions),
       _slots = SettingsService.buildMoodWeightMap(moodOptions);

  /// 默认心情符号 + 内置色。
  static final DiaryMoodPalette defaults = DiaryMoodPalette(
    moodOptions: SettingsService.defaultMoodOptions,
  );

  /// 规整后的 10 个心情符号（由低落到高兴）。
  final List<String> moodOptions;
  final DiaryMoodColors colors;
  final Map<String, int> _slots;
  final Map<(int, Brightness), Color> _accents = <(int, Brightness), Color>{};

  /// 心情符号所在的槽位（1–10）；没有心情或不在心情配置里时为 null。
  int? slotOf(String? moodEmoji) {
    final mood = moodEmoji?.trim();
    if (mood == null || mood.isEmpty) {
      return null;
    }
    return _slots[mood];
  }

  /// 槽位 [slot] 的原色。
  Color seedForSlot(int slot) => Color(colors.colorOf(slot));

  /// 心情的原色；认不出心情时为 null。
  Color? seedOf(String? moodEmoji) {
    final slot = slotOf(moodEmoji);
    return slot == null ? null : seedForSlot(slot);
  }

  /// 槽位 [slot] 在 [brightness] 下的强调色。
  Color accentForSlot(int slot, Brightness brightness) => _accents.putIfAbsent((
    slot,
    brightness,
  ), () => accentFor(seedForSlot(slot), brightness));

  /// 心情在 [brightness] 下的强调色；认不出心情时为 null。
  Color? accentOf(String? moodEmoji, Brightness brightness) {
    final slot = slotOf(moodEmoji);
    return slot == null ? null : accentForSlot(slot, brightness);
  }

  /// 由一种心情色推出 [brightness] 下的强调色：fidelity 配色的 primary。
  ///
  /// 为什么不直接用原色：用户可能挑很浅或很深的颜色，直接拿来当描边、文字
  /// 或印章底色，在某一种明暗下会看不清。fidelity 保留原色的色相与浓淡
  /// （挑了偏灰的颜色仍是灰调，不像 tonalSpot 那样一律补到固定饱和度），
  /// 明暗则与主题的 primary 一样取浅色 40 / 深色 80 上下的色调，两种主题下
  /// 都和 primary 一样耐看。
  static Color accentFor(Color seed, Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).primary;
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryMoodPalette &&
      listEquals(other.moodOptions, moodOptions) &&
      other.colors == colors;

  @override
  int get hashCode => Object.hash(Object.hashAll(moodOptions), colors);
}
