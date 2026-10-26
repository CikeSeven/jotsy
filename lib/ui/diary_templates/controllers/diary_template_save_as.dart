import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_media.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../models/diary_template.dart';
import '../models/diary_template_json.dart';
import '../pages/diary_template_editor_page.dart';

/// 把一篇日记或正在写的内容做成一个预填好、尚未保存的新模板。
///
/// 正文经白名单清洗：图片、录音、视频、附件等媒体全部去掉（它们指向本机
/// 私有文件，模板会被分享与备份），[droppedMedia] 告诉调用方要不要提示。
/// 日记标题直接作为标题格式与模板名称；标签记名称与颜色；心情、精力照搬；
/// 不带时间胶囊、封面与地点。
({DiaryTemplate template, bool droppedMedia}) diaryTemplateFromEntry({
  required String title,
  required String contentDocJson,
  required List<Tag> tags,
  String? mood,
  double? energy,
}) {
  final document = decodeStoredDiaryBlocks(contentDocJson);
  final droppedMedia = diaryBlocksMedia(document).isNotEmpty;
  final trimmedMood = mood?.trim();
  return (
    template: DiaryTemplate(
      id: '',
      name: normalizeDiaryTemplateLine(title, DiaryTemplate.maxNameLength),
      titlePattern: normalizeDiaryTemplateLine(
        title,
        DiaryTemplate.maxTitleLength,
      ),
      bodyJson: encodeDiaryTemplateBody(document),
      tags: List<DiaryTemplateTagRef>.unmodifiable(<DiaryTemplateTagRef>[
        for (final tag in tags.take(DiaryTemplate.maxTags))
          DiaryTemplateTagRef(name: tag.name, color: tag.color),
      ]),
      mood: trimmedMood == null || trimmedMood.isEmpty ? null : trimmedMood,
      energy: energy?.round().clamp(1, 5),
    ),
    droppedMedia: droppedMedia,
  );
}

/// 打开模板编辑页确认这份预填的模板；去掉了媒体时先提示一次。
Future<void> openSaveAsTemplate(
  BuildContext context, {
  required String title,
  required String contentDocJson,
  required List<Tag> tags,
  String? mood,
  double? energy,
}) {
  final draft = diaryTemplateFromEntry(
    title: title,
    contentDocJson: contentDocJson,
    tags: tags,
    mood: mood,
    energy: energy,
  );
  if (draft.droppedMedia) {
    showStyleEditorMessage(
      context,
      context.l10n.diaryTemplateSaveAsMediaDropped,
    );
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => DiaryTemplateEditorPage(template: draft.template),
    ),
  );
}
