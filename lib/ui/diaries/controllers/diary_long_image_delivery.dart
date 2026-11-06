import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/desktop_save_service.dart';
import '../../../core/services/image_export_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/image_export_messages.dart';

/// 分享长图生成后的去处。
enum DiaryLongImageDestination {
  /// 交给系统分享（手机）。
  share,

  /// 存进系统相册（手机）。
  gallery,

  /// 弹出“另存为…”对话框写到文件（桌面：长图不走系统分享，也没有相册）。
  file,
}

/// 把截好的预览页长图交到选定的去处（`DiaryPreviewExportController` 截图后
/// 调用）。
///
/// - 输入：PNG 字节、去处与本地化文案；
/// - 输出：要给用户的提示；交给系统分享（用户已在分享面板里）或取消了保存
///   对话框时为 null；
/// - 副作用：系统分享先把图片写到临时目录再交出；相册经
///   [ImageExportService.saveBytesToGallery]（首次会申请相册权限）；桌面经
///   [DesktopSaveService.saveBytes] 写到用户选的位置。
///
/// 存相册的失败（权限被拒等）在这里转成提示返回；系统分享与写文件的异常
/// 照常抛出，由调用方按各自的口径提示（“图片分享失败” / “保存失败”）。
class DiaryLongImageDelivery {
  const DiaryLongImageDelivery({
    this.images = const ImageExportService(),
    this.desktopSaver = const DesktopSaveService(),
  });

  final ImageExportService images;
  final DesktopSaveService desktopSaver;

  Future<String?> deliver(
    Uint8List bytes, {
    required DiaryLongImageDestination destination,
    required AppLocalizations l10n,
  }) async {
    // 同一个时间戳给文件名和相册名：相册里同名时系统自动加序号，不覆盖。
    final name = 'jotsy_diary_${DateTime.now().millisecondsSinceEpoch}';
    switch (destination) {
      case DiaryLongImageDestination.file:
        final path = await desktopSaver.saveBytes(
          bytes,
          fileName: '$name.png',
          dialogTitle: l10n.desktopSaveImageDialogTitle,
        );
        return path == null ? null : l10n.desktopSavedTo(path);
      case DiaryLongImageDestination.gallery:
        try {
          await images.saveBytesToGallery(bytes, name: name);
          return l10n.imageViewerSaveSuccess;
        } on ImageExportException catch (error) {
          return imageExportErrorMessage(l10n, error);
        }
      case DiaryLongImageDestination.share:
        final directory = await getTemporaryDirectory();
        final file = File(p.join(directory.path, '$name.png'));
        await file.writeAsBytes(bytes, flush: true);
        await Share.shareXFiles(<XFile>[XFile(file.path)]);
        return null;
    }
  }
}
