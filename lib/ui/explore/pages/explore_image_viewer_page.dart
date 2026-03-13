import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/glass_app_bar.dart';

import '../models/explore_view_data.dart';

/// 探索页图片查看器。
///
/// 职责边界：
/// - 仅负责“全屏浏览 + 左右切图 + 索引展示”；
/// - 不承担数据加载与去重逻辑，数据由调用方透传；
/// - 渲染层同时兼容本地图片路径与网络图片 URL。
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: GlassAppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.88),
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        title: Text(
          total == 0
              ? l10n.autoT0052
              : '${_activeIndex + 1} / $total',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
        centerTitle: true,
      ),
      body: total == 0
          ? Center(
              child: Text(
                l10n.autoT0053,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          : PageView.builder(
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

  Widget _buildImagePage(String source) {
    final uri = Uri.tryParse(source);
    final isRemote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    final imageWidget = isRemote
        ? Image.network(
            source,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              final totalBytes = loadingProgress.expectedTotalBytes;
              final value = totalBytes == null
                  ? null
                  : loadingProgress.cumulativeBytesLoaded / totalBytes;
              return Center(
                child: CircularProgressIndicator(value: value),
              );
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
      child: FaIcon(
        FontAwesomeIcons.image,
        size: 28,
        color: Colors.white54,
      ),
    );
  }
}
