part of 'diary_card_style.dart';

// DiaryCardModeStyle 的 JSON 读写。两种模式默认值不同，编解码都以该模式
// 的默认值为基准：缺失字段回退到本模式默认值，编码只写与之不同的项。

DiaryCardModeStyle _modeFromJson(Object? raw, DiaryCardMode mode) {
  final d = DiaryCardModeStyle.defaultsFor(mode);
  final json = _map(raw);
  if (json == null) {
    return d;
  }
  var coverPosition = _enumByName(
    DiaryCardCoverPosition.values,
    json['coverPosition'],
    d.coverPosition,
  );
  // 瀑布流列宽只有半屏，侧边封面放不下：旧数据或手改的样式码出现时回到顶部。
  if (!DiaryCardModeStyle.coverPositionsFor(mode).contains(coverPosition)) {
    coverPosition = d.coverPosition;
  }
  return DiaryCardModeStyle(
    coverPosition: coverPosition,
    coverSide: _double(
      json['coverSide'],
      d.coverSide,
      DiaryCardStyleLimits.coverSide,
    ),
    coverShape: _enumByName(
      DiaryCardCoverShape.values,
      json['coverShape'],
      d.coverShape,
    ),
    coverRadius: _double(
      json['coverRadius'],
      d.coverRadius,
      DiaryCardStyleLimits.coverRadius,
    ),
    coverHeight: _double(
      json['coverHeight'],
      d.coverHeight,
      DiaryCardStyleLimits.coverHeight,
    ),
    coverInset: _bool(json['coverInset'], d.coverInset),
    coverDivider: _bool(json['coverDivider'], d.coverDivider),
    coverGap: _double(
      json['coverGap'],
      d.coverGap,
      DiaryCardStyleLimits.coverGap,
    ),
    scrim: _double(json['scrim'], d.scrim, DiaryCardStyleLimits.scrim),
    paddingH: _double(
      json['paddingH'],
      d.paddingH,
      DiaryCardStyleLimits.paddingH,
    ),
    paddingV: _double(
      json['paddingV'],
      d.paddingV,
      DiaryCardStyleLimits.paddingV,
    ),
    cardGap: _double(json['cardGap'], d.cardGap, DiaryCardStyleLimits.cardGap),
    sideMargin: _double(
      json['sideMargin'],
      d.sideMargin,
      DiaryCardStyleLimits.sideMargin,
    ),
    elementGap: _double(
      json['elementGap'],
      d.elementGap,
      DiaryCardStyleLimits.elementGap,
    ),
    titleMaxLines: _int(
      json['titleMaxLines'],
      d.titleMaxLines,
      DiaryCardStyleLimits.titleMaxLines,
    ),
    previewMaxLines: _int(
      json['previewMaxLines'],
      d.previewMaxLines,
      DiaryCardStyleLimits.previewMaxLines,
    ),
    metaPosition: _enumByName(
      DiaryCardMetaPosition.values,
      json['metaPosition'],
      d.metaPosition,
    ),
    columns: _int(json['columns'], d.columns, DiaryCardStyleLimits.columns),
  );
}

Map<String, Object> _modeToJson(DiaryCardModeStyle s, DiaryCardMode mode) {
  final d = DiaryCardModeStyle.defaultsFor(mode);
  final json = <String, Object>{};
  _putEnum(json, 'coverPosition', s.coverPosition, d.coverPosition);
  _put(json, 'coverSide', s.coverSide, d.coverSide);
  _putEnum(json, 'coverShape', s.coverShape, d.coverShape);
  _put(json, 'coverRadius', s.coverRadius, d.coverRadius);
  _put(json, 'coverHeight', s.coverHeight, d.coverHeight);
  _put(json, 'coverInset', s.coverInset, d.coverInset);
  _put(json, 'coverDivider', s.coverDivider, d.coverDivider);
  _put(json, 'coverGap', s.coverGap, d.coverGap);
  _put(json, 'scrim', s.scrim, d.scrim);
  _put(json, 'paddingH', s.paddingH, d.paddingH);
  _put(json, 'paddingV', s.paddingV, d.paddingV);
  _put(json, 'cardGap', s.cardGap, d.cardGap);
  _put(json, 'sideMargin', s.sideMargin, d.sideMargin);
  _put(json, 'elementGap', s.elementGap, d.elementGap);
  _put(json, 'titleMaxLines', s.titleMaxLines, d.titleMaxLines);
  _put(json, 'previewMaxLines', s.previewMaxLines, d.previewMaxLines);
  _putEnum(json, 'metaPosition', s.metaPosition, d.metaPosition);
  _put(json, 'columns', s.columns, d.columns);
  return json;
}
