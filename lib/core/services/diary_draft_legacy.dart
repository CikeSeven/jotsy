import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../database/content_codec.dart';
import 'settings_service.dart';

/// 草稿箱之前的单份新建草稿。
///
/// 旧版本把唯一一份草稿存成 SharedPreferences 的 JSON 字符串（键
/// `app.settings.diary_create_draft`），完整备份里对应 `settings.createDiaryDraftRaw`。
/// 两处来源都经 [parse] 转成草稿表的一行；JSON 结构与编辑页的草稿模型一致，
/// 原样作为 `payload`，这里只取标题与纯文本镜像，不依赖界面层模型。
typedef LegacyCreateDraft = ({
  String title,
  String contentText,
  String payload,
});

/// 解析旧草稿；空白、坏 JSON 或没有可见内容（与编辑页“有内容才存草稿”
/// 同一口径）时返回 null。
LegacyCreateDraft? parseLegacyCreateDraft(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  final title = decoded['title'] is String ? decoded['title'] as String : '';
  final contentText = decoded['contentText'] is String
      ? decoded['contentText'] as String
      : '';
  final contentDocJson = decoded['contentDocJson'] is String
      ? decoded['contentDocJson'] as String
      : '';
  final hasContent =
      title.trim().isNotEmpty ||
      contentText.trim().isNotEmpty ||
      diaryContentHasEmbeddedContent(contentDocJson);
  if (!hasContent) return null;
  return (title: title, contentText: contentText, payload: raw);
}

/// 启动时把旧版本留下的单份草稿搬进草稿箱，进程内只需执行一次。
///
/// 顺序：先写草稿表、成功后才清旧键——写库失败时旧键原样保留，下次启动再
/// 试，草稿不会两边都没有。旧键为空、或内容为空的草稿（旧版本清空正文时
/// 本就会删掉它）直接清除；JSON 坏掉的保留不动，不替用户丢掉数据。媒体清理
/// 在旧键清空前仍把它当作引用来源，迁移前后草稿里的图片都不会被回收。
Future<void> migrateLegacyCreateDraft({
  required AppDatabase database,
  required SettingsService settings,
}) async {
  final raw = settings.createDiaryDraftRaw;
  if (raw == null) return;
  final draft = parseLegacyCreateDraft(raw);
  if (draft == null) {
    if (_isUnreadable(raw)) {
      debugPrint('Legacy create draft kept: not valid JSON.');
      return;
    }
    await settings.clearCreateDiaryDraft();
    return;
  }
  await database.saveDiaryDraft(
    title: draft.title,
    contentText: draft.contentText,
    payload: draft.payload,
  );
  await settings.clearCreateDiaryDraft();
}

bool _isUnreadable(String raw) {
  if (raw.trim().isEmpty) return false;
  try {
    return jsonDecode(raw) is! Map<String, dynamic>;
  } on FormatException {
    return true;
  }
}
