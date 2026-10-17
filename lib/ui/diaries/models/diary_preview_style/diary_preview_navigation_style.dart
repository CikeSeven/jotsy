part of 'diary_preview_style.dart';

/// 翻页的外观：过渡效果、正文末尾的“上一篇 / 下一篇”与到头提示。左右滑动
/// 的开关与灵敏度属于阅读行为（`DiaryPreviewBehavior`），不在这里。
@immutable
class DiaryPreviewNavigationStyle {
  const DiaryPreviewNavigationStyle({
    this.transition = DiaryPreviewPageTransition.slide,
    this.neighborCards = false,
    this.edgeHint = true,
  });

  final DiaryPreviewPageTransition transition;

  /// 正文末尾显示上一篇、下一篇的标题，点按翻过去。
  final bool neighborCards;

  /// 已经是第一篇或最后一篇还往外拉时，在边缘提示。
  final bool edgeHint;

  DiaryPreviewNavigationStyle copyWith({
    DiaryPreviewPageTransition? transition,
    bool? neighborCards,
    bool? edgeHint,
  }) {
    return DiaryPreviewNavigationStyle(
      transition: transition ?? this.transition,
      neighborCards: neighborCards ?? this.neighborCards,
      edgeHint: edgeHint ?? this.edgeHint,
    );
  }

  static DiaryPreviewNavigationStyle _fromJson(Object? raw) {
    const d = DiaryPreviewNavigationStyle();
    final json = StyleJson.map(raw);
    if (json == null) {
      return d;
    }
    return DiaryPreviewNavigationStyle(
      transition: StyleJson.enumByName(
        DiaryPreviewPageTransition.values,
        json['transition'],
        d.transition,
      ),
      neighborCards: StyleJson.boolean(json['neighborCards'], d.neighborCards),
      edgeHint: StyleJson.boolean(json['edgeHint'], d.edgeHint),
    );
  }

  Map<String, Object> _toJson() {
    const d = DiaryPreviewNavigationStyle();
    final json = <String, Object>{};
    StyleJson.putEnum(json, 'transition', transition, d.transition);
    StyleJson.put(json, 'neighborCards', neighborCards, d.neighborCards);
    StyleJson.put(json, 'edgeHint', edgeHint, d.edgeHint);
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryPreviewNavigationStyle &&
        other.transition == transition &&
        other.neighborCards == neighborCards &&
        other.edgeHint == edgeHint;
  }

  @override
  int get hashCode => Object.hash(transition, neighborCards, edgeHint);
}
