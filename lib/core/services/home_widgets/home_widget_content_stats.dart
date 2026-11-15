part of 'home_widget_content.dart';

// 写作统计与照片回忆的内容选项（见 home_widget_content.dart 文件头）。

/// 写作统计热力图的着色依据（与探索页热力图的“篇数 / 字数”一致）。
enum WritingHeatBasis { entries, words }

class WritingStatsContent extends HomeWidgetContent {
  const WritingStatsContent({
    this.basis = WritingHeatBasis.entries,
    this.showHeatmap = true,
  });

  static const WritingStatsContent defaults = WritingStatsContent();

  final WritingHeatBasis basis;

  /// 4×2 与 4×4 显示最近几周的热力图（2×2 放不下，不显示）。
  final bool showHeatmap;

  WritingStatsContent copyWith({WritingHeatBasis? basis, bool? showHeatmap}) =>
      WritingStatsContent(
        basis: basis ?? this.basis,
        showHeatmap: showHeatmap ?? this.showHeatmap,
      );

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'basis': basis.name,
    'heatmap': showHeatmap,
  };

  static WritingStatsContent _fromJson(Map<Object?, Object?> json) =>
      WritingStatsContent(
        basis: _pick(WritingHeatBasis.values, json['basis'], defaults.basis),
        showHeatmap: _bool(json['heatmap'], defaults.showHeatmap),
      );

  @override
  bool operator ==(Object other) =>
      other is WritingStatsContent &&
      other.basis == basis &&
      other.showHeatmap == showHeatmap;

  @override
  int get hashCode => Object.hash(basis, showHeatmap);
}

/// 照片回忆从哪些日记里取照片。
enum PhotoMemorySource {
  /// 最近带照片的日记（不含私密日记与未到期的胶囊）。
  all,

  /// 往年今天前后几天的日记；这几天没有带照片的日记时退回 [all]。
  onThisDay,

  /// 某个日记本（[PhotoMemoriesContent.notebookId]，只能选非私密的）。
  notebook,
}

class PhotoMemoriesContent extends HomeWidgetContent {
  const PhotoMemoriesContent({
    this.source = PhotoMemorySource.all,
    this.notebookId,
    this.showDate = true,
  });

  static const PhotoMemoriesContent defaults = PhotoMemoriesContent();

  final PhotoMemorySource source;

  /// [PhotoMemorySource.notebook] 时的日记本（业务 id）；本子被删除、变成私密或
  /// 日记本功能关闭时按 [PhotoMemorySource.all] 取。
  final String? notebookId;

  /// 照片左下角显示日期（那年今日为“N 年前的今天”）。
  final bool showDate;

  PhotoMemoriesContent copyWith({
    PhotoMemorySource? source,
    String? Function()? notebookId,
    bool? showDate,
  }) => PhotoMemoriesContent(
    source: source ?? this.source,
    notebookId: notebookId == null ? this.notebookId : notebookId(),
    showDate: showDate ?? this.showDate,
  );

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'source': source.name,
    'notebook': ?notebookId,
    'date': showDate,
  };

  static PhotoMemoriesContent _fromJson(Map<Object?, Object?> json) {
    final notebook = json['notebook'];
    return PhotoMemoriesContent(
      source: _pick(PhotoMemorySource.values, json['source'], defaults.source),
      notebookId: notebook is String && notebook.isNotEmpty ? notebook : null,
      showDate: _bool(json['date'], defaults.showDate),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PhotoMemoriesContent &&
      other.source == source &&
      other.notebookId == notebookId &&
      other.showDate == showDate;

  @override
  int get hashCode => Object.hash(source, notebookId, showDate);
}
