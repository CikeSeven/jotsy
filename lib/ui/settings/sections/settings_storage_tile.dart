import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../storage/pages/storage_page.dart';
import '../../storage/providers/storage_providers.dart';
import '../widgets/settings_nav_tile.dart';

/// 设置首页“数据与安全”里的“存储管理”行：副标题为应用已用的空间（后台
/// 只累加文件大小，算完前不显示副标题）。从存储管理回来后重新计算。
class SettingsStorageTile extends ConsumerWidget {
  const SettingsStorageTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final total = ref.watch(storageQuickTotalProvider).value;
    return SettingsNavTile(
      icon: FontAwesomeIcons.chartPie,
      title: l10n.storageMgmtTitle,
      subtitle: total == null
          ? null
          : l10n.settingsStorageSubtitle(l10n.formatByteSize(total)),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => const StoragePage(),
          ),
        );
        if (context.mounted) ref.invalidate(storageQuickTotalProvider);
      },
    );
  }
}
