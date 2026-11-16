import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../controllers/diary_editor_controller.dart';

/// 新建空白日记的页头里“思维导图”小按钮：正文还没写东西时出现，点按把
/// 这篇日记变成一张导图（[onPressed] 收到按钮的全局矩形，画布从这里展开）。
/// 开始写正文后随之收起（只监听正文控制器，不牵动整页重建）。
class DiaryMindMapEntryChip extends StatelessWidget {
  const DiaryMindMapEntryChip({
    super.key,
    required this.content,
    required this.onPressed,
  });

  final DiaryEditorController content;
  final ValueChanged<Rect?> onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: content,
      builder: (BuildContext context, Widget? _) {
        final visible = !content.hasContent;
        return AnimatedSize(
          duration: ExpressiveMotion.durationNonZero(
            context,
            ExpressiveMotion.medium,
          ),
          curve: ExpressiveMotion.effects,
          alignment: Alignment.topLeft,
          child: !visible
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Builder(
                      builder: (BuildContext context) => Tooltip(
                        message: l10n.mindMapCreateChipTooltip,
                        child: FilledButton.tonalIcon(
                          style:
                              (AppGlassField.tonalButtonStyle(context) ??
                                      const ButtonStyle())
                                  .copyWith(
                                    visualDensity: VisualDensity.compact,
                                    textStyle:
                                        WidgetStatePropertyAll<TextStyle?>(
                                          theme.textTheme.labelLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                  ),
                          onPressed: () {
                            final box = context.findRenderObject();
                            onPressed(
                              box is RenderBox && box.hasSize
                                  ? box.localToGlobal(Offset.zero) & box.size
                                  : null,
                            );
                          },
                          icon: const FaIcon(
                            FontAwesomeIcons.sitemap,
                            size: 13,
                          ),
                          label: Text(l10n.mindMapCreateChip),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
