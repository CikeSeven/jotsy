part of 'diary_card_style.dart';

/// 卡片正文的组成：区块顺序、标题/摘要显隐、“无标题”占位、标签样式、
/// 置顶徽章、无封面占位与多图拼贴。两种布局共用。
///
/// 标签显示数量沿用独立的旧设置 `diaryCardTagLimit`（随备份单独导出），
/// 这里不重复保存。
@immutable
class DiaryCardContentStyle {
  const DiaryCardContentStyle({
    this.blocks = DiaryCardBlock.values,
    this.showTitle = true,
    this.showUntitled = true,
    this.showPreview = true,
    this.tagStyle = DiaryCardTagStyle.chip,
    this.pinnedBadge = DiaryCardPinnedBadge.standard,
    this.coverFallback = DiaryCardCoverFallback.none,
    this.collage = false,
  });

  /// 区块自上而下的顺序；每个区块恰好出现一次（解码时补齐）。
  final List<DiaryCardBlock> blocks;
  final bool showTitle;

  /// 没写标题的日记是否用“无标题”占位；关闭后这类日记不显示标题行。
  /// 只在 [showTitle] 开启时起作用，未解封胶囊不受影响。
  final bool showUntitled;
  final bool showPreview;
  final DiaryCardTagStyle tagStyle;
  final DiaryCardPinnedBadge pinnedBadge;
  final DiaryCardCoverFallback coverFallback;

  /// 顶部封面改为最多三张正文图片的拼贴（只有一张图时仍是单图）。
  final bool collage;

  DiaryCardContentStyle copyWith({
    List<DiaryCardBlock>? blocks,
    bool? showTitle,
    bool? showUntitled,
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
      showUntitled: showUntitled ?? this.showUntitled,
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
      showUntitled: _bool(json['showUntitled'], d.showUntitled),
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
    _put(json, 'showUntitled', showUntitled, d.showUntitled);
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
        other.showUntitled == showUntitled &&
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
    showUntitled,
    showPreview,
    tagStyle,
    pinnedBadge,
    coverFallback,
    collage,
  );
}
