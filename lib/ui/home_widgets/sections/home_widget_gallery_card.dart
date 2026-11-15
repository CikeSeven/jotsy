import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/services/home_widgets/home_widget_kind.dart';
import '../../../core/services/home_widgets/home_widget_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../models/home_widget_cell_size.dart';
import '../viewmodels/home_widget_native_config.dart';
import '../widgets/home_widget_kind_labels.dart';
import '../widgets/home_widget_native_context.dart';
import '../widgets/home_widget_preview.dart';

/// 组件库里的一张卡片：上半是一块“桌面”，放着按默认配置、默认尺寸画出来的
/// 真实小组件；下半是名字、一句说明与可用的尺寸。点按进工作室设计一个新的。
///
/// 卡片外观与日记卡片同一层级（`ExpressiveSurfaces` 的卡片色与描边、
/// [AppRadii.card] 圆角）；桌面块用容器色，与小组件自己的底色拉开。
class HomeWidgetGalleryCard extends ConsumerWidget {
  const HomeWidgetGalleryCard({
    super.key,
    required this.kind,
    required this.onTap,
  });

  final HomeWidgetKind kind;
  final VoidCallback onTap;

  /// 桌面块的高度：4×2 的预览按比例缩进来，2×2 原样放下。
  static const double _deskHeight = 196;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sizes = HomeWidgetCellSize.sizesOf(kind);
    final nativeConfig = homeWidgetNativeConfig(
      HomeWidgetInstance.defaultsFor(kind),
      watchHomeWidgetNativeContext(ref, l10n),
    );
    return Material(
      color: ExpressiveSurfaces.cardColor(scheme),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: ExpressiveSurfaces.cardBorderSide(scheme),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                height: _deskHeight,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadii.card - 12),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: HomeWidgetPreview(
                      kind: kind,
                      nativeConfig: nativeConfig,
                      size: sizes.first,
                      dark: theme.brightness == Brightness.dark,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            homeWidgetKindName(l10n, kind),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            homeWidgetKindDescription(l10n, kind),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              for (final size in sizes) _SizeTag(size: size),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FaIcon(
                      FontAwesomeIcons.angleRight,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 尺寸小标签（格数，不翻译）。
class _SizeTag extends StatelessWidget {
  const _SizeTag({required this.size});

  final HomeWidgetCellSize size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          size.label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
