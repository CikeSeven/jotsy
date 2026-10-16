import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'diary_card_style_enums.dart';
import 'diary_card_style_limits.dart';

export 'diary_card_style_enums.dart';
export 'diary_card_style_limits.dart';

part 'diary_card_color_spec.dart';
part 'diary_card_content_style.dart';
part 'diary_card_meta_style.dart';
part 'diary_card_mode_style.dart';
part 'diary_card_mode_style_json.dart';
part 'diary_card_style_json.dart';
part 'diary_card_surface_style.dart';
part 'diary_card_typography.dart';

/// 日记列表卡片的完整样式。
///
/// 输入：持久化的 JSON（单键 `diaryCardStyleRaw` 中的 `current`，或样式码）；
/// 输出：不可变的样式对象。无副作用，也不依赖 Flutter 的 `Color`——颜色以
/// ARGB 整数保存，解析为具体颜色、字号与间距由渲染层负责。
///
/// 结构：[surface]、[typography]、[content]、[meta] 两种布局共用；[list] 与
/// [waterfall] 是各模式专属的封面、间距与行数。
///
/// 兼容策略：
/// - 默认值逐项等于改版前写死的卡片（DESIGN.md §5.1），未自定义的用户看不
///   到任何变化；
/// - 解码逐字段容错：缺失、类型不符、未知枚举名或越界的数值只让该字段回退
///   到默认值（越界夹到边界），备份或样式码的局部损坏不会连累其余选择；
/// - 编码是稀疏的：只写与默认值不同的字段。样式码因此更短，未改动的字段
///   也能跟随以后对默认外观的微调。
@immutable
class DiaryCardStyle {
  const DiaryCardStyle({
    this.surface = const DiaryCardSurfaceStyle(),
    this.typography = const DiaryCardTypography(),
    this.content = const DiaryCardContentStyle(),
    this.meta = const DiaryCardMetaStyle(),
    this.list = DiaryCardModeStyle.listDefaults,
    this.waterfall = DiaryCardModeStyle.waterfallDefaults,
  });

  static const DiaryCardStyle defaults = DiaryCardStyle();

  /// 解析持久化的 JSON；null、空串或损坏时返回默认样式。
  factory DiaryCardStyle.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return defaults;
    }
    try {
      return DiaryCardStyle.fromJson(jsonDecode(raw));
    } catch (_) {
      // 损坏的配置按默认样式展示，不阻断日记列表。
      return defaults;
    }
  }

  /// 从已解码的 JSON 构造；不是对象时返回默认样式。
  factory DiaryCardStyle.fromJson(Object? raw) {
    final json = _map(raw);
    if (json == null) {
      return defaults;
    }
    return DiaryCardStyle(
      surface: DiaryCardSurfaceStyle._fromJson(json['surface']),
      typography: DiaryCardTypography._fromJson(json['typography']),
      content: DiaryCardContentStyle._fromJson(json['content']),
      meta: DiaryCardMetaStyle._fromJson(json['meta']),
      list: _modeFromJson(json['list'], DiaryCardMode.list),
      waterfall: _modeFromJson(json['waterfall'], DiaryCardMode.waterfall),
    );
  }

  final DiaryCardSurfaceStyle surface;
  final DiaryCardTypography typography;
  final DiaryCardContentStyle content;
  final DiaryCardMetaStyle meta;
  final DiaryCardModeStyle list;
  final DiaryCardModeStyle waterfall;

  bool get isDefault => this == defaults;

  DiaryCardModeStyle mode(DiaryCardMode mode) => switch (mode) {
    DiaryCardMode.list => list,
    DiaryCardMode.waterfall => waterfall,
  };

  /// 替换某一模式的专属样式。
  DiaryCardStyle withMode(DiaryCardMode mode, DiaryCardModeStyle style) =>
      switch (mode) {
        DiaryCardMode.list => copyWith(list: style),
        DiaryCardMode.waterfall => copyWith(waterfall: style),
      };

  /// 稀疏 JSON：默认样式编码为空对象。
  Map<String, Object> toJson() {
    final json = <String, Object>{};
    _putObject(json, 'surface', surface._toJson());
    _putObject(json, 'typography', typography._toJson());
    _putObject(json, 'content', content._toJson());
    _putObject(json, 'meta', meta._toJson());
    _putObject(json, 'list', _modeToJson(list, DiaryCardMode.list));
    _putObject(
      json,
      'waterfall',
      _modeToJson(waterfall, DiaryCardMode.waterfall),
    );
    return json;
  }

  String encode() => jsonEncode(toJson());

  DiaryCardStyle copyWith({
    DiaryCardSurfaceStyle? surface,
    DiaryCardTypography? typography,
    DiaryCardContentStyle? content,
    DiaryCardMetaStyle? meta,
    DiaryCardModeStyle? list,
    DiaryCardModeStyle? waterfall,
  }) {
    return DiaryCardStyle(
      surface: surface ?? this.surface,
      typography: typography ?? this.typography,
      content: content ?? this.content,
      meta: meta ?? this.meta,
      list: list ?? this.list,
      waterfall: waterfall ?? this.waterfall,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryCardStyle &&
        other.surface == surface &&
        other.typography == typography &&
        other.content == content &&
        other.meta == meta &&
        other.list == list &&
        other.waterfall == waterfall;
  }

  @override
  int get hashCode =>
      Object.hash(surface, typography, content, meta, list, waterfall);
}
