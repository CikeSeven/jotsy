import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/services/image_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/models/app_surface_settings.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../widgets/expressive_image_frame.dart';
import '../../../widgets/expressive_loading_indicator.dart';
import '../../../widgets/long_image/long_image_policy.dart';
import '../../controllers/app_surface_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import 'app_surface_common.dart';
import 'app_surface_focus_viewfinder.dart';

/// 背景编辑器里“图片”类型的内容：缩略图与选图按钮、焦点取景器、模糊与
/// 浅色 / 深色遮罩三个滑块。
///
/// 输入：编辑控制器、正在编辑的区域（null 为全局）与它当前的背景；副作用：
/// 经控制器选图 / 移除图片 / 写入焦点与滑块，失败时经
/// `showTrackedSnackBar` 提示。
///
/// 文件名 → 文件 → 原图尺寸的解析是异步的，只在文件名变化时重做一次
/// （拖动焦点、滑块不会重新读文件）；解析回来时文件名已经又换了就丢弃。
/// 文件已不存在时显示提示，设置原样保留（恢复备份后文件可能又回来）。
class AppSurfaceImageSection extends StatefulWidget {
  const AppSurfaceImageSection({
    super.key,
    required this.controller,
    required this.area,
    required this.background,
  });

  final AppSurfaceEditorController controller;
  final AppBackgroundArea? area;
  final AppBackground background;

  @override
  State<AppSurfaceImageSection> createState() => _AppSurfaceImageSectionState();
}

/// 解析好的背景图：文件与原图尺寸（读不到尺寸时为 null，取景器不显示）。
typedef _ResolvedImage = ({File file, Size? size});

class _AppSurfaceImageSectionState extends State<AppSurfaceImageSection> {
  String? _name;
  _ResolvedImage? _resolved;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _resolve(widget.background.image);
  }

  @override
  void didUpdateWidget(AppSurfaceImageSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.background.image != _name) _resolve(widget.background.image);
  }

  Future<void> _resolve(String? name) async {
    _name = name;
    _resolved = null;
    if (name == null) {
      _resolving = false;
      return;
    }
    _resolving = true;
    _ResolvedImage? resolved;
    try {
      final file = await widget.controller.resolveImage(name);
      if (file != null) {
        resolved = (file: file, size: await ImageDimensions.resolve(file.path));
      }
    } catch (error) {
      debugPrint('App background preview resolve failed: $error');
    }
    if (!mounted || _name != name) return;
    setState(() {
      _resolved = resolved;
      _resolving = false;
    });
  }

  Future<void> _pick() async {
    final l10n = context.l10n;
    final status = await widget.controller.pickImage(widget.area);
    if (!mounted) return;
    final message = switch (status) {
      AppSurfaceImagePickStatus.unavailable => l10n.appSurfaceImageUnavailable,
      AppSurfaceImagePickStatus.failed => l10n.appSurfaceImageImportFailed,
      _ => null,
    };
    if (message != null) showStyleEditorMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    final area = widget.area;
    final background = widget.background;
    final hasImage = background.image != null;
    final resolved = _resolved;
    final missing = hasImage && !_resolving && resolved == null;
    void preview(AppBackground next) =>
        controller.previewBackgroundOf(area, next);
    void commit(AppBackground next) => controller.commitBackground(area, next);
    final size = resolved?.size;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ImageRow(
          file: resolved?.file,
          hasImage: hasImage,
          missing: missing,
          picking: controller.picking,
          onPick: _pick,
          onRemove: () => controller.removeImage(area),
        ),
        if (resolved != null && size != null) ...<Widget>[
          const SettingsCardGroupDivider(),
          SettingsChoiceTile(
            title: l10n.appSurfaceFocus,
            subtitle: l10n.appSurfaceFocusHint,
            child: AppSurfaceFocusViewfinder(
              file: resolved.file,
              imageSize: size,
              alignX: background.alignX,
              alignY: background.alignY,
              onPreview: (double x, double y) =>
                  preview(background.copyWith(alignX: x, alignY: y)),
              onCommit: (double x, double y) =>
                  commit(background.copyWith(alignX: x, alignY: y)),
            ),
          ),
        ],
        const SettingsCardGroupDivider(),
        appSurfaceSlider(
          title: l10n.appSurfaceBlur,
          range: AppSurfaceLimits.blur,
          value: background.blur,
          valueLabel: (double v) => '${v.round()}',
          onPreview: (double v) => preview(background.copyWith(blur: v)),
          onCommit: (double v) => commit(background.copyWith(blur: v)),
        ),
        const SettingsCardGroupDivider(),
        appSurfaceSlider(
          title: l10n.appSurfaceScrimLight,
          range: AppSurfaceLimits.scrim,
          value: background.scrimLight,
          valueLabel: (double v) => appSurfacePercentLabel(l10n, v),
          onPreview: (double v) => preview(background.copyWith(scrimLight: v)),
          onCommit: (double v) => commit(background.copyWith(scrimLight: v)),
        ),
        const SettingsCardGroupDivider(),
        appSurfaceSlider(
          title: l10n.appSurfaceScrimDark,
          range: AppSurfaceLimits.scrim,
          value: background.scrimDark,
          valueLabel: (double v) => appSurfacePercentLabel(l10n, v),
          onPreview: (double v) => preview(background.copyWith(scrimDark: v)),
          onCommit: (double v) => commit(background.copyWith(scrimDark: v)),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// 缩略图 + 说明 + 按钮（没有图时“选择图片”，有图时“移除”“更换”）。选图
/// 进行中按钮内显示等待并禁用，防止重复打开选择器。
class _ImageRow extends StatelessWidget {
  const _ImageRow({
    required this.file,
    required this.hasImage,
    required this.missing,
    required this.picking,
    required this.onPick,
    required this.onRemove,
  });

  static const double _thumb = 56;

  final File? file;
  final bool hasImage;
  final bool missing;
  final bool picking;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final file = this.file;
    final extent = (_thumb * dpr).ceil();
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: _thumb,
        child: file == null
            ? ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.image,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            : Image(
                image: boundedImageProvider(
                  FileImage(file),
                  width: extent,
                  height: extent,
                ),
                fit: BoxFit.cover,
                frameBuilder: expressiveImageFrameBuilder,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: scheme.surfaceContainerHighest),
              ),
      ),
    );
    final note = !hasImage
        ? l10n.appSurfaceImageEmpty
        : (missing ? l10n.appSurfaceImageMissing : null);
    final pickLabel = hasImage
        ? l10n.appSurfaceImageChange
        : l10n.appSurfaceImagePick;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: <Widget>[
          thumbnail,
          const SizedBox(width: 12),
          Expanded(
            child: note == null
                ? const SizedBox.shrink()
                : Text(
                    note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: missing ? scheme.error : scheme.onSurfaceVariant,
                    ),
                  ),
          ),
          if (hasImage) ...<Widget>[
            TextButton(
              onPressed: picking ? null : onRemove,
              child: Text(l10n.appSurfaceImageRemove),
            ),
            const SizedBox(width: 4),
          ],
          FilledButton.tonal(
            onPressed: picking ? null : onPick,
            style: AppGlassField.tonalButtonStyle(context),
            child: picking
                ? const ExpressiveLoadingIndicator(size: 20)
                : Text(pickLabel),
          ),
        ],
      ),
    );
  }
}
