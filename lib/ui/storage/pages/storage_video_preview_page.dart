import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/file_open_service.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../diaries/controllers/diary_video_player_controller.dart';
import '../../diaries/widgets/diary_image_source.dart';
import '../../diaries/widgets/diary_video_controls.dart';
import '../../diaries/widgets/diary_video_surface.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/expressive_image_frame.dart';
import '../../widgets/long_image/long_image_policy.dart';
import '../../widgets/width_layout_builder.dart';
import '../providers/storage_providers.dart';
import '../viewmodels/storage_labels.dart';
import '../viewmodels/storage_media_view.dart';

/// 存储管理里的视频预览页（只在能内嵌播放视频的平台，
/// `AppPlatform.supportsInlineVideo`；其余平台仍交给系统应用打开）。
///
/// - 播放：与正文视频同一个控制器（`DiaryVideoPlayerController`，切到后台
///   暂停、同一时间只放一个）与画面（`DiaryVideoSurface`，点按播放 / 暂停），
///   下方为与“这天的照片”预览页共用的播放按钮与进度条；就绪后自动开始播放；
/// - 就绪前先显示缩略图帧（与列表同一张缓存），读取超过 300ms 才出现等待
///   指示；放不了时居中说明，并可经顶栏交给其他应用打开；
/// - 底部一行写来源、大小与规格。只负责查看，压缩与删除仍在详情面板。
class StorageVideoPreviewPage extends ConsumerStatefulWidget {
  const StorageVideoPreviewPage({super.key, required this.item, this.player});

  final StorageMediaItemView item;

  /// 测试注入的原生播放器；为 null 时按文件路径创建。
  final VideoPlayerController? player;

  @override
  ConsumerState<StorageVideoPreviewPage> createState() =>
      _StorageVideoPreviewPageState();
}

class _StorageVideoPreviewPageState
    extends ConsumerState<StorageVideoPreviewPage> {
  late final DiaryVideoPlayerController _player = DiaryVideoPlayerController(
    source: widget.item.entry.path,
    player: widget.player,
  );
  late final Future<String?> _poster = ref
      .read(storageMediaServiceProvider)
      .videoThumbnail(widget.item.entry);

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  /// 打开预览就是为了看：就绪后直接开始播放。
  Future<void> _start() async {
    await _player.initialize();
    if (!mounted || _player.hasFailed || _player.isPlaying) return;
    await _player.toggle();
  }

  Future<void> _openExternally() async {
    await _player.pause();
    await const FileOpenService().open(widget.item.entry.path);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = widget.item;
    return AppPageBackground(
      area: AppBackgroundArea.preview,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            title: Text(
              storageMediaTitle(l10n, item.entry, masked: false),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: l10n.storageMgmtOpenExternally,
                onPressed: () => unawaited(_openExternally()),
                icon: const FaIcon(
                  FontAwesomeIcons.arrowUpRightFromSquare,
                  size: 16,
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: AnimatedBuilder(
              animation: _player,
              builder: (BuildContext context, _) {
                final failed = _player.hasFailed;
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          // 就绪前的缩略图帧；就绪后画面盖在它上面。
                          if (_player.isLoading || failed)
                            _Poster(poster: _poster),
                          if (!failed) DiaryVideoSurface(controller: _player),
                          if (failed)
                            Center(
                              child: _Unavailable(
                                message: l10n.videoPlaybackFailed,
                              ),
                            ),
                        ],
                      ),
                    ),
                    DiaryVideoPlaybackBar(player: failed ? null : _player),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.l,
                        0,
                        AppSpacing.l,
                        AppSpacing.m,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              storageMediaDetails(l10n, item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.m),
                          Text(
                            l10n.formatByteSize(item.entry.bytes),
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.poster});

  final Future<String?> poster;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: poster,
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        final path = snapshot.data;
        if (path == null) return const SizedBox.shrink();
        return WidthLayoutBuilder(
          builder: (BuildContext context, double width) => Center(
            child: Image(
              image: boundedImageProvider(
                diaryImageProvider(path),
                width: (width * MediaQuery.devicePixelRatioOf(context)).round(),
              ),
              fit: BoxFit.contain,
              frameBuilder: expressiveImageFrameBuilder,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSpacing.l),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FaIcon(FontAwesomeIcons.film, size: 16, color: scheme.onSurface),
            const SizedBox(width: AppSpacing.s),
            Flexible(child: Text(message, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}
