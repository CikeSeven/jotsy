import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../../app/theme/expressive_surfaces.dart';
import '../../../explore/models/explore_module_config.dart';
import '../../../explore/models/explore_module_id.dart';
import '../../../explore/models/explore_module_spec.dart';
import '../../../explore/viewmodels/explore_labels.dart';
import '../../../widgets/expressive_reorder_proxy.dart';
import '../../../widgets/triple_bar_drag_handle.dart';
import '../../controllers/explore_layout_editor_controller.dart';
import '../../providers/app_features_provider.dart';
import '../../widgets/settings_reveal.dart';
import 'explore_layout_labels.dart';
import 'explore_layout_option_controls.dart';

/// “卡片”标签页：全部卡片排成一条可拖动排序的列表。
///
/// 每行：图标、名称与“分组 · 说明”、显示开关与拖动手柄；点按一行展开它的
/// 设置（宽窗口下的宽度与这张卡的选项，[exploreModuleOptionTiles]）。功能
/// 管理里关掉的功能，对应的卡片开关禁用并注明原因（数据与设置保留）。
///
/// 拖拽手柄立即拖动、不经过长按，系统不会反馈；拿起时补一次触觉，与其他
/// 排序页一致。从探索页长按“卡片设置”进来时，[focus] 这张卡默认展开并滚到
/// 可见处。
class ExploreLayoutCardsTab extends ConsumerStatefulWidget {
  const ExploreLayoutCardsTab({
    super.key,
    required this.controller,
    this.focus,
  });

  final ExploreLayoutEditorController controller;
  final ExploreModuleId? focus;

  @override
  ConsumerState<ExploreLayoutCardsTab> createState() =>
      _ExploreLayoutCardsTabState();
}

class _ExploreLayoutCardsTabState extends ConsumerState<ExploreLayoutCardsTab> {
  late final Set<ExploreModuleId> _expanded = <ExploreModuleId>{?widget.focus};
  final GlobalKey _focusKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.focus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _focusKey.currentContext;
        if (target != null && target.mounted) {
          unawaited(Scrollable.ensureVisible(target, alignment: 0.1));
        }
      });
    }
  }

  void _toggleExpanded(ExploreModuleId id) {
    setState(() {
      if (!_expanded.remove(id)) _expanded.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final features = ref.watch(appFeaturesProvider);
    final controller = widget.controller;
    final layout = controller.style;
    final modules = layout.modules;
    final defaultOrder = <ExploreModuleId>[
      for (final spec in ExploreModuleSpec.all) spec.id,
    ];
    final isDefaultOrder =
        <ExploreModuleId>[for (final config in modules) config.id].join() ==
        defaultOrder.join();
    final allShown = modules.every(
      (config) => config.visible || !config.spec.isAvailable(features),
    );
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
      buildDefaultDragHandles: false,
      proxyDecorator: expressiveReorderProxyDecorator,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.exploreLayoutCardsHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: <Widget>[
                TextButton.icon(
                  onPressed: allShown
                      ? null
                      : () => controller.applyStyle(
                          layout.withModuleOrder(<ExploreModuleConfig>[
                            for (final config in modules)
                              config.spec.isAvailable(features)
                                  ? config.copyWith(visible: true)
                                  : config,
                          ]),
                        ),
                  icon: const FaIcon(FontAwesomeIcons.eye, size: 14),
                  label: Text(l10n.exploreLayoutCardsShowAll),
                ),
                TextButton.icon(
                  onPressed: isDefaultOrder
                      ? null
                      : () => controller.applyStyle(
                          layout.withModuleOrder(<ExploreModuleConfig>[
                            for (final id in defaultOrder) layout.module(id),
                          ]),
                        ),
                  icon: const FaIcon(
                    FontAwesomeIcons.arrowRotateLeft,
                    size: 14,
                  ),
                  label: Text(l10n.exploreLayoutCardsDefaultOrder),
                ),
              ],
            ),
          ],
        ),
      ),
      itemCount: modules.length,
      onReorderStart: (_) => unawaited(HapticFeedback.mediumImpact()),
      onReorderItem: controller.moveModule,
      itemBuilder: (BuildContext context, int index) {
        final config = modules[index];
        final spec = config.spec;
        final available = spec.isAvailable(features);
        final name = ExploreLabels.moduleName(l10n, config.id);
        final expanded = _expanded.contains(config.id);
        return Padding(
          key: ValueKey<ExploreModuleId>(config.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            key: config.id == widget.focus ? _focusKey : null,
            color: ExpressiveSurfaces.cardColor(scheme),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: ExpressiveSurfaces.cardBorderSide(scheme),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  contentPadding: const EdgeInsetsDirectional.only(
                    start: 16,
                    end: 4,
                  ),
                  onTap: () => _toggleExpanded(config.id),
                  leading: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FaIcon(
                      spec.icon,
                      size: 14,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  title: Text(name),
                  subtitle: Text(
                    available
                        ? '${ExploreLayoutLabels.group(l10n, spec.group)} · '
                              '${ExploreLabels.moduleDescription(l10n, config.id)}'
                        : l10n.exploreLayoutFeatureOff,
                    maxLines: expanded ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Semantics(
                        label: l10n.exploreLayoutShowModule(name),
                        child: Switch(
                          value: config.visible && available,
                          onChanged: available
                              ? (bool value) =>
                                    controller.setVisible(config.id, value)
                              : null,
                        ),
                      ),
                      Semantics(
                        label: l10n.exploreLayoutDragHandle(name),
                        child: ReorderableDragStartListener(
                          index: index,
                          child: const SizedBox(
                            width: 44,
                            height: 40,
                            child: ColoredBox(
                              color: Colors.transparent,
                              child: Center(child: TripleBarDragHandle()),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SettingsReveal(
                  visible: expanded,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      settingsNestedDivider,
                      ...exploreModuleOptionTiles(
                        context,
                        controller: controller,
                        config: config,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
