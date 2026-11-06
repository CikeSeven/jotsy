import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/app_top_bar.dart';
import '../widgets/app_lock_surface.dart';
import '../widgets/passcode_unlock_view.dart';

/// 应用密码验证页：应用密码方式下，进入上锁日记本、确认局域网配对、关闭
/// 应用锁、切换验证方式与修改密码前都打开这里（经 `IdentityVerifier.verify`）。
///
/// 返回 true 表示验证通过；返回、Esc 或系统返回为 false。[allowBiometric] 为
/// true 时进入后自动弹一次指纹（开着且可用时），敏感操作传 false 只认密码。
class PasscodeVerifyPage extends StatelessWidget {
  const PasscodeVerifyPage({
    super.key,
    required this.reason,
    this.allowBiometric = true,
  });

  final String reason;
  final bool allowBiometric;

  static Future<bool> open(
    BuildContext context, {
    required String reason,
    bool allowBiometric = true,
  }) async {
    final passed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (BuildContext context) =>
            PasscodeVerifyPage(reason: reason, allowBiometric: allowBiometric),
      ),
    );
    return passed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppPageBackground(
      area: AppBackgroundArea.other,
      child: Builder(
        builder: (BuildContext context) => CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.of(context).maybePop(false),
          },
          child: Scaffold(
            backgroundColor: AppPageBackdrop.pageColorOf(context),
            appBar: AppTopBar(
              title: Text(l10n.passcodeVerifyTitle),
              leading: IconButton(
                tooltip: l10n.commonBack,
                onPressed: () => Navigator.of(context).maybePop(false),
                icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
              ),
            ),
            body: AppLockScrollBody(
              builder: (BuildContext context, double viewportHeight) =>
                  PasscodeUnlockView(
                    message: reason,
                    allowBiometric: allowBiometric,
                    autoBiometric: allowBiometric,
                    onUnlocked: () => Navigator.of(context).pop(true),
                    viewportHeight: viewportHeight,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
