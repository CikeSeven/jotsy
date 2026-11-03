import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/app_radii.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/core/services/app_platform.dart';
import 'package:node_diary/core/services/file_open_service.dart';
import 'package:node_diary/core/services/heif_image_converter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_file_open_controller.dart';
import 'package:node_diary/ui/diaries/widgets/diary_attachment_tile.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

/// 正文图片显示不出来时的占位，避免正文里出现空白或框架默认错误块。
///
/// 一般是文件被删除或来源失效（“图片文件不存在或无法加载”）。桌面上还有
/// 一种常见原因：手机存进来的 HEIC / HEIF / AVIF 照片——桌面版的解码器不认
/// 这些格式（见 [HeifImageConverter]）。这时读文件头确认后改为说明原因与
/// 补救办法（手机端会自动转成 JPEG，再同步一次），并可交给系统里装着的看图
/// 应用打开。文件头读出之前先按一般情况显示。
class DiaryImageFallback extends StatefulWidget {
  const DiaryImageFallback({
    super.key,
    required this.source,
    this.openService = const FileOpenService(),
  });

  /// 正文图片来源（本地路径、`file:` 地址、`data:` 或网络地址）。
  final String source;
  final FileOpenService openService;

  @override
  State<DiaryImageFallback> createState() => _DiaryImageFallbackState();
}

class _DiaryImageFallbackState extends State<DiaryImageFallback> {
  late final DiaryFileOpenController _opener = DiaryFileOpenController(
    service: widget.openService,
  );
  String? _heifPath;

  @override
  void initState() {
    super.initState();
    _detect();
  }

  @override
  void didUpdateWidget(DiaryImageFallback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _heifPath = null;
      _detect();
    }
  }

  @override
  void dispose() {
    _opener.dispose();
    super.dispose();
  }

  /// 只在桌面判断：手机上 HEIC 本就显示得了，失败只会是别的原因。
  Future<void> _detect() async {
    if (!AppPlatform.isDesktop) return;
    final source = widget.source;
    final path = _localPath(source);
    if (path == null || !await HeifImageConverter.isHeifFile(path)) return;
    if (!mounted || widget.source != source) return;
    setState(() => _heifPath = path);
  }

  static String? _localPath(String source) {
    final uri = Uri.tryParse(source);
    if (uri != null && uri.isScheme('file')) {
      try {
        return File.fromUri(uri).path;
      } catch (_) {
        return null;
      }
    }
    if (uri != null && uri.hasScheme && uri.scheme.length > 1) return null;
    return source;
  }

  Future<void> _open(String path) async {
    final failure = await _opener.open(path);
    if (!mounted || failure == null) return;
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(diaryFileOpenFailureMessage(context.l10n, failure)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final heifPath = _heifPath;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final title = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FaIcon(
          FontAwesomeIcons.image,
          size: 18,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            heifPath == null
                ? context.l10n.imageLoadFailed
                : context.l10n.imageHeifUnsupported,
            style: muted,
          ),
        ),
      ],
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 20, 16, heifPath == null ? 20 : 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.fromBorderSide(
          ExpressiveSurfaces.cardBorderSide(colors),
        ),
      ),
      child: heifPath == null
          ? title
          : Column(
              children: [
                title,
                const SizedBox(height: 6),
                Text(
                  context.l10n.imageHeifUnsupportedHint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                ListenableBuilder(
                  listenable: _opener,
                  builder: (context, _) => TextButton(
                    onPressed: _opener.isOpening ? null : () => _open(heifPath),
                    child: Text(context.l10n.imageOpenInOtherApp),
                  ),
                ),
              ],
            ),
    );
  }
}
