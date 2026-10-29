import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_card_surface.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../models/lan_sync_view_state.dart';

/// 设备详情页英雄卡下面的一组：单设备“自动同步”开关与“备注名”。
///
/// 全局自动同步关闭时单设备开关仍可改（记住用户的选择），副标题说明暂不
/// 生效；备注名只在本机显示，副标题写出当前值。
class LanSyncDeviceSettings extends StatelessWidget {
  const LanSyncDeviceSettings({
    super.key,
    required this.peer,
    required this.globalAutoSync,
    required this.onAutoSyncChanged,
    required this.onEditAlias,
  });

  final LanSyncPeerView peer;

  /// 同步页“同步选项”里的全局自动同步开关。
  final bool globalAutoSync;
  final ValueChanged<bool> onAutoSyncChanged;
  final VoidCallback onEditAlias;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final alias = peer.alias?.trim();
    final aliasValue = alias == null || alias.isEmpty
        ? l10n.lanSyncAliasNotSet
        : alias;
    return AppCardSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SettingsSwitchTile(
            title: l10n.lanSyncAutoSync,
            subtitle: globalAutoSync
                ? l10n.lanSyncPeerAutoSyncSubtitle
                : l10n.lanSyncPeerAutoSyncGlobalOff,
            value: peer.autoSync,
            onChanged: onAutoSyncChanged,
          ),
          const SettingsCardGroupDivider(),
          ListTile(
            contentPadding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              top: 2,
              bottom: 2,
            ),
            title: Text(l10n.lanSyncAliasTitle),
            subtitle: Text('$aliasValue · ${l10n.lanSyncAliasLocalOnly}'),
            trailing: FaIcon(
              FontAwesomeIcons.angleRight,
              size: 14,
              color: colors.onSurfaceVariant,
            ),
            onTap: onEditAlias,
          ),
        ],
      ),
    );
  }
}
