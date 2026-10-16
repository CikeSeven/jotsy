import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../diary_card_style/diary_card_style_enums.dart';
import '../style_library/style_json.dart';
import 'diary_preview_style_enums.dart';
import 'diary_preview_style_limits.dart';

export '../diary_card_style/diary_card_style_enums.dart'
    show DiaryCardDateFormat, DiaryCardDateSource, DiaryCardTagStyle;
export 'diary_preview_style_enums.dart';
export 'diary_preview_style_limits.dart';

part 'diary_preview_body_style.dart';
part 'diary_preview_cover_style.dart';
part 'diary_preview_meta_style.dart';
part 'diary_preview_page_style.dart';
part 'diary_preview_title_style.dart';

/// 日记预览页（阅读页）的完整外观。
///
/// 输入：持久化的 JSON（单键 `diaryPreviewStyleRaw` 中的 `current`，或样式码）；
/// 输出：不可变的样式对象。无副作用，也不依赖 Flutter 的 `Color`——颜色以
/// ARGB 整数保存，解析为具体颜色、尺寸由渲染层（`DiaryPreviewResolvedStyle`）
/// 负责。正文的字体、字号与行距不在这里：它们只存于 `DiaryTypography`，编辑
/// 页与预览页共用。
///
/// 结构：[page] 页面与顶栏，[cover] 头图，[title] 标题，[meta] 信息栏，[body]
/// 正文与页尾。
///
/// 兼容策略：
/// - 默认值逐项等于改版前写死的预览页（DESIGN.md §5.8），未自定义的用户看
///   不到变化（新增的字数与阅读时长默认显示）；
/// - 解码逐字段容错：缺失、类型不符、未知枚举名或越界的数值只让该字段回退
///   到默认值（越界夹到边界）；
/// - 编码是稀疏的：只写与默认值不同的字段，样式码更短，未改动的字段也能
///   跟随以后对默认外观的微调。
@immutable
class DiaryPreviewStyle {
  const DiaryPreviewStyle({
    this.page = const DiaryPreviewPageStyle(),
    this.cover = const DiaryPreviewCoverStyle(),
    this.title = const DiaryPreviewTitleStyle(),
    this.meta = const DiaryPreviewMetaStyle(),
    this.body = const DiaryPreviewBodyStyle(),
  });

  static const DiaryPreviewStyle defaults = DiaryPreviewStyle();

  /// 解析持久化的 JSON；null、空串或损坏时返回默认样式。
  factory DiaryPreviewStyle.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return defaults;
    }
    try {
      return DiaryPreviewStyle.fromJson(jsonDecode(raw));
    } catch (_) {
      // 损坏的配置按默认样式展示，不阻断阅读。
      return defaults;
    }
  }

  /// 从已解码的 JSON 构造；不是对象时返回默认样式。
  factory DiaryPreviewStyle.fromJson(Object? raw) {
    final json = StyleJson.map(raw);
    if (json == null) {
      return defaults;
    }
    return DiaryPreviewStyle(
      page: DiaryPreviewPageStyle._fromJson(json['page']),
      cover: DiaryPreviewCoverStyle._fromJson(json['cover']),
      title: DiaryPreviewTitleStyle._fromJson(json['title']),
      meta: DiaryPreviewMetaStyle._fromJson(json['meta']),
      body: DiaryPreviewBodyStyle._fromJson(json['body']),
    );
  }

  final DiaryPreviewPageStyle page;
  final DiaryPreviewCoverStyle cover;
  final DiaryPreviewTitleStyle title;
  final DiaryPreviewMetaStyle meta;
  final DiaryPreviewBodyStyle body;

  bool get isDefault => this == defaults;

  /// 稀疏 JSON：默认样式编码为空对象。
  Map<String, Object> toJson() {
    final json = <String, Object>{};
    StyleJson.putObject(json, 'page', page._toJson());
    StyleJson.putObject(json, 'cover', cover._toJson());
    StyleJson.putObject(json, 'title', title._toJson());
    StyleJson.putObject(json, 'meta', meta._toJson());
    StyleJson.putObject(json, 'body', body._toJson());
    return json;
  }

  String encode() => jsonEncode(toJson());

  DiaryPreviewStyle copyWith({
    DiaryPreviewPageStyle? page,
    DiaryPreviewCoverStyle? cover,
    DiaryPreviewTitleStyle? title,
    DiaryPreviewMetaStyle? meta,
    DiaryPreviewBodyStyle? body,
  }) {
    return DiaryPreviewStyle(
      page: page ?? this.page,
      cover: cover ?? this.cover,
      title: title ?? this.title,
      meta: meta ?? this.meta,
      body: body ?? this.body,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryPreviewStyle &&
        other.page == page &&
        other.cover == cover &&
        other.title == title &&
        other.meta == meta &&
        other.body == body;
  }

  @override
  int get hashCode => Object.hash(page, cover, title, meta, body);
}
