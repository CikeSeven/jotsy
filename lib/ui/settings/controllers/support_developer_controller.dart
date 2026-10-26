import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/app_platform.dart';
import '../../../core/services/image_export_service.dart';
import '../../../l10n/app_localizations.dart';
import '../models/support_channel.dart';

/// 交给其他应用打开 [uri]；返回是否有应用接手。
typedef ExternalUriLauncher = Future<bool> Function(Uri uri);

/// 默认的外部应用拉起：没有应用能处理（如没装支付宝）时 url_launcher 返回
/// false，个别 ROM 会抛 [PlatformException]，两者都按“打不开”处理。
Future<bool> launchExternalUri(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on PlatformException {
    return false;
  }
}

/// 打赏面板一次操作的结果。
///
/// [message] 为 null 表示已顺利交给其他应用、无需说明（面板清掉上一条说明）；
/// 有内容时面板把它写在按钮下方一行——面板遮罩会盖住 SnackBar，不用它提示。
@immutable
class SupportActionResult {
  const SupportActionResult({this.message, this.isError = false});

  static const SupportActionResult handedOff = SupportActionResult();

  final String? message;
  final bool isError;
}

/// “支持开发者”面板的执行层：打开支付宝付款、打开微信、把收款码存进相册。
///
/// - 输入：所选渠道与本地化文案；
/// - 输出：[isBusy]（面板据此禁用按钮）与每次操作的 [SupportActionResult]；
///   忙碌中重复触发直接忽略并返回 null，防止连点重复拉起应用或重复保存；
/// - 副作用：经 [ExternalUriLauncher] 拉起支付宝 / 微信；经
///   [ImageExportService.saveBytesToGallery] 把内置收款码写入相册（只在用户点
///   保存时申请相册权限；桌面没有相册，改为“另存为…”对话框）。不联网、
///   不记录任何打赏信息。
class SupportDeveloperController extends ChangeNotifier {
  SupportDeveloperController({
    this._service = const ImageExportService(),
    this._launcher = launchExternalUri,
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  final ImageExportService _service;
  final ExternalUriLauncher _launcher;
  final AssetBundle _bundle;
  bool _busy = false;
  bool _disposed = false;

  bool get isBusy => _busy;

  /// 让支付宝按“扫到收款码”打开付款页；没装支付宝等打不开时提示保存收款码。
  Future<SupportActionResult?> openAlipay(AppLocalizations l10n) {
    return _run(() async {
      final opened = await _launcher(alipayLaunchUri);
      return opened
          ? SupportActionResult.handedOff
          : SupportActionResult(
              message: l10n.supportDeveloperAlipayUnavailable,
              isError: true,
            );
    });
  }

  /// 打开微信（之后由用户在「扫一扫」里从相册选赞赏码）。
  Future<SupportActionResult?> openWeChat(AppLocalizations l10n) {
    return _run(() async {
      final opened = await _launcher(weChatLaunchUri);
      return opened
          ? SupportActionResult.handedOff
          : SupportActionResult(
              message: l10n.supportDeveloperWeChatUnavailable,
              isError: true,
            );
    });
  }

  /// 把 [channel] 的收款码保存到相册。
  Future<SupportActionResult?> saveCode(
    SupportChannel channel,
    AppLocalizations l10n,
  ) {
    return _run(() async {
      try {
        final data = await _bundle.load(channel.assetPath);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        if (!AppPlatform.savesImagesToGallery) {
          final path = await _service.saveBytesToFile(
            bytes,
            fileName: '${channel.galleryName}${p.extension(channel.assetPath)}',
            dialogTitle: l10n.desktopSaveImageDialogTitle,
          );
          // 取消对话框不算失败：清掉上一条说明即可。
          return path == null
              ? SupportActionResult.handedOff
              : SupportActionResult(message: l10n.desktopSavedTo(path));
        }
        await _service.saveBytesToGallery(bytes, name: channel.galleryName);
        return SupportActionResult(message: l10n.imageViewerSaveSuccess);
      } on ImageExportException catch (error) {
        return SupportActionResult(
          message: switch (error.type) {
            ImageExportErrorType.permissionDenied =>
              l10n.imageViewerGalleryPermissionDenied,
            ImageExportErrorType.invalidSource ||
            ImageExportErrorType.downloadFailed ||
            ImageExportErrorType.unknown => l10n.imageViewerSaveFailed(
              error.message,
            ),
          },
          isError: true,
        );
      }
    });
  }

  Future<SupportActionResult?> _run(
    Future<SupportActionResult> Function() task,
  ) async {
    if (_disposed || _busy) {
      return null;
    }
    _busy = true;
    notifyListeners();
    try {
      return await task();
    } finally {
      _busy = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
