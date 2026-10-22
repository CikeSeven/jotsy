import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../../../core/database/audio_embed_codec.dart';
import '../../../../core/database/file_embed_codec.dart';
import '../../../../core/services/audio_playback_service.dart';
import '../../../../core/services/video_export_service.dart';
import '../../../../core/services/file_open_service.dart';
import 'package:video_player/video_player.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../diary_attachment_tile.dart';
import '../diary_audio_player.dart';
import '../diary_embedded_image.dart' show DiaryEmbeddedImage;
import '../diary_playback_interaction_guard.dart';
import '../diary_video_player.dart';
import '../../models/diary_image_embed_data.dart';
import '../../controllers/diary_editor_controller.dart';

/// 媒体保留原生块选区，播放器内部仍接管自己的点按；文字路径不参与选区。
class DiaryMediaBlockBuilder extends af.BlockComponentBuilder {
  DiaryMediaBlockBuilder({
    required this.controller,
    this.onImageOpen,
    this.onImageMenu,
    this.foldLongImages = true,
    this.audioPlayer,
    this.videoPlayerFactory,
    this.videoExportService = const VideoExportService(),
    this.fileOpenService = const FileOpenService(),
  });
  final DiaryEditorController controller;
  final void Function(String source, ImageViewerHero? hero)? onImageOpen;
  final void Function(BuildContext context, af.Node node)? onImageMenu;
  final bool foldLongImages;
  final AudioPlaybackService? audioPlayer;
  final VideoPlayerController Function(String)? videoPlayerFactory;
  final VideoExportService videoExportService;
  final FileOpenService fileOpenService;
  @override
  af.BlockComponentValidate get validate =>
      (_) => true;
  @override
  af.BlockComponentWidget build(af.BlockComponentContext context) =>
      _DiaryMediaBlock(
        key: context.node.key,
        node: context.node,
        controller: controller,
        onImageOpen: onImageOpen,
        onImageMenu: onImageMenu,
        foldLongImages: foldLongImages,
        audioPlayer: audioPlayer,
        videoPlayerFactory: videoPlayerFactory,
        videoExportService: videoExportService,
        fileOpenService: fileOpenService,
      );
}

class _DiaryMediaBlock extends af.BlockComponentStatefulWidget {
  const _DiaryMediaBlock({
    super.key,
    required super.node,
    required this.controller,
    this.onImageOpen,
    this.onImageMenu,
    required this.foldLongImages,
    this.audioPlayer,
    this.videoPlayerFactory,
    required this.videoExportService,
    required this.fileOpenService,
  }) : super(configuration: const af.BlockComponentConfiguration());
  final DiaryEditorController controller;
  final void Function(String source, ImageViewerHero? hero)? onImageOpen;
  final void Function(BuildContext context, af.Node node)? onImageMenu;
  final bool foldLongImages;
  final AudioPlaybackService? audioPlayer;
  final VideoPlayerController Function(String)? videoPlayerFactory;
  final VideoExportService videoExportService;
  final FileOpenService fileOpenService;
  @override
  State<_DiaryMediaBlock> createState() => _DiaryMediaBlockState();
}

class _DiaryMediaBlockState extends State<_DiaryMediaBlock>
    with af.SelectableMixin {
  af.Node get node => widget.node;
  RenderBox? get box => context.findRenderObject() as RenderBox?;
  @override
  Widget build(BuildContext context) {
    final data = node.attributes;
    Widget child;
    switch (node.type) {
      case 'image':
        final source = data['url'];
        if (source is! String || source.isEmpty) return const SizedBox.shrink();
        final tag = widget.onImageOpen == null
            ? null
            : ImageViewerHeroTag('diary_block', node.id);
        child = Builder(
          builder: (imageContext) => GestureDetector(
            onTap: () {
              final open = widget.onImageOpen;
              if (open != null) {
                open(
                  source,
                  tag == null ? null : _captureImageHero(imageContext, tag),
                );
              } else {
                widget.onImageMenu?.call(imageContext, node);
              }
            },
            child: DiaryEmbeddedImage(
              source: source,
              heroTag: tag,
              foldLongImages: widget.foldLongImages,
              bounds: diaryImageEmbedBounds(node),
            ),
          ),
        );
      case 'audio':
        final audio = DiaryAudioAttachment.tryDecode(data);
        if (audio == null) return Text(context.l10n.recordingPlaybackFailed);
        child = DiaryAudioPlayer(
          key: ValueKey(audio.path),
          recording: audio,
          player: widget.audioPlayer,
          onRename: widget.controller.readOnly
              ? null
              : (name) {
                  final transaction = widget.controller.state.transaction
                    ..updateNode(node, {'name': name.trim()})
                    ..afterSelection = widget.controller.selection;
                  widget.controller.apply(transaction, updateSelection: false);
                },
        );
      case 'video':
        final video = DiaryFileAttachment.tryDecode(data);
        if (video == null) return Text(context.l10n.videoPlaybackFailed);
        child = DiaryVideoPlayer(
          key: ValueKey(video.path),
          video: video,
          player: widget.videoPlayerFactory?.call(video.path),
          exportService: widget.videoExportService,
        );
      case 'attachment':
        final file = DiaryFileAttachment.tryDecode(data);
        if (file == null) return Text(context.l10n.attachmentFileMissing);
        child = DiaryAttachmentTile(
          key: ValueKey(file.path),
          attachment: file,
          openService: widget.fileOpenService,
        );
      default:
        // 未识别的旧嵌入仍原样保存，提供一个可选中、可删除的占位。
        child = Text(
          context.l10n.diaryEditorUnsupportedBlock,
          style: Theme.of(context).textTheme.bodySmall,
        );
    }
    final state = widget.controller.state;
    return af.BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: state.selectionNotifier,
      remoteSelection: state.remoteSelections,
      blockColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      supportTypes: const [
        af.BlockSelectionType.block,
        af.BlockSelectionType.selection,
        af.BlockSelectionType.cursor,
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Align(
          alignment: switch (data['align']) {
            'center' => Alignment.center,
            'right' => Alignment.centerRight,
            _ => AlignmentDirectional.centerStart,
          },
          heightFactor: 1,
          child: node.type == 'video'
              ? child
              : DiaryPlaybackInteractionGuard(child: child),
        ),
      ),
    );
  }

  @override
  af.Position start() => af.Position(path: node.path);
  @override
  af.Position end() => af.Position(path: node.path, offset: 1);
  @override
  af.Position getPositionInOffset(Offset offset) => end();
  @override
  bool get shouldCursorBlink => false;
  @override
  af.CursorStyle get cursorStyle => af.CursorStyle.cover;
  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) =>
      Offset.zero & (box?.size ?? Size.zero);
  @override
  Rect? getCursorRectInPosition(
    af.Position position, {
    bool shiftWithBaseOffset = false,
  }) => getBlockRect();
  @override
  List<Rect> getRectsInSelection(
    af.Selection selection, {
    bool shiftWithBaseOffset = false,
  }) => [getBlockRect()];
  @override
  af.Selection getSelectionInRange(Offset start, Offset end) =>
      af.Selection.single(path: node.path, startOffset: 0, endOffset: 1);
  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      box?.localToGlobal(offset) ?? offset;
  @override
  TextDirection textDirection() => TextDirection.ltr;
}

ImageViewerHero? _captureImageHero(BuildContext context, Object tag) {
  var present = false;
  void visit(Element element) {
    if (element.widget case Hero hero when hero.tag == tag) present = true;
    if (!present) element.visitChildElements(visit);
  }

  context.visitChildElements(visit);
  return present ? ImageViewerHero.capture(context, tag: tag) : null;
}
