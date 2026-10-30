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
import 'app_surface_labels.dart';

/// 背景编辑器里“图片”类型的内容：两个分组——“图片”（缩略图与选图按钮）
/// 与“参数”（焦点取景器、模糊与浅色 / 深色遮罩三个滑块）。
///
/// 输入：编辑控制器与正在编辑的区域（null 为全局）；副作用：经控制器选图 /
/// 移除图片 / 写入焦点与滑块 / 切换跟随，失败时经 `showTrackedSnackBar`
/// 提示。
///
/// 区域（[area] 不为 null）的两个分组顶部各有一个跟随开关，跟随的是背景
/// 分组里所选的“跟随来源”：
/// - 图片跟随：缩略图换成来源当前显示的图片，选图 / 移除按钮收起；自己的
///   图片原样保存在设置里，关掉跟随即回来；
/// - 参数跟随：焦点、模糊与两档遮罩整块取自来源，取景器收起、滑块停用并
///   显示来源的值；不能逐项跟随。
/// 显示一律按“实际生效”的背景（`effectiveBackgroundOf`），编辑一律改自己
/// 的那一份（`backgroundOf`），跟随中的那一块不会被误写。
///
/// 文件名 → 文件 → 原图尺寸的解析是异步的，只在生效的文件名变化时重做一次
/// （拖动焦点、滑块不会重新读文件）；解析回来时文件名已经又换了就丢弃。
/// 文件已不存在时显示提示，设置原样保留（恢复备份后文件可能又回来）。
class AppSurfaceImageSection extends StatefulWidget {
  const AppSurfaceImageSection({
    super.key,
    required this.controller,
    required this.area,
  });

  final AppSurfaceEditorController controller;
  final AppBackgroundArea? area;

  @override
  State<AppSurfaceImageSection> createState() => _AppSurfaceImageSectionState();
}

/// 解析好的背景图：文件与原图尺寸（读不到尺寸时为 null，取景器不显示）。
typedef _ResolvedImage = ({File file, Size? size});

class _AppSurfaceImageSectionState extends State<AppSurfaceImageSection> {
  String? _name;
  _ResolvedImage? _resolved;
  bool _resolving = false;

  String? get _shownImage =>
      widget.controller.effectiveBackgroundOf(widget.area).image;

  @override
  void initState() {
    super.initState();
    _resolve(_shownImage);
  }

