import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/mind_map/mind_map_rich_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/diary_material_colors.dart';
import '../../diaries/models/diary_text_colors.dart';
import '../../diaries/providers/diary_saved_colors_provider.dart';
import '../../diaries/widgets/diary_color_panel/diary_color_host.dart';
import '../../diaries/widgets/diary_color_panel/diary_color_panel.dart';
import '../controllers/mind_map_editing_controller.dart';
import '../controllers/mind_map_rich_text_controller.dart';
import '../viewmodels/mind_map_text_colors.dart';

/// 编辑主题文字时的格式条（一行 [height] 高）：粗体、斜体、下划线、删除线
/// | 文字颜色、高亮。手机上是键盘附件条的上一行，桌面上编辑时替换底部的
/// 工具坞。
///
/// - 作用对象是 [MindMapEditingController.textSession] 里正在编辑的输入框：
///   有选区时改选中的字，没有时设“接下来打的字”的样式（见
///   [MindMapRichTextController]）；按钮状态随选区实时刷新；
/// - 两个颜色按钮在按钮行之上展开正文同款的颜色面板 [DiaryColorPanel]
///   （色板 + 我的颜色、色系、自定义），颜色按原色写入；两个按钮就是目标
///   切换，再点一次收起。面板不走路由或对话框，键盘与输入框的焦点都不动；
///   自定义页的颜色代码输入框拿走焦点时，输入框不结束编辑（焦点在
///   [MindMapTextSession.toolbarFocus] 之内），应用后焦点还给输入框；
/// - 面板高度经 [MindMapTextSession.setPanelExtent] 报给画布，正在编辑的
///   节点一并让开；
/// - 整条包在 [TextFieldTapRegion] 里：桌面上用鼠标点它不会让输入框失焦
///   （手机上触摸本就不会）。
class MindMapFormatBar extends ConsumerStatefulWidget {
  const MindMapFormatBar({super.key, required this.controller});

  /// 按钮行的高度。
  static const double height = 44;

  /// 面板与上边、按钮行之间的留白。
  static const double _panelTopGap = 8;
  static const double _panelBottomGap = 4;

  /// 面板左右的留白。
  static const double _panelInset = 8;

  final MindMapEditingController controller;

  @override
  ConsumerState<MindMapFormatBar> createState() => _MindMapFormatBarState();
}

class _MindMapFormatBarState extends ConsumerState<MindMapFormatBar> {
  /// 颜色面板正在编辑的目标；null 为收起。
  DiaryColorTarget? _target;
  DiaryColorPanelMode _mode = DiaryColorPanelMode.swatches;
  DiaryMaterialFamily _family = DiaryMaterialFamily.red;
  List<Color> _documentColors = const <Color>[];
  double _reportedExtent = 0;

  MindMapTextSession get _session => widget.controller.textSession;

  @override
  void dispose() {
    if (_reportedExtent != 0) _session.setPanelExtent(0);
    super.dispose();
  }

  void _toggle(DiaryColorTarget target) {
    setState(() {
      if (_target == target) {
        _target = null;
      } else {
        _target = target;
        _scanDocumentColors();
      }
    });
  }

  void _scanDocumentColors() {
    final target = _target;
    if (target == null) return;
    _documentColors = mindMapDocumentColors(widget.controller.document, target);
  }

