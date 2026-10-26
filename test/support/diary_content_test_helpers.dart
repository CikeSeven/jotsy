import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_to_delta.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:dart_quill_delta/dart_quill_delta.dart' as legacy;
import 'package:flutter/widgets.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart'
    hide Delta;
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_media_block.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/core/services/audio_playback_service.dart';
import 'package:node_diary/core/services/video_export_service.dart';
import 'package:node_diary/core/services/file_open_service.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:video_player/video_player.dart';

export 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart'
    hide Delta;
export 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
export 'package:node_diary/core/database/content_codec.dart';

/// 导入器测试继续按文字、行格式与嵌入断言语义；存储结构由块文档专项测试
/// 验证，避免每个来源的测试都依赖正文 JSON 的外层布局。
List<Map<String, Object?>> diaryContentQuillOps(String content) =>
    diaryBlocksToQuillOps(decodeStoredDiaryBlocks(content));

Widget nativeTestEditor({
  required DiaryEditorController controller,
  FocusNode? focusNode,
  bool shrinkWrap = false,
  AudioPlaybackService? audioPlayer,
  VideoPlayerController Function(String)? videoPlayerFactory,
  VideoExportService videoExportService = const VideoExportService(),
  FileOpenService? fileOpenService,
  void Function(String, ImageViewerHero?)? onImageOpen,
  bool foldLongImages = true,
}) => ProviderScope(
  child: DiaryEditor(
    controller: controller,
    focusNode: focusNode,
    shrinkWrap: shrinkWrap,
    appearance: const DiaryTextAppearance(typography: DiaryTypography()),
    onImageOpen: onImageOpen,
    foldLongImages: foldLongImages,
    blockComponentOverrides: {
      if (audioPlayer != null ||
          videoPlayerFactory != null ||
          fileOpenService != null) ...{
        for (final type in ['audio', 'video', 'attachment'])
          type: DiaryMediaBlockBuilder(
            controller: controller,
            audioPlayer: audioPlayer,
            videoPlayerFactory: videoPlayerFactory,
            videoExportService: videoExportService,
            fileOpenService: fileOpenService ?? const FileOpenService(),
          ),
      },
    },
  ),
);

/// 历史兼容性断言使用的平铺投影；只在测试里保留，应用编辑链路没有此 API。
extension LegacyDocumentProjection on af.Document {
  legacy.Delta toDelta() =>
      legacy.Delta.fromJson(diaryBlocksToQuillOps(toJson()));
  String toPlainText() => toDelta()
      .map((op) => op.data is String ? op.data as String : '\uFFFC')
      .join();
  int get length => toPlainText().length;
}

/// 原有页面业务测试按字符偏移模拟输入；在边界转换一次，然后使用真实原生
/// 事务。文档树、通知、撤销与自动保存均由正式控制器执行。
extension DiaryTestInput on DiaryEditorController {
  TextSelection get flatSelection {
    int offset(af.Position position) {
      var total = 0;
      for (final node in walkDiaryEditorNodes(document)) {
        if (node.path.equals(position.path)) return total + position.offset;
        total += (node.delta?.length ?? 1) + 1;
      }
      return total;
    }

    final value = selection;
    return value == null
        ? const TextSelection.collapsed(offset: -1)
        : TextSelection(
            baseOffset: offset(value.start),
            extentOffset: offset(value.end),
          );
  }

  void updateSelection(TextSelection value, [Object? source]) {
    select(
      af.Selection(
        start: diaryEditorSelectionAtOffset(document, value.baseOffset).start,
        end: diaryEditorSelectionAtOffset(document, value.extentOffset).end,
      ),
    );
  }

  void replaceText(
    int index,
    int length,
    String text,
    TextSelection? after, {
    bool ignoreFocus = false,
  }) {
    final start = diaryEditorSelectionAtOffset(document, index).start;
    final end = diaryEditorSelectionAtOffset(document, index + length).end;
    final nodes = state.getNodesInSelection(
      af.Selection(start: start, end: end),
    );
    final transaction = state.transaction;
    if (nodes.length == 1 && !text.contains('\n')) {
      transaction.replaceText(nodes.single, start.offset, length, text);
    } else {
      // 页面测试的大段输入通常整篇替换，用真实节点替换事务，避免测试再实现
      // 一份编辑器的跨块合并规则。
      final current = document.toPlainText();
      final value = current.replaceRange(index, index + length, text);
      restoreContent(plainTextToContentJson(value));
      if (after != null) updateSelection(after);
      return;
    }
    apply(transaction);
    if (after != null) updateSelection(after);
  }

  void formatText(int index, int length, MapEntry<String, Object?> attribute) {
    updateSelection(
      TextSelection(baseOffset: index, extentOffset: index + length),
    );
    final node = document.nodeAtPath(selection!.start.path)!;
    if (node.delta == null) {
      apply(
        state.transaction
          ..updateNode(node, {attribute.key: attribute.value})
          ..afterSelection = selection,
      );
    } else {
      formatSelection(attribute);
    }
  }
}
