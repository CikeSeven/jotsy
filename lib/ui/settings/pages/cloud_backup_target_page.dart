import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/cloud_backup_models.dart';
import '../../../core/services/cloud_backup_presets.dart';
import '../../../core/services/cloud_backup_target.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/action_loading_overlay.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../controllers/cloud_backup_controller.dart';
import '../controllers/cloud_backup_failure.dart';
import '../sections/cloud_backup_account_section.dart';
import '../sections/cloud_backup_config_forms.dart';
import '../sections/cloud_backup_remote_list.dart';
import '../widgets/cloud_backup_labels.dart';

/// 单个备份位置的页面：连接配置（或授权账号）、上传、远程备份列表与恢复。
///
/// 只负责装配与忙碌/提示出口，流程见 [CloudBackupController]。
/// - [isNew] 为 true 时 [target] 是尚未保存的草稿（刚从预设创建）：保存、
///   测试连接、上传或刷新时才写入，直接返回则不留下任何配置；
/// - 填写式位置每次发起网络操作前，若表单与已保存的配置不同则先保存；
/// - 已保存的位置打开时静默读取一次远程列表（失败只在列表处提示）。
class CloudBackupTargetPage extends ConsumerStatefulWidget {
  const CloudBackupTargetPage({
    super.key,
    required this.target,
    this.isNew = false,
  });

  final CloudBackupTarget target;
  final bool isNew;

  @override
  ConsumerState<CloudBackupTargetPage> createState() =>
      _CloudBackupTargetPageState();
}

