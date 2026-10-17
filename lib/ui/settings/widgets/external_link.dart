import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';

/// 设置模块的外链统一入口：
/// 1) 优先拉起系统浏览器；
/// 2) 系统无法处理时复制链接并提示，避免用户丢失入口。
Future<void> openExternalLink(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  if (uri != null) {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) {
      return;
    }
  }
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) {
    return;
  }
  await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(content: Text(context.l10n.aboutOpenLinkFallbackCopied)),
  );
}
