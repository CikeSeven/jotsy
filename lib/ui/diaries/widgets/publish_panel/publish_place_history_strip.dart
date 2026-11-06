import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/desktop_horizontal_scroll.dart';

import '../../providers/diary_place_history_provider.dart';
import '../../viewmodels/place_history_view.dart';
import 'publish_panel_tile.dart';

/// 地点为空时输入框下方的“最近”条带：最近用过的几个地点排成一行胶囊，
/// 点一下直接填入；比 [maxChips] 多时末尾是“全部 N”，打开用过的地点子页。
///
/// 只在地点为空时出现（有地点时这一格换成地址层级入口，见
/// `PublishContextFields`）；还没有用过的地点、或仍在读取时不占高度。
/// 条带与输入框左缘对齐：第一枚胶囊的定位点（胶囊内边距 12）正好落在输入框
/// 定位图标的那一列。不再另放时钟图标——输入框行尾的时钟按钮就在正上方，
/// 两个时钟上下重复。横向滚动（桌面经 [DesktopHorizontalScroll] 支持拖动与
/// Shift+滚轮）。
class PublishPlaceHistoryStrip extends ConsumerWidget {
  const PublishPlaceHistoryStrip({
    super.key,
    required this.enabled,
    required this.onSelect,
    required this.onShowAll,
  });

  /// 条带里最多几个地点。
  static const int maxChips = 8;

  static const double chipHeight = 34;

  /// 正在定位时为 false：定位结果晚到会覆盖刚选的地点。
  final bool enabled;
  final ValueChanged<DiaryPlaceUsage> onSelect;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places =
        ref.watch(diaryPlaceHistoryProvider).value ?? const <DiaryPlaceUsage>[];
    if (places.isEmpty) return const SizedBox(width: double.infinity);
    final l10n = context.l10n;
    final shown = places.take(maxChips).toList(growable: false);
    final labels = placeChipLabels(shown);
    final more = places.length > shown.length;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.placeHistoryTitle,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          height: chipHeight,
          child: DesktopHorizontalScroll(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shown.length + (more ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (BuildContext context, int index) {
                if (index == shown.length) {
                  return _ShowAllChip(count: places.length, onTap: onShowAll);
                }
                final place = shown[index];
                return _PlaceChip(
                  key: ValueKey<String>('place_chip_${place.label}'),
                  place: place,
                  text: labels[index],
                  onTap: enabled ? () => onSelect(place) : null,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 一个地点胶囊：输入框同款填充色，行首小定位点（带坐标的地点为 `primary`，
/// 手填的为灰），长按 / 悬停显示全称。
class _PlaceChip extends StatelessWidget {
  const _PlaceChip({
    super.key,
    required this.place,
    required this.text,
    required this.onTap,
  });

  final DiaryPlaceUsage place;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = onTap != null;
    // 禁用（定位中）时文字与图标按 M3 禁用口径降到 38%。
    Color tone(Color color) => enabled ? color : color.withValues(alpha: 0.38);
    return Tooltip(
      message: place.label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: place.label,
        excludeSemantics: true,
        child: Material(
          color: PublishPanelTile.surfaceColorOf(context),
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FaIcon(
                    FontAwesomeIcons.locationDot,
                    size: 11,
                    color: tone(
                      place.hasCoordinates
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: tone(colorScheme.onSurface),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 条带末尾的“全部 N ›”：无底色的主色文字，与地点胶囊区分开。
class _ShowAllChip extends StatelessWidget {
  const _ShowAllChip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Material(
      type: MaterialType.transparency,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                context.l10n.placeHistoryShowAll(count),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              FaIcon(FontAwesomeIcons.angleRight, size: 11, color: primary),
            ],
          ),
        ),
      ),
    );
  }
}
