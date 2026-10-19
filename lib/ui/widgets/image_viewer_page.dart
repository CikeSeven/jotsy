import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_share_target.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/action_loading_overlay.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/delayed_loading_gate.dart';
import 'package:node_diary/ui/widgets/image_viewer_actions_sheet.dart';
import 'package:node_diary/ui/widgets/image_viewer_export_controller.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:node_diary/ui/widgets/image_viewer_image_page.dart';
import 'package:node_diary/ui/widgets/image_viewer_page_counter.dart';
import 'package:node_diary/ui/widgets/swipe_dismiss_viewer.dart';

/// 通用图片查看项。
class ImageViewerItem {
  const ImageViewerItem({required this.source, this.diaryId});

  final String source;

  /// 图片所在日记的业务 id；与 [openImageViewer] 的 `onOpenDiary` 同时给出时，
  /// 长按面板才有“打开日记”。
  final String? diaryId;
}

/// 看图页长按“打开日记”的处理：调用时看图页仍在路由栈上，入口把预览页叠在
/// 它之上，返回时回到刚才那张图。
typedef ImageViewerOpenDiary = void Function(String diaryId);

/// 打开看图页。
///
/// 专用路由：不透明度为 false（下拉关闭时能看到下层页面）、整页淡入淡出，时长
/// 走 standard，减少动画时直接切换。[hero] 描述初始页的共享元素飞入（见
/// [ImageViewerHero.capture]），所有权随之转交看图页；为 null 时只做淡入。
/// [onOpenDiary] 只由“日记不在下层”的入口（如探索页媒体画廊）提供：从预览页
/// 或编辑页看图时，图片所在的日记就在下面，不需要再打开一次。
Future<void> openImageViewer(
  BuildContext context, {
  required List<ImageViewerItem> items,
  required int initialIndex,
  ImageViewerHero? hero,
  ImageViewerOpenDiary? onOpenDiary,
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
        onOpenDiary: onOpenDiary,
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
/// - 负责“全屏浏览 + 左右切图 + 双击/捏合缩放 + 下拉关闭 + 索引展示 + 长按
///   操作面板”；当前页放大时禁用左右翻页与下拉关闭，拖动只用于平移查看细节；
///   长图按屏宽从顶部开始竖向滚动（见 [ImageViewerImagePage]），该页的竖向
///   拖动留给滚动，不响应下拉关闭；
/// - 长按图片或点顶栏 ⋮ 弹出同一个操作面板（[showImageViewerActionsSheet]）：
///   分享到已安装的应用或“更多应用”、保存到相册，图片带日记 id 且入口给了
///   [onOpenDiary] 时还能打开所在日记；顶栏只有返回、页码与 ⋮，不再单独放
///   保存 / 分享按钮；
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
    this.onOpenDiary,
  });

  final List<ImageViewerItem> items;
  final int initialIndex;

  /// 初始页的共享元素；本页负责在销毁时释放其占位画面。
  final ImageViewerHero? initialHero;

  /// 长按面板“打开日记”的处理；null 时面板不显示这一项。
  final ImageViewerOpenDiary? onOpenDiary;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController _pageController;
  late int _activeIndex;

  /// 规范化后的初始页，共享元素只属于这一页。
  late final int _initialPage;

  final ImageViewerExportController _export = ImageViewerExportController();

  /// 已安装分享应用的检测：打开看图页时就开始，长按时通常早已完成；放到长按
  /// 时才查，面板会先只有“更多应用”再跳出其他应用。
  late final Future<Set<DiaryShareTarget>> _installedTargets;

  /// [_installedTargets] 完成后的结果，作为面板首帧的数据。
  Set<DiaryShareTarget>? _resolvedTargets;

  /// 当前页是否处于放大态；放大时 PageView 不再响应水平拖动。
  bool _pageZoomed = false;

  /// 处于长图模式的页：竖向拖动用于滚动，停在这些页时关闭下拉关闭。
  final Set<int> _tallPages = <int>{};

  @override
  void initState() {
    super.initState();
    _activeIndex = _normalizeInitialIndex();
    _initialPage = _activeIndex;
    _pageController = PageController(initialPage: _activeIndex);
    _export.addListener(_handleExportChanged);
    _installedTargets = _export.availableTargets();
    // 检测失败时面板经 FutureBuilder 退回只有“更多应用”，这里不必处理。
    unawaited(
      _installedTargets.then<void>(
        (Set<DiaryShareTarget> targets) => _resolvedTargets = targets,
        onError: (Object _) {},
      ),
    );
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
      // ⋮ 与长按图片打开同一个面板：长按不易发现，读屏用户也更习惯点按钮。
      actions: hasImages
          ? <Widget>[
              IconButton(
                tooltip: l10n.imageViewerMoreActions,
                onPressed: _export.isBusy
                    ? null
                    : () => unawaited(_openActions(_activeIndex)),
                icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
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
      enabled: hasImages && !_pageZoomed && !_tallPages.contains(_activeIndex),
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
                // 本地图片的保存与分享通常瞬间完成，遮罩延迟出现免得闪一下；
                // 拦截点击仍随忙碌态立即生效。
                Positioned.fill(
                  child: ActionLoadingOverlay(
                    visible: _export.isBusy,
                    label: _export.busyLabel,
                    revealDelay: DelayedLoadingGate.defaultDelay,
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

  void _handleExportChanged() => setState(() {});

  /// 长按图片：先给长按反馈，再打开与顶栏 ⋮ 相同的操作面板。忙碌时（上一次
  /// 保存 / 分享未完成）忽略长按，也不震动。
  void _handleLongPress(int index) {
    if (_export.isBusy) {
      return;
    }
    // Android 由 Feedback.forLongPress 给出系统长按震动；iOS 上它不震，补一次。
    unawaited(Feedback.forLongPress(context));
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      unawaited(HapticFeedback.mediumImpact());
    }
    unawaited(_openActions(index));
  }

  /// 打开操作面板（长按图片与顶栏 ⋮ 共用），面板关闭后在这里执行所选动作。
  ///
  /// 面板期间页面不会翻页（模态遮罩拦住了手势），所以执行时仍对应打开面板
  /// 时的那一张；忙碌时直接忽略。
  Future<void> _openActions(int index) async {
    if (_export.isBusy || index < 0 || index >= widget.items.length) {
      return;
    }
    final item = widget.items[index];
    final diaryId = item.diaryId;
    final onOpenDiary = widget.onOpenDiary;
    final action = await showImageViewerActionsSheet(
      context,
      installedTargets: _installedTargets,
      initialTargets: _resolvedTargets,
      canOpenDiary: diaryId != null && onOpenDiary != null,
    );
    if (!mounted || action == null) {
      return;
    }
    final l10n = context.l10n;
    switch (action) {
      case ImageViewerShareAction(:final target):
        _showHintIfAny(await _export.shareTo(target, item.source, l10n));
      case ImageViewerSaveAction():
        _showHintIfAny(await _export.saveToGallery(item.source, l10n));
      case ImageViewerOpenDiaryAction():
        onOpenDiary?.call(diaryId!);
    }
  }

  void _handleZoomChanged(bool zoomed) {
    if (zoomed == _pageZoomed || !mounted) {
      return;
    }
    setState(() => _pageZoomed = zoomed);
  }

  /// 统一提示：复用 Home 提示追踪能力，scope 缺失时自动降级为普通 SnackBar。
  void _showHintIfAny(String? message) {
    if (message == null || !mounted) {
      return;
    }
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleTallChanged(int index, bool tall) {
    if (!mounted || _tallPages.contains(index) == tall) {
      return;
    }
    setState(() {
      if (tall) {
        _tallPages.add(index);
      } else {
        _tallPages.remove(index);
      }
    });
  }

  Widget _buildImagePage(int index) {
    // 长按与双击、捏合、拖动同在手势竞技场：手指一动就交给翻页 / 平移 /
    // 下拉关闭，只有按住不动到长按时限才弹出面板。
    return Semantics(
      onLongPressHint: context.l10n.imageViewerMoreActions,
      child: GestureDetector(
        onLongPress: () => _handleLongPress(index),
        child: ImageViewerImagePage(
          source: widget.items[index].source,
          hero: index == _initialPage ? widget.initialHero : null,
          onZoomChanged: _handleZoomChanged,
          onTallChanged: (tall) => _handleTallChanged(index, tall),
        ),
      ),
    );
  }
}