  void _onModeChanged(DiaryColorPanelMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      // 回到色板时把刚在色系页或自定义页用过的颜色排进来。
      if (mode == DiaryColorPanelMode.swatches) _scanDocumentColors();
    });
  }

  void _report(double extent) {
    if (extent == _reportedExtent) return;
    _reportedExtent = extent;
    _session.setPanelExtent(extent);
  }

  @override
  Widget build(BuildContext context) {
    return TextFieldTapRegion(
      child: Focus(
        focusNode: _session.toolbarFocus,
        child: ListenableBuilder(
          listenable: _session,
          builder: (BuildContext context, Widget? _) {
            final text = _session.current;
            if (text == null) {
              _report(0);
              return _buttons(null);
            }
            return ListenableBuilder(
              listenable: text,
              builder: (BuildContext context, Widget? _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AnimatedSize(
                    duration: ExpressiveMotion.duration(
                      context,
                      ExpressiveMotion.medium,
                    ),
                    curve: ExpressiveMotion.spatial,
                    alignment: Alignment.bottomCenter,
                    child: _panel(text),
                  ),
                  _buttons(text),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _panel(MindMapRichTextController text) {
    final target = _target;
    if (target == null) {
      _report(0);
      return const SizedBox(width: double.infinity);
    }
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final grid = DiaryColorGridLayout.resolve(
          innerWidth: constraints.maxWidth - 2 * MindMapFormatBar._panelInset,
        );
        final body = diaryColorPanelNaturalHeight(_mode, grid);
        _report(
          body +
              MindMapFormatBar._panelTopGap +
              MindMapFormatBar._panelBottomGap,
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            MindMapFormatBar._panelInset,
            MindMapFormatBar._panelTopGap,
            MindMapFormatBar._panelInset,
            MindMapFormatBar._panelBottomGap,
          ),
          child: DiaryColorPanel(
            host: _RichTextColorHost(text),
            target: target,
            title: target == DiaryColorTarget.text
                ? l10n.mindMapTextColor
                : l10n.mindMapHighlight,
            mode: _mode,
            onModeChanged: _onModeChanged,
            grid: grid,
            savedColors: ref.watch(diarySavedColorsProvider).forTarget(target),
            documentColors: _documentColors,
            bodyHeight: body,
            active: true,
            onEditSavedColors: ref.read(diarySavedColorsProvider.notifier).edit,
            materialFamily: _family,
            onMaterialFamilyChanged: (DiaryMaterialFamily family) =>
                _family = family,
          ),
        );
      },
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
    Widget color(FaIconData icon, String label, DiaryColorTarget target) {
      final value = parseDiaryColorValue(
        text?.colorOf(mindMapColorMarkOf(target)),
      );
      return _FormatButton(
        icon: icon,
        label: label,
        selected: _target == target,
        indicator: value ?? scheme.outlineVariant,
        onTap: text == null ? null : () => _toggle(target),
      );
    }

    return SizedBox(
      height: MindMapFormatBar.height,
      child: Row(
        children: <Widget>[
          toggle(FontAwesomeIcons.bold, l10n.mindMapBold, MindMapMark.bold),
          toggle(
            FontAwesomeIcons.italic,
            l10n.mindMapItalic,
            MindMapMark.italic,
          ),
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
            DiaryColorTarget.text,
          ),
          color(
            FontAwesomeIcons.highlighter,
            l10n.mindMapHighlight,
            DiaryColorTarget.background,
          ),
        ],
      ),
    );
  }
}

/// 颜色面板作用在正在编辑的主题文字上：有选区时改选中的字，没有时设接下来
/// 打的字（见 [MindMapRichTextController.setColor]）。按输入框判等，每次
/// 构建新建一个也不会让面板重新订阅。
final class _RichTextColorHost implements DiaryColorHost {
  const _RichTextColorHost(this.text);

  final MindMapRichTextController text;

  @override
  DiaryColorValue colorValue(DiaryColorTarget target) =>
      DiaryColorValue.parse(text.colorOf(mindMapColorMarkOf(target)));

  @override
  void applyColor(DiaryColorTarget target, Color? color) => text.setColor(
    mindMapColorMarkOf(target),
    color == null ? null : encodeDiaryColor(color),
  );

  @override
  Object? get selectionToken => text.selection;

  @override
  void addListener(VoidCallback listener) => text.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => text.removeListener(listener);

  @override
  bool operator ==(Object other) =>
      other is _RichTextColorHost && identical(other.text, text);

  @override
  int get hashCode => identityHashCode(text);
}

/// 格式条上的一格：开着的开关（或展开着面板的颜色按钮）铺次要容器色；
/// 颜色按钮在图标下画一条当前颜色 [indicator]。
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
          selected: indicator == null ? null : selected,
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
