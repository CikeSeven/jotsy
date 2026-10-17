import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/cloud_backup_drive.dart';
import '../../../core/services/cloud_backup_oauth.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../controllers/cloud_backup_failure.dart';

/// 授权对话框里发生的失败，由调用方按失败分类提示。取消不算失败（返回 null）。
class CloudAuthorizationFailed implements Exception {
  const CloudAuthorizationFailed(this.error);

  final Object error;
}

/// 设备码授权对话框：申请设备码 → 展示代码，用户在浏览器授权 → 轮询拿到
/// 令牌后自动关闭并返回令牌。关闭对话框即取消轮询，返回 null；申请或轮询
/// 失败抛出 [CloudAuthorizationFailed]。
Future<CloudOAuthToken?> showCloudDeviceAuthorizationDialog(
  BuildContext context, {
  required CloudDeviceCodeAuthorization method,
  required String providerName,
}) async {
  final outcome = await showDialog<_AuthorizationOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) =>
        _DeviceCodeDialog(method: method, providerName: providerName),
  );
  final error = outcome?.error;
  if (error != null) throw CloudAuthorizationFailed(error);
  return outcome?.token;
}

/// 授权码粘贴对话框：在浏览器打开授权页，用户把网盘显示的授权码粘贴回来
/// 换取令牌。授权码无效时留在对话框内提示，可重新获取后再试。
Future<CloudOAuthToken?> showCloudCodePasteDialog(
  BuildContext context, {
  required CloudCodePasteAuthorization method,
  required String providerName,
}) {
  return showDialog<CloudOAuthToken>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) =>
        _CodePasteDialog(method: method, providerName: providerName),
  );
}

class _AuthorizationOutcome {
  const _AuthorizationOutcome.token(CloudOAuthToken this.token) : error = null;
  const _AuthorizationOutcome.error(Object this.error) : token = null;

  final CloudOAuthToken? token;
  final Object? error;
}

Future<void> _openInBrowser(Uri uri) async {
  // 必须在系统浏览器中打开：Google、Dropbox 都不允许在内嵌网页里授权。
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _DeviceCodeDialog extends StatefulWidget {
  const _DeviceCodeDialog({required this.method, required this.providerName});

  final CloudDeviceCodeAuthorization method;
  final String providerName;

  @override
  State<_DeviceCodeDialog> createState() => _DeviceCodeDialogState();
}

class _DeviceCodeDialogState extends State<_DeviceCodeDialog> {
  final CloudBackupCancellation _cancellation = CloudBackupCancellation();
  CloudDeviceAuthorization? _authorization;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    // 对话框关闭（含返回键）即停止轮询，避免后台继续请求令牌端点。
    _cancellation.cancel();
    super.dispose();
  }

  /// 申请设备码后立即开始轮询；轮询在用户切到浏览器期间继续进行。
  Future<void> _run() async {
    try {
      final authorization = await widget.method.start();
      if (!mounted || _cancellation.isCancelled) return;
      setState(() => _authorization = authorization);
      final token = await waitForDeviceToken(
        authorization,
        widget.method.poll,
        cancellation: _cancellation,
      );
      if (mounted) {
        Navigator.of(context).pop(_AuthorizationOutcome.token(token));
      }
    } on CloudBackupCancelled {
      // 用户关闭了对话框。
    } catch (error) {
      if (mounted && !_cancellation.isCancelled) {
        Navigator.of(context).pop(_AuthorizationOutcome.error(error));
      }
    }
  }

  /// 打开授权页前先复制代码，切到浏览器后直接粘贴。
  Future<void> _openPage() async {
    final authorization = _authorization;
    if (authorization == null) return;
    await _copyCode();
    await _openInBrowser(
      authorization.verificationUriComplete ?? authorization.verificationUri,
    );
  }

  Future<void> _copyCode() async {
    final authorization = _authorization;
    if (authorization == null) return;
    await Clipboard.setData(ClipboardData(text: authorization.userCode));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authorization = _authorization;
    return AlertDialog(
      title: Text(l10n.cloudBackupAuthorizeTitle(widget.providerName)),
      content: SingleChildScrollView(
        child: authorization == null
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
                child: Center(child: ExpressiveLoadingIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.cloudBackupDeviceCodeHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Semantics(
                    label: l10n.cloudBackupDeviceCodeLabel,
                    child: SelectableText(
                      authorization.userCode,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  FilledButton.icon(
                    onPressed: _openPage,
                    icon: const FaIcon(
                      FontAwesomeIcons.arrowUpRightFromSquare,
                      size: 14,
                    ),
                    label: Text(l10n.cloudBackupOpenAuthorizePage),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  OutlinedButton.icon(
                    onPressed: _copyCode,
                    icon: ExpressiveIconSwap(
                      switchKey: _copied,
                      child: FaIcon(
                        _copied
                            ? FontAwesomeIcons.circleCheck
                            : FontAwesomeIcons.copy,
                        size: 14,
                      ),
                    ),
                    label: Text(
                      _copied
                          ? l10n.cloudBackupDeviceCodeCopied
                          : l10n.cloudBackupCopyCode,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const ExpressiveLoadingIndicator(size: 24),
                      const SizedBox(width: AppSpacing.s),
                      Flexible(
                        child: Text(
                          l10n.cloudBackupWaitingAuthorization,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}

class _CodePasteDialog extends StatefulWidget {
  const _CodePasteDialog({required this.method, required this.providerName});

  final CloudCodePasteAuthorization method;
  final String providerName;

  @override
  State<_CodePasteDialog> createState() => _CodePasteDialogState();
}

class _CodePasteDialogState extends State<_CodePasteDialog> {
  final TextEditingController _code = TextEditingController();
  bool _exchanging = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.isEmpty || _exchanging) return;
    setState(() {
      _exchanging = true;
      _error = null;
    });
    try {
      final token = await widget.method.exchange(code);
      if (mounted) Navigator.of(context).pop(token);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _exchanging = false;
        _error = describeCloudBackupError(context.l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final error = _error;
    return AlertDialog(
      title: Text(l10n.cloudBackupAuthorizeTitle(widget.providerName)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.cloudBackupCodePasteHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            FilledButton.icon(
              onPressed: () => _openInBrowser(widget.method.authorizeUri),
              icon: const FaIcon(
                FontAwesomeIcons.arrowUpRightFromSquare,
                size: 14,
              ),
              label: Text(l10n.cloudBackupOpenAuthorizePage),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _code,
              enabled: !_exchanging,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.cloudBackupCodeLabel,
                errorText: error,
                errorMaxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
          onPressed: _exchanging ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
          onPressed: _exchanging ? null : _submit,
          child: _exchanging
              ? const ExpressiveLoadingIndicator(size: 20)
              : Text(l10n.cloudBackupCodeConfirm),
        ),
      ],
    );
  }
}
