import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:node_diary/ui/diaries/widgets/diary_attachment_embed_builder.dart';
import 'package:node_diary/ui/diaries/widgets/diary_audio_embed_builder.dart';
import 'package:node_diary/ui/diaries/widgets/diary_image_embed_builder.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_embed_builder.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';

// 编辑页悬浮工具栏（常驻 + 「更多」面板）与正文渲染器的统一入口。
export '../models/diary_toolbar_layout.dart';
export '../models/diary_toolbar_preferences.dart';
export '../models/diary_toolbar_time_format.dart';
export 'diary_floating_toolbar.dart';
export 'diary_toolbar_panel_reserve.dart';

/// 编辑、发布预览和阅读页共用全部 embed；图片点按菜单见 `showDiaryImageOptions`。
/// [onImageOpen]：只读正文里点按图片时调用，第二个参数是从图片画面抓取的
/// 看图页飞入信息（减少动画或图片未解码时为 null）。
List<quill.EmbedBuilder> buildDiaryQuillEmbedBuilders({
  void Function(String imageSource, ImageViewerHero? hero)? onImageOpen,
}) {
  return [
    if (kIsWeb)
      ...FlutterQuillEmbeds.defaultEditorBuilders()
    else ...[
      // 菜单里删除图片只移出正文，不删文件：撤销或放弃修改后原日记还要用，
      // 文件由 DiaryMediaCleanupService 按引用回收。
      DiaryImageEmbedBuilder(onImageOpen: onImageOpen),
      const DiaryVideoEmbedBuilder(),
    ],
    const DiaryAudioEmbedBuilder(),
    const DiaryAttachmentEmbedBuilder(),
    const DiaryAttachmentEmbedBuilder(embedType: 'file'),
  ];
}
