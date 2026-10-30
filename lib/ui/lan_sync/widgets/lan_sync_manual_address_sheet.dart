import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../models/lan_sync_address_input.dart';
import '../models/lan_sync_platform.dart';

/// 手动输入的地址（已校验、规整）。
@immutable
class LanSyncManualAddress {
  const LanSyncManualAddress(this.host, this.port);

  final String host;
  final int port;
}

/// “手动输入地址”面板（只负责收集与校验）：地址与端口两个输入框，端口默认
/// [LanSyncPorts.preferredSync]。地址框里粘贴“地址:端口”时自动拆到两个框里
/// （逐字输入时不拆，免得打到一半就被拆走；点“连接”时再拆一次兜底）。点
/// “连接”且两项都合法时返回结果，取消返回 null；不合法时在对应输入框下
/// 提示，面板不关闭。
Future<LanSyncManualAddress?> showLanSyncManualAddressSheet(
  BuildContext context,
) {
  return showAppModalBottomSheet<LanSyncManualAddress>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 640),
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) => const _ManualAddressSheet(),
  );
}

class _ManualAddressSheet extends StatefulWidget {
  const _ManualAddressSheet();

  @override
  State<_ManualAddressSheet> createState() => _ManualAddressSheetState();
}

class _ManualAddressSheetState extends State<_ManualAddressSheet> {
  final TextEditingController _host = TextEditingController();
  final TextEditingController _port = TextEditingController(
    text: '${LanSyncPorts.preferredSync}',
  );

  /// 只在点过“连接”之后提示错误，输入中途不打断。
  bool _hostError = false;
  bool _portError = false;

  /// 地址框上一次的长度：一次多出不止一个字即视为粘贴。
  int _hostLength = 0;

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  void _onHostChanged(String text) {
    final pasted = text.length - _hostLength > 1;
    _hostLength = text.length;
    if (pasted) _splitHostPort();
    if (_hostError) setState(() => _hostError = false);
  }

  /// 地址框是“地址:端口”时拆到两个框里；拆了返回 true。
  bool _splitHostPort() {
    final split = splitLanSyncHostPort(_host.text);
    if (split == null) return false;
    _host.value = TextEditingValue(
      text: split.host,
      selection: TextSelection.collapsed(offset: split.host.length),
    );
    _hostLength = split.host.length;
    _port.text = '${split.port}';
    if (_portError) setState(() => _portError = false);
    return true;
  }

  void _submit() {
    _splitHostPort();
    final host = normalizeLanSyncHost(_host.text);
    final port = parseLanSyncPort(_port.text);
    if (host == null || port == null) {
      setState(() {
        _hostError = host == null;
        _portError = port == null;
      });
      return;
    }
    Navigator.of(context).pop(LanSyncManualAddress(host, port));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.lanSyncManualAddress,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.lanSyncManualIntro,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            TextField(
              key: const ValueKey<String>('lanSyncManualHost'),
              controller: _host,
              autofocus: true,
              autocorrect: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              onChanged: _onHostChanged,
              decoration: InputDecoration(
                labelText: l10n.lanSyncManualHostLabel,
                hintText: l10n.lanSyncManualHostHint,
                errorText: _hostError ? l10n.lanSyncManualHostInvalid : null,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              key: const ValueKey<String>('lanSyncManualPort'),
              controller: _port,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_portError) setState(() => _portError = false);
              },
              decoration: InputDecoration(
                labelText: l10n.lanSyncManualPortLabel,
                errorText: _portError ? l10n.lanSyncManualPortInvalid : null,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onSurfaceVariant,
                  ),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: AppSpacing.s),
                FilledButton(
                  onPressed: _submit,
                  child: Text(l10n.lanSyncManualConnect),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
