import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../controllers/home_bar_style_editor_controller.dart';

/// 预览工具条：只有预览明暗切换（导航栏没有需要在预览里切换的布局）。
class HomeBarStylePreviewToolbar extends StatelessWidget {
  const HomeBarStylePreviewToolbar({super.key, required this.controller});

  final HomeBarStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brightness =
        controller.previewBrightness ?? Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: <Widget>[
          const Spacer(),
          IconButton.filledTonal(
            style: AppGlassField.tonalButtonStyle(context),
            tooltip: isLight
                ? l10n.styleEditorPreviewDark
                : l10n.styleEditorPreviewLight,
            onPressed: () => controller.previewBrightness = isLight
                ? Brightness.dark
                : Brightness.light,
            icon: FaIcon(
              isLight ? FontAwesomeIcons.moon : FontAwesomeIcons.sun,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}
