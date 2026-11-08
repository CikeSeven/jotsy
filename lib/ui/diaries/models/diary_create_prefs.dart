// 新建日记的偏好（设置 → 编辑器设置 → 编辑行为）。
//
// 存储：单个 JSON 设置键 `app.settings.diary_create_prefs`（经
// `SettingsService.setDiaryCreatePrefsRaw`），形如 `{"leave":"publish"}`，
// 逐字段容错解析；全为默认时不存这个键。随备份导出，导入失败时回滚（与
// 编辑器的其他写作偏好一样）。

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 新建日记时按返回（返回键、顶栏返回、桌面 Esc）怎样处理这篇（#196）。
enum DiaryCreateLeaveAction {
  /// 存进草稿箱，之后从草稿箱续写、发表。默认，也是改版前的行为。
  keepDraft('draft'),

  /// 直接发表成日记，不经发布页（带时间胶囊的仍经发布页，见
  /// `EditDiaryCreateLeaveFlow`）。
  publish('publish');

  const DiaryCreateLeaveAction(this.storageName);

  /// 在设置 JSON 里的取值。改名会让已选的用户回到默认，不要改。
  final String storageName;

  /// 认不出的取值（类型不对、较新版本写入的）按默认处理。
  static DiaryCreateLeaveAction fromStorage(Object? value) {
    for (final action in values) {
      if (action.storageName == value) return action;
    }
    return keepDraft;
  }
}

/// 新建日记的偏好。不可变。
@immutable
class DiaryCreatePrefs {
  const DiaryCreatePrefs({this.leaveAction = DiaryCreateLeaveAction.keepDraft});

  static const DiaryCreatePrefs defaults = DiaryCreatePrefs();

  static const _keyLeave = 'leave';

  /// 按返回时怎样处理这篇新日记。
  final DiaryCreateLeaveAction leaveAction;

  /// 按返回时直接发表。
  bool get publishOnLeave => leaveAction == DiaryCreateLeaveAction.publish;

  DiaryCreatePrefs copyWith({DiaryCreateLeaveAction? leaveAction}) =>
      DiaryCreatePrefs(leaveAction: leaveAction ?? this.leaveAction);

  /// 解析设置原文：空值、坏 JSON 或不是对象时为 [defaults]；每个字段单独
  /// 容错。
  static DiaryCreatePrefs decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaults;
    final Object? node;
    try {
      node = jsonDecode(raw);
    } on FormatException {
      return defaults;
    }
    if (node is! Map) return defaults;
    return DiaryCreatePrefs(
      leaveAction: DiaryCreateLeaveAction.fromStorage(node[_keyLeave]),
    );
  }

  /// 编码为设置原文；全为默认时为 null（移除这个键，备份里不留冗余配置）。
  String? encode() {
    if (this == defaults) return null;
    return jsonEncode(<String, Object>{_keyLeave: leaveAction.storageName});
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryCreatePrefs && other.leaveAction == leaveAction;

  @override
  int get hashCode => leaveAction.hashCode;
}
