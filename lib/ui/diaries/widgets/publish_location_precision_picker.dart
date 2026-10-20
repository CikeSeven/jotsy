import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/app_radii.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';

/// 位置输入下方的地址层级入口：输入当前层级、地点输入框与自动定位的地址
/// 组件，输出用户选择；只管理菜单开合，选择由页面控制器保存。
///
/// 选项放在菜单浮层而不是面板内展开：5 个层级在手机宽度下只能纵向堆叠，
/// 展开会把天气等字段整体推走约 260dp。菜单里每项预览选择后的地址，
/// 但只在地点仍是自动文案时预览——手动填写的地点不会被层级改写，此时
/// 预览只会误导。
class PublishLocationPrecisionPicker extends StatefulWidget {
  const PublishLocationPrecisionPicker({
    super.key,
    required this.precision,
    required this.locationController,
    required this.addressComponent,
    required this.onChanged,
  });

  final DiaryLocationPrecision precision;
  final TextEditingController locationController;

  /// 自动定位得到、且仍会随 metadata 保存的地址组件；未定位或已清空地点时
  /// 为 null。
  final Map<String, Object?>? addressComponent;
  final ValueChanged<DiaryLocationPrecision>? onChanged;

  @override
  State<PublishLocationPrecisionPicker> createState() =>
      _PublishLocationPrecisionPickerState();
}

class _PublishLocationPrecisionPickerState
    extends State<PublishLocationPrecisionPicker> {
  /// 选项文字列的最大宽度；窄屏时再按面板宽度收窄。
  static const double _menuContentMaxWidth = 216;

  /// 菜单在文字列之外的固定宽度：菜单内边距 16 + 选项内边距 24 + 勾选图标
  /// 16 + 图标与文字间距 12。
  static const double _menuChromeWidth = 68;

  bool _menuOpen = false;

  /// 菜单关闭时焦点交还给入口按钮。
  final FocusNode _triggerFocus = FocusNode(
    debugLabel: 'PublishLocationPrecisionPicker',
  );

  @override
  void dispose() {
    _triggerFocus.dispose();
    super.dispose();
  }

  static String _label(
    AppLocalizations l10n,
    DiaryLocationPrecision precision,
  ) => switch (precision) {
    DiaryLocationPrecision.city => l10n.locationPrecisionCity,
    DiaryLocationPrecision.district => l10n.locationPrecisionDistrict,
    DiaryLocationPrecision.township => l10n.locationPrecisionTownship,
    DiaryLocationPrecision.street => l10n.locationPrecisionStreet,
    DiaryLocationPrecision.address => l10n.locationPrecisionAddress,
  };

  /// 菜单在页面销毁时也会关闭，回调晚于 dispose 时不能再 setState。
  void _setMenuOpen(bool open) {
    if (mounted && _menuOpen != open) setState(() => _menuOpen = open);
  }

  @override
  Widget build(BuildContext context) {
    // 输入框逐字变化不会让页面重建；在这里监听，菜单预览才跟得上手动修改。
    return ListenableBuilder(
      listenable: widget.locationController,
      builder: (context, _) {
        final previewComponents =
            DiaryLocationLabel.isAutoLabel(
              widget.locationController.text,
              widget.addressComponent,
              widget.precision,
            )
            ? widget.addressComponent
            : null;
        // 菜单从入口左缘展开；宽度不超过面板内容宽度，320dp 屏宽下也不会
        // 伸出面板贴到屏幕边缘，放不下的预览以省略号截断。
        return LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = (constraints.maxWidth - _menuChromeWidth)
                .clamp(120.0, _menuContentMaxWidth);
            return Align(
              alignment: AlignmentDirectional.centerStart,
              child: ExpressiveMenuAnchor(
                placement: ExpressiveMenuPlacement.start,
                childFocusNode: _triggerFocus,
                onOpen: () => _setMenuOpen(true),
                onClose: () => _setMenuOpen(false),
                menuChildren: [
                  for (final precision in DiaryLocationPrecision.values)
                    _buildOption(
                      context,
                      precision,
                      previewComponents,
                      contentWidth,
                    ),
                ],
                builder: (context, menu, _) => _buildTrigger(context, menu),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrigger(BuildContext context, ExpressiveMenuAnchorState menu) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final enabled = widget.onChanged != null;
    return Semantics(
      expanded: _menuOpen,
      child: TextButton(
        focusNode: _triggerFocus,
        onPressed: enabled ? menu.toggle : null,
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          textStyle: theme.textTheme.labelMedium,
          minimumSize: const Size(0, 36),
          // 左侧 12 与上方输入框内边距一致，图标和文字与定位行对齐。
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 10, 0),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              child: Center(
                child: FaIcon(FontAwesomeIcons.layerGroup, size: 12),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                l10n.locationPrecisionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Text(' · '),
            Flexible(
              child: Text(
                _label(l10n, widget.precision),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // 禁用时不指定颜色，沿用按钮的禁用前景色。
                style: TextStyle(
                  color: enabled ? theme.colorScheme.primary : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: _menuOpen ? 0.5 : 0,
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.fast,
              ),
              curve: ExpressiveMotion.effects,
              child: const FaIcon(FontAwesomeIcons.angleDown, size: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    DiaryLocationPrecision precision,
    Map<String, Object?>? previewComponents,
    double contentWidth,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = precision == widget.precision;
    final onChanged = widget.onChanged;
    final preview = DiaryLocationLabel.format(previewComponents, precision);
    // 选中项只换容器色（与菜单项选中态同为 primaryContainer）和字重，文字
    // 保持 onSurface：部分配色下容器的 on 色偏浅，会让选中项看起来比其他项更弱。
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: ExpressiveMenuItem(
        onPressed: onChanged == null ? null : () => onChanged(precision),
        // 层级选项带预览，保留自己的行首主色勾、内边距与 16 圆角，覆盖菜单项
        // 默认样式（不用 selected：行尾不要对勾，语义由外层 Semantics 给出）。
        style: MenuItemButton.styleFrom(
          backgroundColor: selected ? colors.primaryContainer : null,
          foregroundColor: colors.onSurface,
          iconColor: colors.primary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.input),
          ),
        ),
        leadingIcon: SizedBox(
          width: 16,
          child: selected
              ? const FaIcon(FontAwesomeIcons.check, size: 14)
              : null,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _label(context.l10n, precision),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (preview != null)
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
