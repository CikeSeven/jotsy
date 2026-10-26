import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/cloud_backup_settings_service.dart';
import '../../../core/services/cloud_backup_target.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/action_loading_overlay.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../controllers/cloud_backup_controller.dart';
import '../controllers/cloud_backup_failure.dart';
import '../widgets/cloud_backup_labels.dart';
import '../widgets/cloud_backup_provider_sheet.dart';
import '../widgets/settings_card_group.dart';
import 'cloud_backup_target_page.dart';
import '../../widgets/form_width.dart';

/// 网盘备份首页：已配置的备份位置列表与“添加备份位置”。
///
/// - 授权类网盘在添加时就完成授权并保存，成功后进入该位置的页面；
/// - WebDAV / S3 按预设生成未保存的草稿进入配置页，保存后才出现在列表里；
/// - 列表随 [CloudBackupSettingsService.targetsNotifier] 实时刷新。
class CloudBackupPage extends ConsumerStatefulWidget {
  const CloudBackupPage({super.key});

  @override
  ConsumerState<CloudBackupPage> createState() => _CloudBackupPageState();
}

class _CloudBackupPageState extends ConsumerState<CloudBackupPage>
    implements CloudBackupHost {
  late final CloudBackupController _controller = CloudBackupController(this);
  bool _busy = false;
  String _busyText = '';

  @override
  bool get busy => _busy;

  @override
  void setBusy(bool busy, [String text = '']) {
    if (!mounted) return;
    setState(() {
      _busy = busy;
      if (busy) _busyText = text;
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

  Future<void> _add() async {
    if (_busy) return;
    final service = await ref.read(cloudBackupServiceProvider.future);
    if (!mounted) return;
    final choice = await showCloudBackupProviderSheet(
      context,
      isDriveAvailable: service.isDriveAvailable,
    );
    if (choice == null || !mounted) return;
    final preset = choice.preset;
    if (preset == null) {
      final target = await _controller.authorize(choice.kind);
      if (target != null && mounted) _open(target);
      return;
    }
    _open(
      CloudBackupTarget.create(
        kind: preset.kind,
        config: preset.initialConfig(),
        presetId: preset.id,
      ),
      isNew: true,
    );
  }

  void _open(CloudBackupTarget target, {bool isNew = false}) {
    if (_busy) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            CloudBackupTargetPage(target: target, isNew: isNew),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settingsAsync = ref.watch(cloudBackupSettingsServiceProvider);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppTopBar(
          contentMaxWidth: FormWidth.maxWidth,
          title: Text(l10n.cloudBackupTitle),
          leading: IconButton(
            tooltip: l10n.commonBack,
            onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
            icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
          ),
        ),
        body: Stack(
          children: <Widget>[
            settingsAsync.when(
              data: (settings) =>
                  ValueListenableBuilder<List<CloudBackupTarget>>(
                    valueListenable: settings.targetsNotifier,
                    builder: (context, targets, _) =>
                        _buildContent(context, targets),
                  ),
              loading: () => const DelayedLoadingIndicator(),
              error: (error, _) => ListView(
                padding: const EdgeInsets.all(AppSpacing.l),
                children: <Widget>[Text(describeCloudBackupError(l10n, error))],
              ),
            ),
            Positioned.fill(
              child: ActionLoadingOverlay(
                visible: _busy,
                label: _busyText,
                semanticLabel: l10n.cloudBackupBusyLabel,
                revealDelay: DelayedLoadingGate.defaultDelay,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<CloudBackupTarget> targets) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final side = FormWidth.extra(constraints.maxWidth);
        return ListView(
          padding: EdgeInsets.fromLTRB(
            side,
            AppSpacing.m,
            side,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            if (targets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Text(
                  l10n.cloudBackupEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              )
            else
              SettingsCardGroup(
                children: <Widget>[
                  for (final target in targets)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.l,
                        vertical: AppSpacing.xs,
                      ),
                      leading: FaIcon(cloudBackupTargetIcon(target), size: 16),
                      title: Text(cloudBackupTargetName(l10n, target)),
                      subtitle: Text(
                        cloudBackupTargetSummary(l10n, target),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const FaIcon(
                        FontAwesomeIcons.angleRight,
                        size: 14,
                      ),
                      onTap: () => _open(target),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.l),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _add,
                  icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                  label: Text(l10n.cloudBackupAdd),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Text(
                l10n.cloudBackupHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
