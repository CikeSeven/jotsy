part of 'home_widget_content.dart';

// 那年今日与最近日记的内容选项（见 home_widget_content.dart 文件头）。

/// 那年今日按什么算“这一天”：与探索页“那年今日”的匹配口径一致
/// （`ExploreOnThisDayMatch`，枚举名相同）。
enum OnThisDayMatch {
  /// 往年的同月同日。
  sameDay,

  /// 往年的前后 3 天内。
  nearby,

  /// 往年的同月。
  sameMonth,
}

class OnThisDayContent extends HomeWidgetContent {
  const OnThisDayContent({
    this.match = OnThisDayMatch.sameDay,
    this.showPhoto = true,
    this.showExcerpt = true,
  });

  static const OnThisDayContent defaults = OnThisDayContent();

  final OnThisDayMatch match;

  /// 日记里有照片时以照片为主（封面优先，其次正文里第一张）。
  final bool showPhoto;

  /// 标题下方显示正文摘要。
  final bool showExcerpt;

  OnThisDayContent copyWith({
    OnThisDayMatch? match,
    bool? showPhoto,
    bool? showExcerpt,
  }) => OnThisDayContent(
    match: match ?? this.match,
    showPhoto: showPhoto ?? this.showPhoto,
    showExcerpt: showExcerpt ?? this.showExcerpt,
  );

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'match': match.name,
    'photo': showPhoto,
    'excerpt': showExcerpt,
  };

  static OnThisDayContent _fromJson(Map<Object?, Object?> json) =>
      OnThisDayContent(
        match: _pick(OnThisDayMatch.values, json['match'], defaults.match),
        showPhoto: _bool(json['photo'], defaults.showPhoto),
        showExcerpt: _bool(json['excerpt'], defaults.showExcerpt),
      );

  @override
  bool operator ==(Object other) =>
      other is OnThisDayContent &&
      other.match == match &&
      other.showPhoto == showPhoto &&
      other.showExcerpt == showExcerpt;

  @override
  int get hashCode => Object.hash(match, showPhoto, showExcerpt);
}

/// 最近日记从哪里取。
enum RecentDiariesSource {
  /// 全部日记（不含私密日记，与首页“全部日记”同一口径）。
  all,

  /// 某个日记本（[RecentDiariesContent.notebookId]，只能选非私密的）。
  notebook,

  /// 带某个标签的（[RecentDiariesContent.tagName]）。
  tag,

  /// 置顶的。
  pinned,
}

class RecentDiariesContent extends HomeWidgetContent {
  const RecentDiariesContent({
    this.source = RecentDiariesSource.all,
    this.notebookId,
    this.tagName,
    this.showPhotos = true,
    this.showExcerpt = true,
  });

  static const RecentDiariesContent defaults = RecentDiariesContent();

  final RecentDiariesSource source;

  /// [RecentDiariesSource.notebook] 时的日记本（业务 id）；本子被删除、变成私密
  /// 或日记本功能关闭时按全部日记显示。
  final String? notebookId;

  /// [RecentDiariesSource.tag] 时的标签。存名字而不是本地 id：标签的本地 id 在
  /// 恢复备份后会变（与智能日记本规则同一做法）。标签已不存在时按全部日记显示。
  final String? tagName;

  /// 有照片的日记在行首显示缩略图（没有照片的显示日期）。
  final bool showPhotos;

  /// 标题下方显示正文摘要。
  final bool showExcerpt;

  RecentDiariesContent copyWith({
    RecentDiariesSource? source,
    String? Function()? notebookId,
    String? Function()? tagName,
    bool? showPhotos,
    bool? showExcerpt,
  }) => RecentDiariesContent(
    source: source ?? this.source,
    notebookId: notebookId == null ? this.notebookId : notebookId(),
    tagName: tagName == null ? this.tagName : tagName(),
    showPhotos: showPhotos ?? this.showPhotos,
    showExcerpt: showExcerpt ?? this.showExcerpt,
  );

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'source': source.name,
    'notebook': ?notebookId,
    'tag': ?tagName,
    'photos': showPhotos,
    'excerpt': showExcerpt,
  };

  static RecentDiariesContent _fromJson(Map<Object?, Object?> json) {
    final notebook = json['notebook'];
    final tag = json['tag'];
    return RecentDiariesContent(
      source: _pick(
        RecentDiariesSource.values,
        json['source'],
        defaults.source,
      ),
      notebookId: notebook is String && notebook.isNotEmpty ? notebook : null,
      tagName: tag is String && tag.isNotEmpty ? tag : null,
      showPhotos: _bool(json['photos'], defaults.showPhotos),
      showExcerpt: _bool(json['excerpt'], defaults.showExcerpt),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RecentDiariesContent &&
      other.source == source &&
      other.notebookId == notebookId &&
      other.tagName == tagName &&
      other.showPhotos == showPhotos &&
      other.showExcerpt == showExcerpt;

  @override
  int get hashCode =>
      Object.hash(source, notebookId, tagName, showPhotos, showExcerpt);
}
