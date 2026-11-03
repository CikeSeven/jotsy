import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/expressive_state_blend.dart';
import '../../widgets/image_viewer_hero.dart';
import '../../widgets/image_viewer_page_counter.dart';
import '../../widgets/swipe_dismiss_viewer.dart';
import '../controllers/diary_day_photos_controller.dart';
import '../controllers/diary_video_player_controller.dart';
import '../widgets/diary_day_photos/diary_day_photo_badges.dart';
import '../widgets/diary_day_photos/diary_day_photo_preview_items.dart';
import '../widgets/diary_day_photos/diary_day_photo_tile.dart';

/// 预览页图片的解码长边：按比例缩小到这个像素数，双击放大后仍够清晰，
/// 一张也只占几十 MB，而不是整张原图（见 [DayPhotoLibrary.previewOf]）。
const int kDiaryDayPhotoPreviewExtent = 3072;

/// 从“这天拍的照片”（提示条或面板）打开预览页，停在第 [initialIndex] 项。
///
/// 与看图页（`openImageViewer`）同样的路由：不透明度为 false（下拉关闭时
/// 能看到下层页面）、整页 `standard` 淡入淡出，减少动画时直接切换。[hero]
/// 为点按时抓取的缩略图画面，所有权随之转交预览页；只用于初始页是图片时。
///
/// 预览页只负责查看与勾选（勾选写进 [controller]，与提示条、面板同一份）。
/// 点“插入”返回 true，由打开者照常执行插入；其余返回 null。
Future<bool?> openDiaryDayPhotoPreview(
  BuildContext context, {
  required DiaryDayPhotosController controller,
  required int initialIndex,
  ImageViewerHero? hero,
}) {
  final photos = controller.photos;
  if (initialIndex < 0 || initialIndex >= photos.length) {
    hero?.dispose();
    return Future<bool?>.value();
  }
  final duration = ExpressiveMotion.duration(
    context,
    ExpressiveMotion.standard,
  );
  // 先让标题 / 正文失去焦点并清掉焦点记录：否则关闭预览时路由把焦点还给
  // 打开前的输入框，键盘会自己弹出来。预览页本身不需要焦点（同正文的全屏
  // 视频）。
  FocusManager.instance.primaryFocus?.unfocus();
  return Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      requestFocus: false,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) =>
          DiaryDayPhotoPreviewPage(
            controller: controller,
            photos: photos,
            initialIndex: initialIndex,
            initialHero: photos[initialIndex].isVideo ? null : hero,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: animation.drive(
              CurveTween(curve: ExpressiveMotion.effects),
            ),
            child: child,
          ),
    ),
  );
}

/// “这天的照片”预览页：左右翻看这天的照片与视频，勾选，插入。
///
/// 职责边界：
/// - 输入：打开时的照片列表 [photos]（冻结：回到前台重新读取也不改变翻页
///   顺序）、共用的 [controller]（勾选、已插入、缩略图与大图来源）；
/// - 输出：勾选经 [DiaryDayPhotosController.toggle] 写回；点“插入”以 true
///   关闭本页；
/// - 不复制文件、不写正文，也不提供分享 / 保存（照片本就在相册里）。
///
/// 交互：图片双击 / 捏合缩放，放大时锁住翻页与下拉关闭；视频点画面或下方
/// 按钮播放，翻页时暂停正在播放的那段；下拉关闭时背景与顶栏、底栏随距离
/// 淡出（与看图页相同的 [SwipeDismissViewer]）。顶栏为返回、页码与勾选圈，
/// 底栏为拍摄时间与“插入”。
class DiaryDayPhotoPreviewPage extends StatefulWidget {
  const DiaryDayPhotoPreviewPage({
    super.key,
    required this.controller,
    required this.photos,
    required this.initialIndex,
    this.initialHero,
  });

  final DiaryDayPhotosController controller;
  final List<DayPhoto> photos;
  final int initialIndex;

  /// 初始页的共享元素；本页负责在销毁时释放其占位画面。
  final ImageViewerHero? initialHero;

  @override
  State<DiaryDayPhotoPreviewPage> createState() =>
      _DiaryDayPhotoPreviewPageState();
}

