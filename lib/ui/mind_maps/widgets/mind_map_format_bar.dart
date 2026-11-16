import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/mind_map/mind_map_rich_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../controllers/mind_map_editing_controller.dart';
import '../controllers/mind_map_rich_text_controller.dart';
import '../viewmodels/mind_map_palette.dart';
import '../viewmodels/mind_map_visuals.dart';
import 'mind_map_color_swatches.dart';

/// 编辑主题文字时的格式条（一行 [height] 高）：粗体、斜体、下划线、删除线
/// | 文字颜色、高亮。手机上是键盘附件条的上一行，桌面上编辑时替换底部的
/// 工具坞。
///
/// - 作用对象是 [MindMapEditingController.textSession] 里正在编辑的输入框：
///   有选区时改选中的字，没有时设“接下来打的字”的样式（见
///   [MindMapRichTextController]）；按钮状态随选区实时刷新；
/// - 点颜色按钮时这一行在原地换成色块（返回 + 默认 + 色块横向滚动），选色
///   后留在色块行，可以接着换；不走对话框或面板，焦点与键盘都不动；
/// - 整条包在 [TextFieldTapRegion] 里：桌面上用鼠标点它不会让输入框失焦
///   （手机上触摸本就不会）。
class MindMapFormatBar extends StatefulWidget {
  const MindMapFormatBar({
    super.key,
    required this.controller,
    required this.palette,
  });

  /// 一行的高度。
  static const double height = 44;

  final MindMapEditingController controller;

  /// 当前导图的配色：色块与颜色按钮的指示条按它换算。
  final MindMapPalette palette;

  @override
  State<MindMapFormatBar> createState() => _MindMapFormatBarState();
}

class _MindMapFormatBarState extends State<MindMapFormatBar> {
  /// 正在挑哪种颜色；null 为显示格式按钮。
  MindMapColorMark? _picking;

  MindMapBranchColors _preview(MindMapColorMark mark, Color seed) {
    final colors = widget.palette.custom(seed);
    // 高亮显示容器色（字后面实际铺的颜色），文字色显示强调色。
    return mark == MindMapColorMark.highlight
        ? MindMapBranchColors(
            accent: colors.container,
            onAccent: colors.onContainer,
            container: colors.container,
            onContainer: colors.onContainer,
          )
        : colors;
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.textSession;
    return TextFieldTapRegion(
      child: SizedBox(
        height: MindMapFormatBar.height,
        child: ListenableBuilder(
          listenable: session,
          builder: (BuildContext context, Widget? _) {
            final text = session.current;
            if (text == null) return _buttons(null);
            return ListenableBuilder(
              listenable: text,
              builder: (BuildContext context, Widget? _) {
                final picking = _picking;
                return AnimatedSwitcher(
                  duration: ExpressiveMotion.duration(
                    context,
                    ExpressiveMotion.fast,
                  ),
                  switchInCurve: ExpressiveMotion.effects,
                  switchOutCurve: ExpressiveMotion.exit,
                  child: picking == null
                      ? _buttons(text)
                      : _swatches(text, picking),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buttons(MindMapRichTextController? text) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    Widget toggle(FaIconData icon, String label, MindMapMark mark) =>
        _FormatButton(
          icon: icon,
          label: label,
          selected: text?.isActive(mark) ?? false,
          onTap: text == null ? null : () => text.toggle(mark),
        );
    Color indicator(MindMapColorMark mark) {
      final seed = MindMapNodeStyle.parseColor(text?.colorOf(mark));
      if (seed == null) return scheme.outlineVariant;
      return _preview(mark, seed).accent;
    }

    Widget color(FaIconData icon, String label, MindMapColorMark mark) =>
        _FormatButton(
          icon: icon,
          label: label,
          indicator: indicator(mark),
          onTap: text == null ? null : () => setState(() => _picking = mark),
        );
    return Row(
      key: const ValueKey<String>('mind-map-format-buttons'),
      children: <Widget>[
        toggle(FontAwesomeIcons.bold, l10n.mindMapBold, MindMapMark.bold),
        toggle(FontAwesomeIcons.italic, l10n.mindMapItalic, MindMapMark.italic),
        toggle(
          FontAwesomeIcons.underline,
          l10n.mindMapUnderline,
          MindMapMark.underline,
        ),
        toggle(
          FontAwesomeIcons.strikethrough,
          l10n.mindMapStrike,
          MindMapMark.strike,
        ),
        Container(
          width: 1,
          height: 20,
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
        color(
          FontAwesomeIcons.font,
          l10n.mindMapTextColor,
          MindMapColorMark.color,
        ),
        color(
          FontAwesomeIcons.highlighter,
          l10n.mindMapHighlight,
          MindMapColorMark.highlight,
        ),
      ],
    );
  }

  Widget _swatches(MindMapRichTextController text, MindMapColorMark mark) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final current = MindMapNodeStyle.parseColor(text.colorOf(mark));
    void pick(Color? seed) => text.setColor(
      mark,
      seed == null ? null : MindMapNodeStyle.encodeColor(seed),
    );
    return Row(
      key: ValueKey<MindMapColorMark>(mark),
      children: <Widget>[
        Tooltip(
          message: l10n.commonBack,
          child: InkResponse(
            onTap: () => setState(() => _picking = null),
            radius: 20,
            child: SizedBox(
              width: 44,
              height: MindMapFormatBar.height,
              child: Center(
                child: FaIcon(
                  FontAwesomeIcons.angleLeft,
                  size: 16,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: FaIcon(
            mark == MindMapColorMark.color
                ? FontAwesomeIcons.font
                : FontAwesomeIcons.highlighter,
            size: 13,
            color: scheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: DesktopHorizontalScroll(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(end: 8),
              children: <Widget>[
                for (final seed in <Color?>[
                  null,
                  for (final value in kMindMapColorSeeds) Color(value),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      child: MindMapColorSwatch(
                        seed: seed,
                        size: 28,
                        active: seed == null
                            ? current == null
                            : current?.toARGB32() == seed.toARGB32(),
                        preview: (c) => _preview(mark, c),
                        onTap: () => pick(seed),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 格式条上的一格：开关按钮选中时铺次要容器色；颜色按钮在图标下画一条
/// 当前颜色 [indicator]。
class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.indicator,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final Color? indicator;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final ink = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : selected
        ? scheme.onSecondaryContainer
        : scheme.onSurface;
    return Expanded(
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          toggled: indicator == null ? selected : null,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: AnimatedContainer(
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.fast,
                ),
                curve: ExpressiveMotion.effects,
                width: 36,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.secondaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    FaIcon(icon, size: 15, color: ink),
                    if (indicator case final color?) ...<Widget>[
                      const SizedBox(height: 3),
                      Container(
                        width: 16,
                        height: 3,
                        decoration: BoxDecoration(
                          color: enabled
                              ? color
                              : color.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
