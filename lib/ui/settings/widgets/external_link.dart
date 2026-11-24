import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';

/// 应用的外链统一入口：
/// 1) 优先经系统外部应用 / 浏览器打开（直接调 `launchUrl`，不先查
///    `canLaunchUrl`，避免 Android 11+ 包可见性拦住可打开的链接）；
/// 2) 无法解析或系统无法处理时复制链接并提示，避免用户丢失入口。
Future<void> openExternalLink(BuildContext context, String value) async {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return;
  }
  final uri = _parseExternalUri(trimmed);
  if (uri != null) {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) {
        return;
      }
    } on PlatformException {
      // Android 没有应用能处理该 Intent 时会抛出 ACTIVITY_NOT_FOUND 而不是返回
      // false；统一落入下方的复制并提示。
    }
  }
  await Clipboard.setData(ClipboardData(text: trimmed));
  if (!context.mounted) {
    return;
  }
  await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(content: Text(context.l10n.aboutOpenLinkFallbackCopied)),
  );
}

/// 规整外链地址：已有 scheme 直接使用，缺少 scheme（如历史或导入数据里的
/// `example.com/a`、`//example.com/a`）时补 `https://`；非法格式返回 null。
Uri? _parseExternalUri(String value) {
  final parsed = Uri.tryParse(value);
  if (parsed == null) {
    return null;
  }
  if (parsed.hasScheme) {
    return parsed;
  }
  final prefixed = value.startsWith('//') ? 'https:$value' : 'https://$value';
  return Uri.tryParse(prefixed);
}