class _DiaryDayPhotoPreviewPageState extends State<DiaryDayPhotoPreviewPage> {
  late final PageController _pageController;
  late int _activeIndex;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _activeIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // 页面销毁发生在本帧绘制之后，返回飞行的画面此时已从 Overlay 移除。
    widget.initialHero?.dispose();
    super.dispose();
  }

  void _handlePageChanged(int index) {
    // 翻走的视频页可能还挂着（拖动途中两页都在），先停下正在播放的那段。
    unawaited(DiaryVideoPlayerController.pauseActive());
    setState(() {
      _activeIndex = index;
      _zoomed = false;
    });
  }

  void _handleZoomChanged(bool zoomed) {
    if (!mounted || zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
  }

  @override
  Widget build(BuildContext context) {
    final pages = PageView.builder(
      controller: _pageController,
      physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
      itemCount: widget.photos.length,
      onPageChanged: _handlePageChanged,
      itemBuilder: _buildPage,
    );
    return SwipeDismissViewer(
      enabled: !_zoomed,
      onDismiss: () => Navigator.of(context).pop(),
      child: pages,
      builder: (BuildContext context, double chromeOpacity, Widget content) {
        final colorScheme = Theme.of(context).colorScheme;
        final appBar = _buildAppBar(context);
        // 背景、顶栏与底栏随下拉距离淡出（路由不透明度为 false，能看到下层
        // 页面）；每页不各自铺底色，否则底色会跟着画面一起被拖动。
        return ColoredBox(
          color: colorScheme.surface.withValues(alpha: chromeOpacity),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: PreferredSize(
              preferredSize: appBar.preferredSize,
              child: Opacity(opacity: chromeOpacity, child: appBar),
            ),
            body: content,
            bottomNavigationBar: Opacity(
              opacity: chromeOpacity,
              child: _PreviewBottomBar(
                controller: widget.controller,
                photo: widget.photos[_activeIndex],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AppTopBar(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      leading: IconButton(
        tooltip: context.l10n.commonBack,
        onPressed: () => Navigator.of(context).pop(),
        icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
      ),
      title: ImageViewerPageCounter(
        index: _activeIndex,
        total: widget.photos.length,
        style: theme.textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      actions: <Widget>[
        _PreviewCheckButton(
          controller: widget.controller,
          photo: widget.photos[_activeIndex],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    final photo = widget.photos[index];
    final controller = widget.controller;
    if (photo.isVideo) {
      return DiaryDayPhotoPreviewVideo(
        key: ValueKey<String>(photo.id),
        poster: controller.previewOf(
          photo,
          maxExtent: kDiaryDayPhotoPreviewExtent,
        ),
        aspectRatio: photo.width > 0 && photo.height > 0
            ? photo.width / photo.height
            : null,
        loadSource: () => controller.library.videoSourceOf(photo),
      );
    }
    return DiaryDayPhotoPreviewImage(
      key: ValueKey<String>(photo.id),
      image: controller.previewOf(
        photo,
        maxExtent: kDiaryDayPhotoPreviewExtent,
      ),
      hero: index == widget.initialIndex ? widget.initialHero : null,
      onZoomChanged: _handleZoomChanged,
    );
  }
}

/// 顶栏右侧的勾选圈：与格子里的勾选圈同一画法，放大到 24dp；已插入时
/// 显示次要色的勾、不可点。
class _PreviewCheckButton extends StatelessWidget {
  const _PreviewCheckButton({required this.controller, required this.photo});

  final DiaryDayPhotosController controller;
  final DayPhoto photo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final inserted = controller.isInserted(photo);
        final selected = controller.isSelected(photo);
        final label = inserted
            ? l10n.diaryDayPhotosInserted
            : (selected
                  ? l10n.diaryDayPhotosDeselect
                  : l10n.diaryDayPhotosSelect);
        return Semantics(
          checked: selected || inserted,
          child: IconButton(
            tooltip: label,
            onPressed: inserted ? null : () => controller.toggle(photo),
            icon: ExpressiveStateBlend(
              active: selected,
              builder: (BuildContext context, double t, Widget? child) =>
                  DiaryDayPhotoCheckBadge(
                    t: t,
                    inserted: inserted,
                    size: 24,
                    idleBorder: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        );
      },
    );
  }
}

/// 底栏：当前这一项的拍摄时间（视频另带时长）与“插入”（带已选数量，没有
/// 勾选时停用）。
class _PreviewBottomBar extends StatelessWidget {
  const _PreviewBottomBar({required this.controller, required this.photo});

  final DiaryDayPhotosController controller;
  final DayPhoto photo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final time = DateFormat.Hm(l10n.localeName).format(photo.takenAt);
    final info = photo.isVideo
        ? '$time · ${dayPhotoDurationLabel(photo.duration)}'
        : time;
    return ColoredBox(
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: ListenableBuilder(
            listenable: controller,
            builder: (BuildContext context, _) {
              final hasSelection = controller.selectedCount > 0;
              return Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      info,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: hasSelection
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    child: Text(
                      hasSelection
                          ? dayPhotosInsertCountLabel(l10n, controller)
                          : l10n.diaryDayPhotosInsert,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