  @override
  void didUpdateWidget(AppSurfaceImageSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final name = _shownImage;
    if (name != _name) _resolve(name);
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
    final own = controller.backgroundOf(area);
    final shown = controller.effectiveBackgroundOf(area);
    final setting = area == null ? null : controller.style.areaOf(area);
    final followImage = setting?.followImage ?? false;
    final followParams = setting?.followParams ?? false;
    final sourceLabel = setting == null
        ? ''
        : appSurfaceSourceLabel(l10n, setting.source);
    final hasImage = shown.image != null;
    final resolved = _resolved;
    final missing = hasImage && !_resolving && resolved == null;
    void preview(AppBackground next) =>
        controller.previewBackgroundOf(area, next);
    void commit(AppBackground next) => controller.commitBackground(area, next);
    final size = resolved?.size;
    final editParams = !followParams;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 16),
        SettingsCardGroup(
          title: l10n.appSurfaceImageGroup,
          children: <Widget>[
            if (area != null)
              SettingsSwitchTile(
                key: const ValueKey<String>('appSurfaceFollowImage'),
                title: l10n.appSurfaceFollowImage(sourceLabel),
                value: followImage,
                onChanged: (bool v) => controller.commitFollowImage(area, v),
              ),
            _ImageRow(
              file: resolved?.file,
              hasImage: hasImage,
              missing: missing,
              picking: controller.picking,
              followNote: !followImage
                  ? null
                  : hasImage
                  ? l10n.appSurfaceFollowImageNote(sourceLabel)
                  : l10n.appSurfaceFollowImageNone(sourceLabel),
              onPick: _pick,
              onRemove: () => controller.removeImage(area),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          title: l10n.appSurfaceParamsGroup,
          children: <Widget>[
            if (area != null)
              SettingsSwitchTile(
                key: const ValueKey<String>('appSurfaceFollowParams'),
                title: l10n.appSurfaceFollowParams(sourceLabel),
                subtitle: l10n.appSurfaceFollowParamsHint,
                value: followParams,
                onChanged: (bool v) => controller.commitFollowParams(area, v),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 跟随时焦点取自来源，取景器没有可改的东西，整行收起。
                if (editParams && resolved != null && size != null) ...<Widget>[
                  SettingsChoiceTile(
                    title: l10n.appSurfaceFocus,
                    subtitle: l10n.appSurfaceFocusHint,
                    child: AppSurfaceFocusViewfinder(
                      file: resolved.file,
                      imageSize: size,
                      alignX: own.alignX,
                      alignY: own.alignY,
                      onPreview: (double x, double y) =>
                          preview(own.copyWith(alignX: x, alignY: y)),
                      onCommit: (double x, double y) =>
                          commit(own.copyWith(alignX: x, alignY: y)),
                    ),
                  ),
                  const SettingsCardGroupDivider(),
                ],
                appSurfaceSlider(
                  title: l10n.appSurfaceBlur,
                  range: AppSurfaceLimits.blur,
                  value: shown.blur,
                  enabled: editParams,
                  valueLabel: (double v) => '${v.round()}',
                  onPreview: (double v) => preview(own.copyWith(blur: v)),
                  onCommit: (double v) => commit(own.copyWith(blur: v)),
                ),
                const SettingsCardGroupDivider(),
                appSurfaceSlider(
                  title: l10n.appSurfaceScrimLight,
                  range: AppSurfaceLimits.scrim,
                  value: shown.scrimLight,
                  enabled: editParams,
                  valueLabel: (double v) => appSurfacePercentLabel(l10n, v),
                  onPreview: (double v) => preview(own.copyWith(scrimLight: v)),
                  onCommit: (double v) => commit(own.copyWith(scrimLight: v)),
                ),
                const SettingsCardGroupDivider(),
                appSurfaceSlider(
                  title: l10n.appSurfaceScrimDark,
                  range: AppSurfaceLimits.scrim,
                  value: shown.scrimDark,
                  enabled: editParams,
                  valueLabel: (double v) => appSurfacePercentLabel(l10n, v),
                  onPreview: (double v) => preview(own.copyWith(scrimDark: v)),
                  onCommit: (double v) => commit(own.copyWith(scrimDark: v)),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// 缩略图 + 说明 + 按钮（没有图时“选择图片”，有图时“移除”“更换”）。选图
/// 进行中按钮内显示等待并禁用，防止重复打开选择器。图片跟随来源时
/// （[followNote] 不为 null）只显示来源的图片与这句说明，不显示按钮。
class _ImageRow extends StatelessWidget {
  const _ImageRow({
    required this.file,
    required this.hasImage,
    required this.missing,
    required this.picking,
    required this.followNote,
    required this.onPick,
    required this.onRemove,
  });

  static const double _thumb = 56;

  final File? file;
  final bool hasImage;
  final bool missing;
  final bool picking;

  /// 图片跟随来源时的说明；null 为用自己的图片。
  final String? followNote;
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
    final followNote = this.followNote;
    final following = followNote != null;
    final note =
        followNote ??
        (!hasImage
            ? l10n.appSurfaceImageEmpty
            : (missing ? l10n.appSurfaceImageMissing : null));
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
                      color: missing && !following
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
          ),
          if (hasImage && !following) ...<Widget>[
            TextButton(
              onPressed: picking ? null : onRemove,
              child: Text(l10n.appSurfaceImageRemove),
            ),
            const SizedBox(width: 4),
          ],
          if (!following)
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
