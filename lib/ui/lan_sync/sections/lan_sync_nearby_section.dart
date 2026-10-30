// “附近的设备”分组：发现到的、还没配对的设备。
//
// 设备的出现与消失经 `ListItemPresence`（`medium`）展开 / 收起：控制器给出的
// 列表里不见了的设备先留在原位（visible 为 false）播放收起，计时到点后才从
// 本地列表移除；收起期间同一设备重新出现则取消移除、重新展开。计时器在
// dispose 时一并取消。减少动画时时长为 0，直接移除，不起计时器。
// 一台都没有时只显示一行灰字提示。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../widgets/list_item_presence.dart';
import '../models/lan_sync_view_state.dart';
import '../widgets/lan_sync_device_row.dart';
import '../widgets/lan_sync_device_tile.dart';
import '../widgets/lan_sync_labels.dart';
import '../widgets/lan_sync_searching_dots.dart';
import '../widgets/lan_sync_section_header.dart';

class LanSyncNearbySection extends StatefulWidget {
  const LanSyncNearbySection({
    super.key,
    required this.nearby,
    required this.searching,
    required this.onPair,
  });

  final List<LanSyncNearbyView> nearby;
  final bool searching;
  final ValueChanged<String> onPair;

  @override
  State<LanSyncNearbySection> createState() => _LanSyncNearbySectionState();
}

class _NearbyEntry {
  _NearbyEntry(this.view, {required this.appearing});

  LanSyncNearbyView view;
  bool visible = true;
  final bool appearing;
  Timer? removal;
}

class _LanSyncNearbySectionState extends State<LanSyncNearbySection> {
  /// 首次构建时已有的设备直接显示，之后新出现的才播放展开。
  late final List<_NearbyEntry> _entries = <_NearbyEntry>[
    for (final view in widget.nearby) _NearbyEntry(view, appearing: false),
  ];

  @override
  void didUpdateWidget(LanSyncNearbySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.nearby, widget.nearby)) return;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    final incoming = <String, LanSyncNearbyView>{
      for (final view in widget.nearby) view.deviceId: view,
    };
    for (final entry in _entries.toList()) {
      final next = incoming.remove(entry.view.deviceId);
      if (next != null) {
        entry
          ..view = next
          ..visible = true;
        entry.removal?.cancel();
        entry.removal = null;
      } else if (entry.visible) {
        entry.visible = false;
        if (duration == Duration.zero) {
          _entries.remove(entry);
        } else {
          entry.removal = Timer(duration, () {
            if (!mounted) return;
            setState(() => _entries.remove(entry));
          });
        }
      }
    }
    // 新出现的设备按控制器给的顺序追加在末尾。
    for (final view in widget.nearby) {
      if (incoming.containsKey(view.deviceId)) {
        _entries.add(_NearbyEntry(view, appearing: true));
      }
    }
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.removal?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LanSyncSectionHeader(
          title: l10n.lanSyncSectionNearby,
          trailing: widget.searching
              ? LanSyncSearchingDots(
                  label: l10n.lanSyncSearching,
                  style: LanSyncSectionHeader.trailingStyle(
                    context,
                    color: theme.colorScheme.primary,
                  ),
                )
              : null,
        ),
        if (_entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              l10n.lanSyncNearbyEmpty,
              style: LanSyncSectionHeader.trailingStyle(context),
            ),
          )
        else
          AppCardSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final (i, entry) in _entries.indexed)
                  ListItemPresence(
                    key: ValueKey<String>(
                      'lanSyncNearby:${entry.view.deviceId}',
                    ),
                    visible: entry.visible,
                    appearing: entry.appearing,
                    duration: duration,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (i > 0)
                          const SettingsCardGroupDivider(
                            indent: LanSyncDeviceRow.textStart,
                          ),
                        _NearbyRow(
                          view: entry.view,
                          // 收起中的设备已经不在附近，不能再发起配对。
                          onPair: entry.visible
                              ? () => widget.onPair(entry.view.deviceId)
                              : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({required this.view, required this.onPair});

  final LanSyncNearbyView view;
  final VoidCallback? onPair;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LanSyncDeviceRow(
      tile: LanSyncDeviceTile(platform: view.platform, active: false),
      title: view.name,
      subtitle: TextSpan(
        text: l10n.lanSyncNearbySubtitle(
          lanSyncPlatformLabel(l10n, view.platform),
          view.address,
        ),
      ),
      trailing: LanSyncRowButton(
        label: l10n.lanSyncPair,
        filled: true,
        onPressed: onPair,
      ),
    );
  }
}
