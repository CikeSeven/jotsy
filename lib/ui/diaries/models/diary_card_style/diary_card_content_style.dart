part of 'diary_card_style.dart';

/// 卡片正文的组成：区块顺序、标题/摘要显隐、标签样式、置顶徽章、无封面
/// 占位与多图拼贴。两种布局共用。
///
/// 标签显示数量沿用独立的旧设置 `diaryCardTagLimit`（随备份单独导出），
/// 这里不重复保存。
@immutable
class DiaryCardContentStyle {
  const DiaryCardContentStyle({
    this.blocks = DiaryCardBlock.values,
    this.showTitle = true,
    this.showPreview = true,
    this.tagStyle = DiaryCardTagStyle.chip,
    this.pinnedBadge = DiaryCardPinnedBadge.standard,
    this.coverFallback = DiaryCardCoverFallback.none,
    this.collage = false,
  });

  /// 区块自上而下的顺序；每个区块恰好出现一次（解码时补齐）。
  final List<DiaryCardBlock> blocks;
  final bool showTitle;
  final bool showPreview;
  final DiaryCardTagStyle tagStyle;
  final DiaryCardPinnedBadge pinnedBadge;
  final DiaryCardCoverFallback coverFallback;

  /// 顶部封面改为最多三张正文图片的拼贴（只有一张图时仍是单图）。
  final bool collage;

  DiaryCardContentStyle copyWith({
    List<DiaryCardBlock>? blocks,
    bool? showTitle,
    bool? showPreview,
    DiaryCardTagStyle? tagStyle,
    DiaryCardPinnedBadge? pinnedBadge,
    DiaryCardCoverFallback? coverFallback,
    bool? collage,
  }) {
    return DiaryCardContentStyle(
      blocks: blocks == null
          ? this.blocks
          : _blocks(
              blocks.map((block) => block.name).toList(),
              DiaryCardBlock.values,
            ),
      showTitle: showTitle ?? this.showTitle,
      showPreview: showPreview ?? this.showPreview,
      tagStyle: tagStyle ?? this.tagStyle,
      pinnedBadge: pinnedBadge ?? this.pinnedBadge,
      coverFallback: coverFallback ?? this.coverFallback,
      collage: collage ?? this.collage,
    );
  }

  static DiaryCardContentStyle _fromJson(Object? raw) {
    const d = DiaryCardContentStyle();
    final json = _map(raw);
    if (json == null) {
      return d;
    }
    return DiaryCardContentStyle(
      blocks: _blocks(json['blocks'], d.blocks),
      showTitle: _bool(json['showTitle'], d.showTitle),
      showPreview: _bool(json['showPreview'], d.showPreview),
      tagStyle: _enumByName(
        DiaryCardTagStyle.values,
        json['tagStyle'],
        d.tagStyle,
      ),
      pinnedBadge: _enumByName(
        DiaryCardPinnedBadge.values,
        json['pinnedBadge'],
        d.pinnedBadge,
      ),
      coverFallback: _enumByName(
        DiaryCardCoverFallback.values,
        json['coverFallback'],
        d.coverFallback,
      ),
      collage: _bool(json['collage'], d.collage),
    );
  }

  Map<String, Object> _toJson() {
    const d = DiaryCardContentStyle();
    final json = <String, Object>{};
    if (!listEquals(blocks, d.blocks)) {
      json['blocks'] = blocks.map((block) => block.name).toList();
    }
    _put(json, 'showTitle', showTitle, d.showTitle);
    _put(json, 'showPreview', showPreview, d.showPreview);
    _putEnum(json, 'tagStyle', tagStyle, d.tagStyle);
    _putEnum(json, 'pinnedBadge', pinnedBadge, d.pinnedBadge);
    _putEnum(json, 'coverFallback', coverFallback, d.coverFallback);
    _put(json, 'collage', collage, d.collage);
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryCardContentStyle &&
        listEquals(other.blocks, blocks) &&
        other.showTitle == showTitle &&
        other.showPreview == showPreview &&
        other.tagStyle == tagStyle &&
        other.pinnedBadge == pinnedBadge &&
        other.coverFallback == coverFallback &&
        other.collage == collage;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(blocks),
    showTitle,
    showPreview,
    tagStyle,
    pinnedBadge,
    coverFallback,
    collage,
  );
}
