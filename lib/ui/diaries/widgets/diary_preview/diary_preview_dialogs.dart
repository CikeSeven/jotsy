import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../../widgets/image_viewer_page.dart';

/// 从预览页打开看图页。
///
/// [sources] 是本篇的全部图片来源（封面在前，可能重复），这里去空、去重后
/// 定位到 [initialSource]；不在列表里时把它放到最前。[hero] 为点按处抓取的
/// 共享元素，所有权随之转交看图页；没有可看的图片时就地释放。
void openDiaryPreviewImages(
  BuildContext context, {
  required List<String> sources,
  required String initialSource,
  ImageViewerHero? hero,
}) {
  final normalizedSources = <String>[];
  final seenSources = <String>{};
  for (final source in sources) {
    final normalized = source.trim();
    if (normalized.isEmpty || !seenSources.add(normalized)) {
      continue;
    }
    normalizedSources.add(normalized);
  }
  final normalizedInitialSource = initialSource.trim();
  if (normalizedInitialSource.isNotEmpty &&
      !seenSources.contains(normalizedInitialSource)) {
    normalizedSources.insert(0, normalizedInitialSource);
  }
  if (normalizedSources.isEmpty) {
    hero?.dispose();
    return;
  }

  final initialIndex = math.max(
    0,
    normalizedSources.indexOf(normalizedInitialSource),
  );
  unawaited(
    openImageViewer(
      context,
      items: normalizedSources
          .map((source) => ImageViewerItem(source: source))
          .toList(growable: false),
      initialIndex: initialIndex,
      hero: hero,
    ),
  );
}

/// 删除确认：左侧灰色“取消”，右侧 error 色“删除”。
Future<bool> confirmDiaryPreviewDelete(BuildContext context) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final colorScheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(l10n.autoT0094),
        content: Text(l10n.autoT0113),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
