part of 'diary_preview_style.dart';

/// 正文与页尾：空正文提示、“最后编辑于”与时间胶囊解封提示。正文字体与排版
/// 只在 `DiaryTypography` 里设置，这里不重复。
@immutable
class DiaryPreviewBodyStyle {
  const DiaryPreviewBodyStyle({
    this.showEmptyHint = true,
    this.showLastEdited = true,
    this.editedFormat = DiaryPreviewEditedFormat.precise,
    this.showCapsuleInsight = true,
  });

  /// 没有正文时显示“今天还没有写下正文”。
  final bool showEmptyHint;
  final bool showLastEdited;
  final DiaryPreviewEditedFormat editedFormat;

  /// 已解封的时间胶囊顶部的提示卡。
  final bool showCapsuleInsight;

  DiaryPreviewBodyStyle copyWith({
    bool? showEmptyHint,
    bool? showLastEdited,
    DiaryPreviewEditedFormat? editedFormat,
    bool? showCapsuleInsight,
  }) {
    return DiaryPreviewBodyStyle(
      showEmptyHint: showEmptyHint ?? this.showEmptyHint,
      showLastEdited: showLastEdited ?? this.showLastEdited,
      editedFormat: editedFormat ?? this.editedFormat,
      showCapsuleInsight: showCapsuleInsight ?? this.showCapsuleInsight,
    );
  }

  static DiaryPreviewBodyStyle _fromJson(Object? raw) {
    const d = DiaryPreviewBodyStyle();
    final json = StyleJson.map(raw);
    if (json == null) {
      return d;
    }
    return DiaryPreviewBodyStyle(
      showEmptyHint: StyleJson.boolean(json['showEmptyHint'], d.showEmptyHint),
      showLastEdited: StyleJson.boolean(
        json['showLastEdited'],
        d.showLastEdited,
      ),
      editedFormat: StyleJson.enumByName(
        DiaryPreviewEditedFormat.values,
        json['editedFormat'],
        d.editedFormat,
      ),
      showCapsuleInsight: StyleJson.boolean(
        json['showCapsuleInsight'],
        d.showCapsuleInsight,
      ),
    );
  }

  Map<String, Object> _toJson() {
    const d = DiaryPreviewBodyStyle();
    final json = <String, Object>{};
    StyleJson.put(json, 'showEmptyHint', showEmptyHint, d.showEmptyHint);
    StyleJson.put(json, 'showLastEdited', showLastEdited, d.showLastEdited);
    StyleJson.putEnum(json, 'editedFormat', editedFormat, d.editedFormat);
    StyleJson.put(
      json,
      'showCapsuleInsight',
      showCapsuleInsight,
      d.showCapsuleInsight,
    );
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryPreviewBodyStyle &&
        other.showEmptyHint == showEmptyHint &&
        other.showLastEdited == showLastEdited &&
        other.editedFormat == editedFormat &&
        other.showCapsuleInsight == showCapsuleInsight;
  }

  @override
  int get hashCode => Object.hash(
    showEmptyHint,
    showLastEdited,
    editedFormat,
    showCapsuleInsight,
  );
}
