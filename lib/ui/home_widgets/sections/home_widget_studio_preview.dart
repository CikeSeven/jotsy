import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_color_scheme.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/expressive_button_group.dart';
import '../controllers/home_widget_studio_controller.dart';
import '../models/home_widget_cell_size.dart';
import '../viewmodels/home_widget_native_config.dart';
import '../widgets/home_widget_native_context.dart';
import '../widgets/home_widget_preview.dart';

/// 工作室上方的预览区：模拟一块桌面，中间是原生画出来的真实小组件，下方是
/// 尺寸切换；设计新的小组件时再下方是“添加到桌面”，编辑已有的时是“修改会
/// 立即同步到桌面”的说明。
///
/// 桌面底色取应用主题色在预览明暗下的最高层容器色：与小组件的各种底色
/// （实色、色调、浓郁）都拉得开，透明底的小组件也看得清文字。预览放不下
/// 4×4 时整体等比缩小，不裁切。
class HomeWidgetStudioPreview extends ConsumerWidget {
  const HomeWidgetStudioPreview({
    super.key,
    required this.controller,
    required this.bottomPadding,
    this.onAddToHome,
  });

  final HomeWidgetStudioController controller;
  final double bottomPadding;

  /// 设计新的小组件时的“添加到桌面”；编辑已有实例时为 null。
  final VoidCallback? onAddToHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = controller.previewDark ?? theme.brightness == Brightness.dark;
    final seed =
        ref
            .watch(settingsServiceProvider)
            .asData
            ?.value
            .themeSeedColorNotifier
            .value ??
        theme.colorScheme.primary;
    final desk = appColorSchemeFromSeed(
      seed,
      dark ? Brightness.dark : Brightness.light,
    );
    final instance = controller.instance;
    final nativeConfig = homeWidgetNativeConfig(
      instance,
      watchHomeWidgetNativeContext(ref, l10n),
    );
    final sizes = HomeWidgetCellSize.sizesOf(instance.kind);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
      child: Column(
        children: <Widget>[
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: dark
                    ? desk.surfaceContainerLowest
                    : desk.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: HomeWidgetPreview(
                      kind: instance.kind,
                      nativeConfig: nativeConfig,
                      extraPalettes: homeWidgetPreviewPalettes(instance),
                      size: controller.size,
                      dark: dark,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: l10n.homeWidgetPreviewSize,
            child: ExpressiveButtonGroup<HomeWidgetCellSize>(
              dense: true,
              segments: <ButtonSegment<HomeWidgetCellSize>>[
                for (final size in sizes)
                  ButtonSegment<HomeWidgetCellSize>(
                    value: size,
                    label: Text(size.label),
                  ),
              ],
              selected: <HomeWidgetCellSize>{controller.size},
              onSelectionChanged: (Set<HomeWidgetCellSize> selected) =>
                  controller.size = selected.first,
            ),
          ),
          const SizedBox(height: 12),
          if (onAddToHome != null)
            FilledButton.icon(
              onPressed: onAddToHome,
              icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
              label: Text(l10n.homeWidgetAddToHome),
            )
          else
            Text(
              l10n.homeWidgetsInstalledHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
