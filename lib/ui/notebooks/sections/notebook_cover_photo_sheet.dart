import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SliverConstraints;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/long_image/long_image_cover_alignment.dart';
import '../../widgets/long_image/long_image_policy.dart';
import '../models/notebook_scope_resolver.dart';
import '../providers/notebook_cover_photos_provider.dart';
import '../providers/notebook_providers.dart';

/// 打开“从日记中选封面”面板：网格列出 [notebookId] 这本（父本连同子本）
/// 日记里用到的图片，点一张返回它的路径；下滑或点遮罩关闭返回 null。
///
/// 面板只负责挑选，拷贝成封面由调用方（编辑页的封面流程）执行。
Future<String?> showNotebookCoverPhotoSheet(
  BuildContext context, {
  required String notebookId,
}) {
  return showAppModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      builder: (BuildContext context, ScrollController scrollController) =>
          NotebookCoverPhotoPicker(
            notebookId: notebookId,
            scrollController: scrollController,
          ),
    ),
  );
}

/// 面板内容：标题、说明与图片网格（加载中 / 空状态各占剩余高度）。
///
/// 范围取数据库里已保存的这本（[notebookProvider]），不是编辑页里还没保存
/// 的草稿：选图看的是本子里现有的日记。本子已被删除时按没有图片处理。
class NotebookCoverPhotoPicker extends ConsumerWidget {
  const NotebookCoverPhotoPicker({
    super.key,
    required this.notebookId,
    this.scrollController,
  });

  final String notebookId;
  final ScrollController? scrollController;

  /// 缩略图的目标边长：按可用宽度算列数，至少 3 列。
  static const double _targetCell = 112;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final notebookAsync = ref.watch(notebookProvider(notebookId));
    final tree = ref.watch(notebookTreeProvider);
    final notebook = notebookAsync.value;
    final List<String>? photos;
    if (notebookAsync.isLoading && notebook == null) {
      photos = null;
    } else if (notebook == null) {
      photos = const <String>[];
    } else {
      photos = ref
          .watch(
            notebookCoverPhotosProvider(
              notebookStatsScope(notebook, tree: tree),
            ),
          )
          .value;
    }
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.l,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.notebookCoverPhotosTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.notebookCoverPhotosSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    final Widget content;
    if (photos == null) {
      content = const SliverFillRemaining(
        hasScrollBody: false,
        child: DelayedLoadingIndicator(),
      );
    } else if (photos.isEmpty) {
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyHint(
          icon: FontAwesomeIcons.images,
          message: l10n.notebookCoverPhotosEmpty,
        ),
      );
    } else {
      final items = photos;
      content = SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        sliver: SliverLayoutBuilder(
          builder: (BuildContext context, SliverConstraints constraints) {
            final columns = math.max(
              3,
              (constraints.crossAxisExtent / _targetCell).floor(),
            );
            return SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: _gap,
                crossAxisSpacing: _gap,
              ),
              itemCount: items.length,
              itemBuilder: (BuildContext context, int index) =>
                  NotebookCoverPhotoTile(
                    path: items[index],
                    label: l10n.notebookCoverPhotoItem(index + 1),
                    onTap: () => Navigator.of(context).pop(items[index]),
                  ),
            );
          },
        ),
      );
    }
    return CustomScrollView(
      controller: scrollController,
      slivers: <Widget>[
        SliverToBoxAdapter(child: header),
        content,
      ],
    );
  }
}

/// 一张缩略图：12dp 圆角、cover 裁切（长图顶部对齐）、首次解码淡入；
/// 读不出来时显示一个图片图标。水波纹叠在图片之上。
class NotebookCoverPhotoTile extends StatelessWidget {
  const NotebookCoverPhotoTile({
    super.key,
    required this.path,
    required this.label,
    required this.onTap,
  });

  final String path;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            LayoutBuilder(
              // 方格里的横图按高度铺满：按边长 1.5 倍解码，避免放大发糊。
              builder: (BuildContext context, BoxConstraints constraints) =>
                  CoverCroppedImage(
                    image: boundedImageProvider(
                      FileImage(File(path)),
                      width: (constraints.maxWidth * dpr * 1.5).round(),
                    ),
                    errorBuilder: (_, _, _) => Center(
                      child: FaIcon(
                        FontAwesomeIcons.image,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
            ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
