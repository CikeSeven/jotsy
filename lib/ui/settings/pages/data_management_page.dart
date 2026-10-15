import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/settings/pages/webdav_sync_page.dart';
import 'package:node_diary/ui/settings/widgets/settings_card_group.dart';

import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/action_loading_overlay.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../controllers/data_management_controller.dart';
import '../controllers/journal_import_controller.dart';

/// 数据管理页面：完整备份导出、导入（合并或覆盖）、从其他日记应用导入与
/// WebDAV 入口。
///
/// 只负责装配与忙碌/提示出口，导出导入流程见 [DataManagementController]，
/// 其他应用的导入流程见 [JournalImportController]。
class DataManagementPage extends ConsumerStatefulWidget {
  const DataManagementPage({super.key});

  @override
  ConsumerState<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends ConsumerState<DataManagementPage>
    implements DataManagementHost {
  late final DataManagementController _controller = DataManagementController(
    this,
  );
  late final JournalImportController _journalImport = JournalImportController(
    this,
  );
  bool _busy = false;
  String _busyText = '';

  @override
  bool get busy => _busy;

  /// 切换忙碌态。结束时保留上一条步骤文案，让它随遮罩一起淡出，而不是先
  /// 变空再消失。
  @override
  void setBusy(bool busy, [String text = '']) {
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = busy;
      if (busy) {
        _busyText = text;
      }
    });
  }

  @override
  void showSnack(String message) {
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 导入会改写本地数据，进行中禁止返回，避免页面销毁后流程仍在后台改写
    // 数据库而用户无从得知结果。
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppTopBar(
          title: Text(context.l10n.dataMgmtTitle),
          leading: IconButton(
            tooltip: context.l10n.commonBack,
            onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
            icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
          ),
        ),
        body: Stack(
          children: <Widget>[
            ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
              children: <Widget>[
                SettingsCardGroup(
                  children: <Widget>[
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: const FaIcon(
                        FontAwesomeIcons.fileExport,
                        size: 16,
                      ),
                      title: Text(context.l10n.dataMgmtExport),
                      subtitle: Text(context.l10n.dataMgmtExportSubtitle),
                      trailing: const FaIcon(
                        FontAwesomeIcons.angleRight,
                        size: 14,
                      ),
                      onTap: _controller.exportAll,
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: const FaIcon(
                        FontAwesomeIcons.fileImport,
                        size: 16,
                      ),
                      title: Text(context.l10n.dataMgmtImport),
                      subtitle: Text(context.l10n.dataMgmtImportSubtitle),
                      trailing: const FaIcon(
                        FontAwesomeIcons.angleRight,
                        size: 14,
                      ),
                      onTap: _controller.importData,
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: const FaIcon(
                        FontAwesomeIcons.rightToBracket,
                        size: 16,
                      ),
                      title: Text(context.l10n.dataMgmtImportJournal),
                      subtitle: Text(
                        context.l10n.dataMgmtImportJournalSubtitle,
                      ),
                      trailing: const FaIcon(
                        FontAwesomeIcons.angleRight,
                        size: 14,
                      ),
                      onTap: _journalImport.importFromApp,
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: const FaIcon(
                        FontAwesomeIcons.cloudArrowUp,
                        size: 16,
                      ),
                      title: Text(context.l10n.dataMgmtWebDav),
                      subtitle: Text(context.l10n.dataMgmtWebDavSubtitle),
                      trailing: const FaIcon(
                        FontAwesomeIcons.angleRight,
                        size: 14,
                      ),
                      onTap: () {
                        if (_busy) {
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) {
                              return const WebDavSyncPage();
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    context.l10n.dataMgmtHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            // 忙碌期间立即拦截点击，画面在超过 300ms 后才淡入；条目不再随
            // 忙碌态整体变灰闪一下。
            Positioned.fill(
              child: ActionLoadingOverlay(
                visible: _busy,
                label: _busyText,
                semanticLabel: context.l10n.dataMgmtBusyLabel,
                revealDelay: DelayedLoadingGate.defaultDelay,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
