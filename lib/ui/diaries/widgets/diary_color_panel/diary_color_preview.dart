import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';

/// 所见即所得的预览：文字色写出“Aa”，背景色在纸面上叠出高亮、上面是正文
/// 墨色的“Aa”。颜色已在我的颜色里时，底部浮出一行“已保存”（`fast`，淡入
/// 并微微上移），“Aa”不随之移动。
class DiaryColorPreview extends StatelessWidget {
  const DiaryColorPreview({
    super.key,
    required this.color,
    required this.target,
    required this.saved,
  });

  final Color color;
  final DiaryColorTarget target;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = target == DiaryColorTarget.background;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: colors.outlineVariant),
    );
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: background ? colors.surface : colors.surfaceContainerHigh,
          shape: shape,
        ),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: background ? color : null,
            shape: shape,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Text(
                'Aa',
                style: TextStyle(
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: background ? colors.onSurface : color,
                ),
              ),
              Positioned(
                left: 4,
                right: 4,
                bottom: 7,
                child: _SavedMark(
                  visible: saved,
                  // 背景色预览上的字压在高亮上，用正文墨色；文字色预览在
                  // 中性底上，用次要墨色。
                  color: background
                      ? colors.onSurface
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// “已保存”一行：出现时淡入并从下方微微升起，消失时反向；隐藏后移出树
/// （读屏与查找都不会碰到看不见的字）。
class _SavedMark extends StatelessWidget {
  const _SavedMark({required this.visible, required this.color});

  final bool visible;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
      child: !visible
          ? const SizedBox(key: ValueKey<bool>(false), width: double.infinity)
          : Row(
              key: const ValueKey<bool>(true),
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FaIcon(FontAwesomeIcons.check, size: 8, color: color),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    context.l10n.diaryColorPanelSavedMark,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