class _CloudBackupTargetPageState extends ConsumerState<CloudBackupTargetPage>
    implements CloudBackupHost {
  late final CloudBackupController _controller = CloudBackupController(this);
  late CloudBackupTarget _target = widget.target;
  late bool _saved = !widget.isNew;
  late final CloudBackupFormFields? _form = CloudBackupFormFields.forKind(
    widget.target.kind,
    widget.target.config,
  );
  List<CloudBackupEntry> _backups = const <CloudBackupEntry>[];
  bool _listLoading = false;
  String? _listError;
  bool _busy = false;
  String _busyText = '';

  CloudBackupPreset? get _preset => cloudBackupPresetById(_target.presetId);

  @override
  bool get busy => _busy;

  @override
  void initState() {
    super.initState();
    if (_saved) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadList());
    }
  }

  @override
  void dispose() {
    _form?.dispose();
    super.dispose();
  }

  /// 切换忙碌态。结束时保留上一条文案，让它随遮罩一起淡出。
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

  /// 填写式位置：表单有改动或尚未保存时先保存，返回最新的位置；表单不合法
  /// 或保存失败返回 null（已提示）。授权类位置直接返回。
  Future<CloudBackupTarget?> _ensureSaved({bool notify = false}) async {
    final form = _form;
    if (form == null) return _target;
    final Map<String, Object?> config;
    try {
      config = form.toConfig();
    } catch (error) {
      showSnack(describeCloudBackupError(context.l10n, error));
      return null;
    }
    if (_saved && !notify && jsonEncode(config) == jsonEncode(_target.config)) {
      return _target;
    }
    final next = _target.copyWith(config: config);
    if (!await _controller.saveTarget(next, notify: notify)) return null;
    if (mounted) {
      setState(() {
        _target = next;
        _saved = true;
      });
    }
    return next;
  }

  Future<void> _loadList() async {
    final target = _target;
    setState(() {
      _listLoading = true;
      _listError = null;
    });
    try {
      final backups = await _controller.listBackups(target, showBusy: false);
      if (mounted) setState(() => _backups = backups ?? const []);
    } catch (error) {
      if (mounted) {
        setState(
          () => _listError = describeCloudBackupError(context.l10n, error),
        );
      }
    } finally {
      if (mounted) setState(() => _listLoading = false);
    }
  }

  Future<void> _refresh() async {
    final target = await _ensureSaved();
    if (target == null || !mounted) return;
    final backups = await _controller.listBackups(target);
    if (backups != null && mounted) {
      setState(() {
        _backups = backups;
        _listError = null;
      });
    }
  }

  Future<void> _testConnection() async {
    final target = await _ensureSaved();
    if (target != null) await _controller.testConnection(target);
  }

  Future<void> _upload() async {
    final target = await _ensureSaved();
    if (target == null) return;
    if (await _controller.upload(target)) await _loadList();
  }

  Future<void> _delete(CloudBackupEntry entry) async {
    if (await _controller.delete(_target, entry)) await _loadList();
  }

  Future<void> _reauthorize() async {
    final target = await _controller.authorize(_target.kind, existing: _target);
    if (target == null || !mounted) return;
    setState(() => _target = target);
    await _loadList();
  }

  Future<void> _remove() async {
    if (await _controller.removeTarget(_target) && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 上传/恢复进行中禁止返回：恢复会改写本地数据，中途离开无法得知结果。
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppTopBar(
          title: Text(cloudBackupTargetName(l10n, _target)),
          leading: IconButton(
            tooltip: l10n.commonBack,
            onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
            icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
          ),
          actions: <Widget>[
            if (_saved)
              IconButton(
                tooltip: l10n.cloudBackupRemoveTarget,
                onPressed: _busy ? null : _remove,
                icon: const FaIcon(FontAwesomeIcons.rightFromBracket, size: 16),
              ),
          ],
        ),
        body: Stack(
          children: <Widget>[
            ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.m,
                AppSpacing.l,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                ..._buildConfigSection(context),
                const Divider(height: 32),
                Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _upload,
                      icon: const FaIcon(
                        FontAwesomeIcons.cloudArrowUp,
                        size: 14,
                      ),
                      label: Text(l10n.cloudBackupUploadBackup),
                    ),
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const FaIcon(FontAwesomeIcons.rotate, size: 14),
                      label: Text(l10n.cloudBackupRefreshBackups),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                CloudBackupRemoteList(
                  backups: _backups,
                  loading: _listLoading,
                  error: _listError,
                  onRestore: (entry) => _controller.restore(_target, entry),
                  onDelete: _delete,
                ),
              ],
            ),
            // 忙碌期间立即拦截点击，画面在超过 300ms 后才淡入：保存配置这类
            // 本地操作几十毫秒就结束，不再闪一下。
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

  List<Widget> _buildConfigSection(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final form = _form;
    if (form == null) {
      return <Widget>[
        CloudBackupAccountSection(target: _target, onReauthorize: _reauthorize),
        const SizedBox(height: AppSpacing.m),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _testConnection,
            icon: const FaIcon(FontAwesomeIcons.plugCircleCheck, size: 14),
            label: Text(l10n.cloudBackupTestConnection),
          ),
        ),
      ];
    }
    return <Widget>[
      Text(l10n.cloudBackupConfigSection, style: theme.textTheme.titleMedium),
      const SizedBox(height: AppSpacing.m),
      CloudBackupConfigForm(fields: form, preset: _preset),
      const SizedBox(height: AppSpacing.m),
      Text(
        cloudBackupPresetHint(l10n, _preset),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: AppSpacing.l),
      Wrap(
        spacing: AppSpacing.s,
        runSpacing: AppSpacing.s,
        children: <Widget>[
          FilledButton.icon(
            onPressed: () => _ensureSaved(notify: true),
            icon: const FaIcon(FontAwesomeIcons.floppyDisk, size: 14),
            label: Text(l10n.cloudBackupSaveConfig),
          ),
          OutlinedButton.icon(
            onPressed: _testConnection,
            icon: const FaIcon(FontAwesomeIcons.plugCircleCheck, size: 14),
            label: Text(l10n.cloudBackupTestConnection),
          ),
        ],
      ),
    ];
  }
}
