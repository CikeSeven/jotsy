import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/ui/diaries/controllers/diary_media_import_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/widgets/diary_attachment_embed_builder.dart';
import 'package:node_diary/ui/diaries/widgets/diary_audio_embed_builder.dart';
import 'package:node_diary/ui/diaries/widgets/diary_image_embed_builder.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_config.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_embed_builder.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';

export '../models/diary_toolbar_preferences.dart';
export '../models/diary_toolbar_time_format.dart';

/// 装配悬浮工具栏与统一正文渲染器，不执行文件选择或存储。
/// 媒体控制器由编辑页持有，系统选择器收起键盘时，工具栏移除不会取消导入。
Widget buildDiaryFloatingToolbar({
  required quill.QuillController controller,
  required List<DiaryToolbarItem> order,
  Set<DiaryToolbarItem> hiddenItems = const <DiaryToolbarItem>{},
  String? currentTimeFormatPattern,
  VoidCallback? onRecordingPressed,
  bool recordingOpen = false,
  DiaryMediaImportController? mediaImportController,
  void Function(DiaryMediaKind)? onMediaPressed,
}) {
  final normalizedOrder = filterEnabledDiaryToolbarOrder(order, hiddenItems);
  if (normalizedOrder.isEmpty) return const SizedBox.shrink();
  return AnimatedBuilder(
    animation: mediaImportController ?? controller,
    builder: (context, _) => LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  for (var i = 0; i < normalizedOrder.length; i++) ...<Widget>[
                    quill.QuillSimpleToolbar(
                      controller: controller,
                      config: buildDiaryToolbarItemConfig(
                        context,
                        normalizedOrder[i],
                        controller,
                        currentTimeFormatPattern: currentTimeFormatPattern,
                        onRecordingPressed: onRecordingPressed,
                        recordingOpen: recordingOpen,
                        onMediaPressed: onMediaPressed,
                        activeMediaKind: mediaImportController?.activeKind,
                        mediaImportBusy: mediaImportController?.isBusy ?? false,
                      ),
                    ),
                    if (i != normalizedOrder.length - 1)
                      const SizedBox(width: 2),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// 编辑、发布预览和阅读页共用全部 embed，保留图片已有的编辑菜单。
/// [onImageOpen]：只读正文里点按图片时调用，第二个参数是从图片画面抓取的
/// 看图页飞入信息（减少动画或图片未解码时为 null）。
List<quill.EmbedBuilder> buildDiaryQuillEmbedBuilders({
  void Function(String imageSource, ImageViewerHero? hero)? onImageOpen,
}) {
  return [
    if (kIsWeb)
      ...FlutterQuillEmbeds.defaultEditorBuilders()
    else ...[
      DiaryImageEmbedBuilder(
        onImageOpen: onImageOpen,
        config: QuillEditorImageEmbedConfig(
          // 上游默认在移动端立即删除被移除图片的文件，撤销或放弃修改后
          // 原日记会坏图；文件改由 DiaryMediaCleanupService 按引用回收。
          onImageRemovedCallback: (_) async {},
        ),
      ),
      const DiaryVideoEmbedBuilder(),
    ],
    const DiaryAudioEmbedBuilder(),
    const DiaryAttachmentEmbedBuilder(),
    const DiaryAttachmentEmbedBuilder(embedType: 'file'),
  ];
}
