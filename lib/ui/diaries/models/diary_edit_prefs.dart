// 编辑器设置 → 编辑行为的偏好（已有日记保存方式、插入图片/视频默认小图）。
//
// 存储：单个 JSON 设置键 `app.settings.diary_edit_prefs`（经
// `SettingsService.setDiaryEditPrefsRaw`），逐字段容错解析；全为默认时不存
// 这个键。随备份导出，导入失败时回滚（与编辑器的其他写作偏好一样）。新建
// 日记的偏好另在 `DiaryCreatePrefs`。

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 编辑已有日记时，修改怎样写进库里。
enum DiaryEditSaveMode {
  /// 改了就自动保存（防抖），返回、切后台与打开别的页面时补存。默认。
  auto('auto'),

  /// 只在点顶栏“保存”（桌面 Ctrl / ⌘ + S）时写入；有未保存的修改时返回先
  /// 询问（取消 / 放弃 / 保存并退出），见 `EditDiaryPersistenceFlow`。
  manual('manual');

  const DiaryEditSaveMode(this.storageName);

  /// 在设置 JSON 里的取值。改名会让已选的用户回到默认，不要改。
  final String storageName;

  /// 认不出的取值（类型不对、较新版本写入的）按默认处理。
  static DiaryEditSaveMode fromStorage(Object? value) {
    for (final mode in values) {
      if (mode.storageName == value) return mode;
    }
    return auto;
  }
}

/// 编辑器的编辑行为偏好。不可变。
@immutable
class DiaryEditPrefs {
  const DiaryEditPrefs({
    this.saveMode = DiaryEditSaveMode.auto,
    this.defaultMediaThumbnail = false,
  });

  static const DiaryEditPrefs defaults = DiaryEditPrefs();

  static const _keySave = 'save';
  static const _keyDefaultMediaThumbnail = 'default_media_thumbnail';

  /// 修改怎样写进库里。
  final DiaryEditSaveMode saveMode;

  /// 插入图片与视频时是否默认以小图显示（默认关）。
  final bool defaultMediaThumbnail;

  /// 手动保存。
  bool get manualSave => saveMode == DiaryEditSaveMode.manual;

  DiaryEditPrefs copyWith({
    DiaryEditSaveMode? saveMode,
    bool? defaultMediaThumbnail,
  }) => DiaryEditPrefs(
    saveMode: saveMode ?? this.saveMode,
    defaultMediaThumbnail: defaultMediaThumbnail ?? this.defaultMediaThumbnail,
  );

  /// 解析设置原文：空值、坏 JSON 或不是对象时为 [defaults]；每个字段单独
  /// 容错。
  static DiaryEditPrefs decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaults;
    final Object? node;
    try {
      node = jsonDecode(raw);
    } on FormatException {
      return defaults;
    }
    if (node is! Map) return defaults;
    final thumbnail = node[_keyDefaultMediaThumbnail];
    return DiaryEditPrefs(
      saveMode: DiaryEditSaveMode.fromStorage(node[_keySave]),
      defaultMediaThumbnail: thumbnail is bool ? thumbnail : false,
    );
  }

  /// 编码为设置原文；全为默认时为 null（移除这个键，备份里不留冗余配置）。
  String? encode() {
    if (this == defaults) return null;
    final json = <String, Object>{
      if (saveMode != DiaryEditSaveMode.auto) _keySave: saveMode.storageName,
      if (defaultMediaThumbnail) _keyDefaultMediaThumbnail: true,
    };
    return json.isEmpty ? null : jsonEncode(json);
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryEditPrefs &&
      other.saveMode == saveMode &&
      other.defaultMediaThumbnail == defaultMediaThumbnail;

  @override
  int get hashCode => Object.hash(saveMode, defaultMediaThumbnail);
}
