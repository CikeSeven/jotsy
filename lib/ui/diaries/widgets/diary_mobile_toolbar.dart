import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/ui/diaries/controllers/diary_media_import_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/widgets/diary_attachment_embed_builder.dart';
import 'package:node_diary/ui/diaries/widgets/diary_audio_embed_builder.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_config.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_embed_builder.dart';

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
List<quill.EmbedBuilder> buildDiaryQuillEmbedBuilders({
  void Function(String imageSource)? onImageClicked,
}) {
  return [
    if (kIsWeb)
      ...FlutterQuillEmbeds.defaultEditorBuilders()
    else ...[
      ...FlutterQuillEmbeds.editorBuilders(
        imageEmbedConfig: QuillEditorImageEmbedConfig(
          onImageClicked: onImageClicked,
        ),
        videoEmbedConfig: null,
      ),
      const DiaryVideoEmbedBuilder(),
    ],
    const DiaryAudioEmbedBuilder(),
    const DiaryAttachmentEmbedBuilder(),
    const DiaryAttachmentEmbedBuilder(embedType: 'file'),
  ];
}
