import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/action_loading_overlay.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/double_tap_zoom_viewer.dart';
import 'package:node_diary/ui/widgets/image_viewer_export_controller.dart';
import 'package:node_diary/ui/widgets/image_viewer_full_image.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:node_diary/ui/widgets/image_viewer_page_counter.dart';
import 'package:node_diary/ui/widgets/swipe_dismiss_viewer.dart';

/// 通用图片查看项。
class ImageViewerItem {
  const ImageViewerItem({required this.source});

  final String source;
}

/// 打开看图页。
///
/// 专用路由：不透明度为 false（下拉关闭时能看到下层页面）、整页淡入淡出，时长
/// 走 standard，减少动画时直接切换。[hero] 描述初始页的共享元素飞入（见
/// [ImageViewerHero.capture]），所有权随之转交看图页；为 null 时只做淡入。
Future<void> openImageViewer(
  BuildContext context, {
  required List<ImageViewerItem> items,
  required int initialIndex,
  ImageViewerHero? hero,
}) {
  final duration = ExpressiveMotion.duration(
    context,
    ExpressiveMotion.standard,
  );
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => ImageViewerPage(
        items: items,
        initialIndex: initialIndex,
        initialHero: hero,
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

/// 通用图片浏览页。
///
/// 职责边界：
/// - 负责“全屏浏览 + 左右切图 + 双击/捏合缩放 + 下拉关闭 + 索引展示 + 保存到
///   相册 / 分享当前图片”；当前页放大时禁用左右翻页与下拉关闭，拖动只用于平移
///   查看细节；
/// - 初始页可携带共享元素（[initialHero]）：从缩略图/正文图连续展开，返回时
///   飞回原处；翻到其他页后返回只做淡出；
/// - 不承担数据加载、去重或业务归属判断，图片列表由调用方透传；
/// - 渲染层同时兼容本地图片路径与网络图片 URL；
/// - 保存/分享的流程编排在 [ImageViewerExportController]，本页只负责触发、
///   loading 遮罩与结果提示。
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    super.key,
    required this.items,
    required this.initialIndex,
    this.initialHero,
  });

  final List<ImageViewerItem> items;
  final int initialIndex;

  /// 初始页的共享元素；本页负责在销毁时释放其占位画面。
  final ImageViewerHero? initialHero;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController _pageController;
  late int _activeIndex;

  /// 规范化后的初始页，共享元素只属于这一页。
  late final int _initialPage;

  final ImageViewerExportController _export = ImageViewerExportController();

  /// 当前页是否处于放大态；放大时 PageView 不再响应水平拖动。
  bool _pageZoomed = false;

  @override
  void initState() {
    super.initState();
    _activeIndex = _normalizeInitialIndex();
    _initialPage = _activeIndex;
    _pageController = PageController(initialPage: _activeIndex);
    _export.addListener(_handleExportChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _export
      ..removeListener(_handleExportChanged)
      ..dispose();
    // 页面销毁发生在本帧绘制之后，返回飞行的画面此时已从 Overlay 移除。
    widget.initialHero?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final total = widget.items.length;
    final hasImages = total > 0;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final appBar = AppTopBar(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      leading: IconButton(
        tooltip: context.l10n.commonBack,
        onPressed: () => Navigator.of(context).pop(),
        icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
      ),
      title: hasImages
          ? ImageViewerPageCounter(
              index: _activeIndex,
              total: total,
              style: titleStyle,
            )
          : Text(l10n.autoT0052, style: titleStyle),
      centerTitle: true,
      actions: hasImages
          ? <Widget>[
              // 保存到相册：忙碌时禁用，避免并发触发。
              IconButton(
                tooltip: l10n.imageViewerSaveToGallery,
                onPressed: _export.isBusy ? null : _handleSaveToGallery,
                icon: const FaIcon(FontAwesomeIcons.download, size: 18),
              ),
              // 分享当前图片。
              IconButton(
                tooltip: l10n.commonShare,
                onPressed: _export.isBusy ? null : _handleShare,
                icon: const FaIcon(FontAwesomeIcons.shareNodes, size: 18),
              ),
              const SizedBox(width: 4),
            ]
          : null,
    );
    final pages = hasImages
        ? PageView.builder(
            controller: _pageController,
            physics: _pageZoomed ? const NeverScrollableScrollPhysics() : null,
            itemCount: total,
            onPageChanged: (index) {
              setState(() {
                _activeIndex = index;
              });
            },
            itemBuilder: (context, index) => _buildImagePage(index),
          )
        : Center(
            child: Text(
              l10n.autoT0053,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          );

    // 背景、顶栏随下拉距离淡出（路由不透明度为 false，能看到下层页面）；每页
    // 不再各自铺底色，否则底色会跟着图片一起被拖动。
    return SwipeDismissViewer(
      enabled: hasImages && !_pageZoomed,
      onDismiss: () => Navigator.of(context).pop(),
      child: pages,
      builder: (BuildContext context, double chromeOpacity, Widget content) {
        return ColoredBox(
          color: colorScheme.surface.withValues(alpha: chromeOpacity),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: PreferredSize(
              preferredSize: appBar.preferredSize,
              child: Opacity(opacity: chromeOpacity, child: appBar),
            ),
            body: Stack(
              children: <Widget>[
                Positioned.fill(child: content),
                Positioned.fill(
                  child: ActionLoadingOverlay(
                    visible: _export.isBusy,
                    label: _export.busyLabel,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _normalizeInitialIndex() {
    final max = widget.items.length - 1;
    if (max < 0) {
      return 0;
    }
    if (widget.initialIndex < 0) {
      return 0;
    }
    if (widget.initialIndex > max) {
      return max;
    }
    return widget.initialIndex;
  }

  /// 取当前页对应的图片源；越界时返回 null。
  String? _currentSource() {
    if (_activeIndex < 0 || _activeIndex >= widget.items.length) {
      return null;
    }
    return widget.items[_activeIndex].source;
  }

  void _handleExportChanged() => setState(() {});

  /// 保存到相册，按结果提示。
  Future<void> _handleSaveToGallery() async {
    final source = _currentSource();
    if (source == null) {
      return;
    }
    final hint = await _export.saveToGallery(source, context.l10n);
    if (hint != null && mounted) {
      _showHint(hint);
    }
  }

  /// 分享当前图片，失败时提示。
  Future<void> _handleShare() async {
    final source = _currentSource();
    if (source == null) {
      return;
    }
    final hint = await _export.share(source, context.l10n);
    if (hint != null && mounted) {
      _showHint(hint);
    }
  }

  void _handleZoomChanged(bool zoomed) {
    if (zoomed == _pageZoomed || !mounted) {
      return;
    }
    setState(() => _pageZoomed = zoomed);
  }

  /// 统一提示：复用 Home 提示追踪能力，scope 缺失时自动降级为普通 SnackBar。
  void _showHint(String message) {
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
      forceCloseAfter: const Duration(seconds: 2),
    );
  }

  Widget _buildImagePage(int index) {
    final source = widget.items[index].source;
    final hero = index == _initialPage ? widget.initialHero : null;
    if (hero == null) {
      return DoubleTapZoomViewer(
        onZoomChanged: _handleZoomChanged,
        child: Center(
          child: ImageViewerFullImage(
            source: source,
            fit: BoxFit.contain,
            placeholderBehind: false,
          ),
        ),
      );
    }
    // 放大后返回不做飞行（放大的画面飞回缩略图会先猛地缩一大截），只淡出。
    return DoubleTapZoomViewer(
      onZoomChanged: _handleZoomChanged,
      child: HeroMode(
        enabled: !_pageZoomed,
        child: ImageViewerHeroTarget(
          hero: hero,
          fullImage: ImageViewerFullImage(
            source: source,
            fit: BoxFit.cover,
            placeholderBehind: true,
          ),
        ),
      ),
    );
  }
}
