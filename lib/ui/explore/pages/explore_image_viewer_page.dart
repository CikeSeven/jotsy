import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:node_diary/core/services/image_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../models/explore_view_data.dart';

/// 探索页图片查看器。
///
/// 职责边界：
/// - 负责“全屏浏览 + 左右切图 + 索引展示 + 保存到相册 / 分享当前图片”；
/// - 不承担数据加载与去重逻辑，数据由调用方透传；
/// - 渲染层同时兼容本地图片路径与网络图片 URL；
/// - 保存/分享委托给 [ImageExportService]，本页只负责触发、loading 态与结果提示。
class ExploreImageViewerPage extends StatefulWidget {
  const ExploreImageViewerPage({
    super.key,
    required this.mediaItems,
    required this.initialIndex,
  });

  final List<ExploreMediaItem> mediaItems;
  final int initialIndex;

  @override
  State<ExploreImageViewerPage> createState() => _ExploreImageViewerPageState();
}

class _ExploreImageViewerPageState extends State<ExploreImageViewerPage> {
  late final PageController _pageController;
  late int _activeIndex;

  static const ImageExportService _exportService = ImageExportService();

  /// 当前是否有保存/分享任务在执行。
  ///
  /// 作用：
  /// - 阻止重复点击导致并发保存/分享；
  /// - 驱动顶栏按钮禁用态与底部 loading 遮罩显隐。
  bool _isBusy = false;

  /// loading 遮罩文案（保存中 / 分享准备中），仅在 [_isBusy] 时展示。
  String _busyLabel = '';

  @override
  void initState() {
    super.initState();
    _activeIndex = _normalizeInitialIndex();
    _pageController = PageController(initialPage: _activeIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final total = widget.mediaItems.length;
    final hasImages = total > 0;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppTopBar(
        backgroundColor: Colors.black.withValues(alpha: 0.88),
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        title: Text(
          total == 0 ? l10n.autoT0052 : '${_activeIndex + 1} / $total',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions:
            hasImages
                ? <Widget>[
                  // 保存到相册：忙碌时禁用，避免并发触发。
                  IconButton(
                    tooltip: l10n.imageViewerSaveToGallery,
                    onPressed: _isBusy ? null : _handleSaveToGallery,
                    icon: const FaIcon(
                      FontAwesomeIcons.download,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  // 分享当前图片。
                  IconButton(
                    tooltip: l10n.commonShare,
                    onPressed: _isBusy ? null : _handleShare,
                    icon: const FaIcon(
                      FontAwesomeIcons.shareNodes,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                ]
                : null,
      ),
      body: Stack(
        children: <Widget>[
          if (!hasImages)
            Center(
              child: Text(
                l10n.autoT0053,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            PageView.builder(
              controller: _pageController,
              itemCount: total,
              onPageChanged: (index) {
                setState(() {
                  _activeIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final source = widget.mediaItems[index].source;
                return _buildImagePage(source);
              },
            ),
          if (_isBusy) _buildBusyOverlay(),
        ],
      ),
    );
  }

  int _normalizeInitialIndex() {
    final max = widget.mediaItems.length - 1;
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
    if (_activeIndex < 0 || _activeIndex >= widget.mediaItems.length) {
      return null;
    }
    return widget.mediaItems[_activeIndex].source;
  }

  /// 处理“保存到相册”：进入忙碌态 → 调用服务 → 按结果提示。
  Future<void> _handleSaveToGallery() async {
    final source = _currentSource();
    if (source == null || _isBusy) {
      return;
    }
    final l10n = context.l10n;
    _enterBusy(l10n.imageViewerSaving);
    try {
      await _exportService.saveToGallery(source);
      if (!mounted) {
        return;
      }
      _showHint(l10n.imageViewerSaveSuccess);
    } on ImageExportException catch (error) {
      if (!mounted) {
        return;
      }
      _showHint(_mapSaveError(l10n, error));
    } finally {
      if (mounted) {
        _exitBusy();
      }
    }
  }

  /// 处理“分享当前图片”：进入忙碌态 → 调用服务 → 失败提示。
  Future<void> _handleShare() async {
    final source = _currentSource();
    if (source == null || _isBusy) {
      return;
    }
    final l10n = context.l10n;
    _enterBusy(l10n.imageViewerSharing);
    try {
      await _exportService.shareImage(source);
    } on ImageExportException catch (error) {
      if (!mounted) {
        return;
      }
      _showHint(_mapShareError(l10n, error));
    } finally {
      if (mounted) {
        _exitBusy();
      }
    }
  }

  /// 把保存失败的领域异常映射为本地化提示。
  String _mapSaveError(AppLocalizations l10n, ImageExportException error) {
    switch (error.type) {
      case ImageExportErrorType.permissionDenied:
        return l10n.imageViewerGalleryPermissionDenied;
      case ImageExportErrorType.downloadFailed:
        return l10n.imageViewerDownloadFailed;
      case ImageExportErrorType.invalidSource:
      case ImageExportErrorType.unknown:
        return l10n.imageViewerSaveFailed(error.message);
    }
  }

  /// 把分享失败的领域异常映射为本地化提示。
  String _mapShareError(AppLocalizations l10n, ImageExportException error) {
    switch (error.type) {
      case ImageExportErrorType.downloadFailed:
        return l10n.imageViewerDownloadFailed;
      case ImageExportErrorType.invalidSource:
      case ImageExportErrorType.permissionDenied:
      case ImageExportErrorType.unknown:
        return l10n.imageViewerShareFailed(error.message);
    }
  }

  void _enterBusy(String label) {
    setState(() {
      _isBusy = true;
      _busyLabel = label;
    });
  }

  void _exitBusy() {
    setState(() {
      _isBusy = false;
      _busyLabel = '';
    });
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

  /// 保存/分享进行中的半透明遮罩，沿用 loading_indicator_m3e 统一加载表现。
  Widget _buildBusyOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const LoadingIndicatorM3E(
                variant: LoadingIndicatorM3EVariant.contained,
                constraints: BoxConstraints.tightFor(width: 64, height: 64),
              ),
              if (_busyLabel.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _busyLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePage(String source) {
    final uri = Uri.tryParse(source);
    final isRemote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    final imageWidget =
        isRemote
            ? Image.network(
              source,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                final totalBytes = loadingProgress.expectedTotalBytes;
                final value =
                    totalBytes == null
                        ? null
                        : loadingProgress.cumulativeBytesLoaded / totalBytes;
                return Center(child: CircularProgressIndicator(value: value));
              },
              errorBuilder: (_, __, ___) => const _ImageFallback(),
            )
            : Image.file(
              File(source),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const _ImageFallback(),
            );

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(child: imageWidget),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: FaIcon(FontAwesomeIcons.image, size: 28, color: Colors.white54),
    );
  }
}
