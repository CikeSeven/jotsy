import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/form_width.dart';
import '../../widgets/long_image/long_image_policy.dart';
import '../controllers/notebook_cover_crop_controller.dart';
import '../widgets/notebook_cover/notebook_cover_crop_viewport.dart';

/// 封面图取景页（全屏）：在与封面同为 3:4 的取景框里拖动平移、双指缩放
/// （桌面：鼠标拖动 + 滚轮缩放），底部另有缩放滑块。
///
/// 输入：封面图路径与当前封面样式；输出：点“完成”返回带新取景的样式，
/// 返回键或左上角返回为 null（不采用）。顶栏“重置”回到默认取景（居中、
/// 不放大）。只负责装配：图片尺寸的读取在这里（需要 context 解析图片），
/// 取景状态与手势换算在 [NotebookCoverCropController]。
class NotebookCoverCropPage extends StatefulWidget {
  const NotebookCoverCropPage({
    super.key,
    required this.coverPath,
    required this.style,
  });

  final String coverPath;
  final NotebookCoverStyle style;

  static Route<NotebookCoverStyle> route({
    required String coverPath,
    required NotebookCoverStyle style,
  }) {
    return MaterialPageRoute<NotebookCoverStyle>(
      builder: (_) => NotebookCoverCropPage(coverPath: coverPath, style: style),
    );
  }

  @override
  State<NotebookCoverCropPage> createState() => _NotebookCoverCropPageState();
}

class _NotebookCoverCropPageState extends State<NotebookCoverCropPage> {
  late final NotebookCoverCropController _controller =
      NotebookCoverCropController(widget.style);
  ImageProvider? _image;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    _handleImage,
    onError: _handleError,
  );
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_image != null) return;
    // 解码尺寸按屏幕长边的 2 倍：放大到 4 倍时框里只露出一小块，再大也
    // 看不出差别，长边 2 倍兼顾清晰与内存。只解析一次，旋转屏幕不重解。
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final image = boundedImageProvider(
      FileImage(File(widget.coverPath)),
      width: (size.longestSide * dpr * 2).round(),
    );
    _image = image;
    _stream = image.resolve(createLocalImageConfiguration(context))
      ..addListener(_listener);
  }

  void _handleImage(ImageInfo info, bool synchronousCall) {
    final image = info.image;
    final size = Size(image.width.toDouble(), image.height.toDouble());
    // 每个监听拿到的是独立的克隆，读完尺寸立即释放。
    info.dispose();
    if (!mounted) return;
    _controller.imageSize = size;
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    debugPrint('Notebook cover crop image failed: $error');
    if (mounted) setState(() => _failed = true);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final appBar = AppTopBar(
      contentMaxWidth: FormWidth.maxWidth,
      leading: IconButton(
        tooltip: l10n.commonBack,
        onPressed: () => Navigator.of(context).pop(),
        icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
      ),
      title: Text(l10n.notebookCoverAdjustCrop),
      actions: <Widget>[
        ListenableBuilder(
          listenable: _controller,
          builder: (BuildContext context, Widget? child) => TextButton(
            onPressed: _controller.canReset ? _controller.reset : null,
            child: Text(l10n.commonReset),
          ),
        ),
        TextButton(
          onPressed: _failed
              ? null
              : () => Navigator.of(context).pop(_controller.result),
          child: Text(l10n.notebookCoverCropDone),
        ),
      ],
    );
    final Widget viewport;
    if (_failed) {
      viewport = EmptyHint(
        icon: FontAwesomeIcons.image,
        message: l10n.notebookCoverCropLoadFailed,
      );
    } else {
      viewport = ListenableBuilder(
        listenable: _controller,
        builder: (BuildContext context, Widget? child) =>
            _controller.imageSize == null
            ? const DelayedLoadingIndicator()
            : child!,
        child: NotebookCoverCropViewport(
          controller: _controller,
          image: _image!,
        ),
      );
    }
    final controls = CenteredContent(
      maxWidth: FormWidth.maxWidth,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.s,
          AppSpacing.xxl,
          AppSpacing.l + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ZoomSlider(controller: _controller, enabled: !_failed),
            Text(
              AppPlatform.isDesktop
                  ? l10n.notebookCoverCropHintDesktop
                  : l10n.notebookCoverCropHint,
              textAlign: TextAlign.center,
              style: AppPageBackdrop.onBackgroundTextStyle(
                context,
                theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return AppPageBackground(
      area: AppBackgroundArea.other,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: appBar,
          body: Column(
            children: <Widget>[
              Expanded(child: viewport),
              controls,
            ],
          ),
        ),
      ),
    );
  }
}

/// 缩放滑块（1×–4×，以取景框中心缩放），两端为缩小 / 放大图标。
class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider({required this.controller, required this.enabled});

  final NotebookCoverCropController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = context.l10n.notebookCoverCropZoom;
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final ready = enabled && controller.imageSize != null;
        return Row(
          children: <Widget>[
            FaIcon(
              FontAwesomeIcons.magnifyingGlassMinus,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            Expanded(
              child: Slider(
                value: controller.crop.zoom,
                min: NotebookCoverStyle.minZoom,
                max: NotebookCoverStyle.maxZoom,
                semanticFormatterCallback: (double value) =>
                    '$label ${value.toStringAsFixed(1)}×',
                onChanged: ready ? controller.zoomTo : null,
              ),
            ),
            FaIcon(
              FontAwesomeIcons.magnifyingGlassPlus,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ],
        );
      },
    );
  }
}
