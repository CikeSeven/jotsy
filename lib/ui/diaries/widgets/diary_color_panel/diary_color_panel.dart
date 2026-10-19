import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_hex_input.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_swatch.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_swatch_grid.dart';

/// 表头一行的高度：与工具栏 40dp 一格同高，放得下 36dp 的颜色代码胶囊与
/// 输入模式里 40dp 的输入框、取消 / 应用按钮。
const double kDiaryColorPanelHeaderHeight = 40;

/// 表头与色块网格之间的间距。
const double kDiaryColorPanelHeaderGap = 4;

/// 颜色面板内容的自然高度：表头 + 间距 + 网格行。工具栏据此直接算出面板
/// 目标高度，不必等测量。
double diaryColorPanelNaturalHeight(DiaryColorGridLayout grid) =>
    kDiaryColorPanelHeaderHeight + kDiaryColorPanelHeaderGap + grid.height;

/// 悬浮工具栏卡片内的颜色面板：表头（目标标题 + 颜色代码）与色块网格。
///
/// - 输入：正文控制器、当前目标、网格排布与这篇日记用过的自定义颜色（由工具
///   栏在面板打开、切换目标与应用颜色代码后各扫描一次，这里不扫描文档）；
/// - 输出：经 `controller.formatSelection` 写入 `#AARRGGBB` 或清除属性；
///   [onCustomColorApplied] 请工具栏重新扫描；
/// - 面板里不放文字 / 背景切换：工具栏上的两个颜色按钮就是切换，点另一个时
///   面板保持打开、色块原地变色，表头标题随之交叉淡入；
/// - 不走路由、对话框或底部面板：那些都会抢走正文焦点、收起键盘，而工具栏
///   跟着键盘显示，会连同面板一起消失。
///
/// 输入模式的焦点交接：进入时记下当前的焦点（正文编辑器），把焦点交给颜色
/// 代码输入框——同一帧里旧输入连接关闭、新连接接上，Flutter 不会收起键盘；
/// 退出时（应用、取消、点色块、面板收起）把焦点还给记下的节点。若输入框是
/// 因为用户点了别处（如正文）而失焦，直接退出、不应用也不抢回焦点。
class DiaryColorPanel extends StatefulWidget {
  const DiaryColorPanel({
    super.key,
    required this.controller,
    required this.target,
    required this.grid,
    required this.usedColors,
    required this.bodyHeight,
    required this.active,
    required this.onCustomColorApplied,
  });

  final quill.QuillController controller;
  final DiaryColorTarget target;
  final DiaryColorGridLayout grid;

  /// 这篇日记里用过的非预设颜色，只显示前 [DiaryColorGridLayout.customCount] 个。
  final List<Color> usedColors;

  /// 工具栏给的内容高度；小于自然高度时面板内纵向滚动。
  final double bodyHeight;

  /// 面板是否仍是工具栏当前展开的内容；收起或换成「更多」时为 false，
  /// 正在输入颜色代码的话立即退出并交还焦点（不等收起动画播完）。
  final bool active;
  final VoidCallback onCustomColorApplied;

  @override
  State<DiaryColorPanel> createState() => _DiaryColorPanelState();
}

class _DiaryColorPanelState extends State<DiaryColorPanel> {
  final TextEditingController _hexController = TextEditingController();
  final FocusNode _hexFocus = FocusNode(debugLabel: 'diary-color-hex');

  bool _inputMode = false;

  /// 进入输入模式前的焦点（通常是正文编辑器），退出时交还。
  FocusNode? _returnFocus;

  @override
  void initState() {
    super.initState();
    _hexFocus.addListener(_handleHexFocusChanged);
  }

  @override
  void didUpdateWidget(covariant DiaryColorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 面板收起、换成「更多」或目标被工具栏按钮切走时，输入的代码已没有意义。
    // 本次构建会重建表头，这里只改状态、不调用 setState。
    if ((oldWidget.active && !widget.active) ||
        oldWidget.target != widget.target) {
      _leaveInputMode(restoreFocus: true);
    }
  }

  @override
  void dispose() {
    // 录音面板打开时面板不播动画直接卸载：输入框若还拿着焦点，先交还给正文，
    // 否则焦点落空、键盘收起，工具栏也会跟着消失。
    if (_hexFocus.hasFocus) _restoreFocus();
    _hexFocus.removeListener(_handleHexFocusChanged);
    _hexFocus.dispose();
    _hexController.dispose();
    super.dispose();
  }

  DiaryColorValue get _current => DiaryColorValue.of(
    widget.controller.getSelectionStyle().attributes,
    widget.target,
  );

  void _handleHexFocusChanged() {
    // 焦点被别处（用户点了正文或标题）拿走：退出，不应用、不抢回焦点。
    if (!_hexFocus.hasFocus && _inputMode) {
      setState(() => _leaveInputMode(restoreFocus: false));
    }
  }

  void _enterInputMode() {
    final current = _current.color;
    final text = current == null ? '' : diaryColorRgbHex(current).substring(1);
    // 预填当前颜色并全选，直接打字即替换。
    _hexController.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    _returnFocus = FocusManager.instance.primaryFocus;
    setState(() => _inputMode = true);
    // 输入框本帧才挂进树；未挂载的节点会在挂上时取得焦点。
    _hexFocus.requestFocus();
  }

  /// 退出输入模式（不调用 setState，调用方负责重建）。
  void _leaveInputMode({required bool restoreFocus}) {
    if (!_inputMode) return;
    _inputMode = false;
    if (restoreFocus) {
      _restoreFocus();
    } else {
      _returnFocus = null;
    }
  }

  void _restoreFocus() {
    final node = _returnFocus;
    _returnFocus = null;
    if (node != null && node.context != null && node.canRequestFocus) {
      node.requestFocus();
    }
  }

  /// 写入颜色（null 为清除）；与选区当前值相同则不动正文。
  ///
  /// 先写入、再交还焦点：光标未选中文字时，Quill 把颜色记在
  /// `controller.toggledStyle` 里，等下一次输入时套用；写入时编辑器没有焦点，
  /// 键盘仍由输入框撑着，Quill 不会去抢键盘；随后焦点回到编辑器只重新接上
  /// 输入连接，不改选区，待套用的颜色得以保留。
  void _apply(Color? color) {
    final current = _current;
    if (color == null ? current.isNone : current.matches(color)) return;
    widget.controller.formatSelection(widget.target.attributeFor(color));
  }

  void _handleSwatchTap(Color? color) {
    _apply(color);
    if (_inputMode) setState(() => _leaveInputMode(restoreFocus: true));
  }

  void _handleHexSubmit(Color input) {
    final resolved = resolveDiaryHexInputColor(input, _current.color);
    _apply(resolved);
    setState(() => _leaveInputMode(restoreFocus: true));
    widget.onCustomColorApplied();
  }

  @override
  Widget build(BuildContext context) {
    final natural = diaryColorPanelNaturalHeight(widget.grid);
    final content = ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final current = _current;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: kDiaryColorPanelHeaderHeight,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) =>
                    _buildHeader(
                      context,
                      current,
                      // 与色块网格同一列宽（可用宽度 / 列数）。
                      constraints.maxWidth / widget.grid.columns,
                    ),
              ),
            ),
            const SizedBox(height: kDiaryColorPanelHeaderGap),
            SizedBox(
              height: widget.grid.height,
              child: DiaryColorSwatchGrid(
                target: widget.target,
                current: current,
                grid: widget.grid,
                usedColors: widget.usedColors,
                onSelected: _handleSwatchTap,
              ),
            ),
          ],
        );
      },
    );
    return SizedBox(
      height: widget.bodyHeight,
      child: widget.bodyHeight < natural
          ? SingleChildScrollView(primary: false, child: content)
          : content,
    );
  }

  Widget _buildHeader(
    BuildContext context,
    DiaryColorValue current,
    double cellWidth,
  ) {
    final l10n = context.l10n;
    // 表头与输入行同高交叉淡入，面板高度不跳。
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[...previous, ?current],
      ),
      child: _inputMode
          ? Padding(
              key: const ValueKey<String>('hex-input'),
              // 预览圆点与第一列色块同圆心，输入行与色块网格对成一列。
              padding: EdgeInsetsDirectional.only(
                start: (cellWidth - kDiaryColorHexPreviewSize) / 2,
              ),
              child: DiaryColorHexInputRow(
                controller: _hexController,
                focusNode: _hexFocus,
                target: widget.target,
                currentColor: current.color,
                onSubmit: _handleHexSubmit,
                onCancel: () =>
                    setState(() => _leaveInputMode(restoreFocus: true)),
              ),
            )
          : Row(
              key: const ValueKey<String>('header'),
              children: <Widget>[
                Expanded(
                  child: Padding(
                    // 标题起点对齐第一个色块圆的左缘（色块在格子里居中）。
                    padding: EdgeInsetsDirectional.only(
                      start: (cellWidth - kDiaryColorSwatchSize) / 2,
                    ),
                    child: AnimatedSwitcher(
                      duration: ExpressiveMotion.duration(
                        context,
                        ExpressiveMotion.fast,
                      ),
                      switchInCurve: ExpressiveMotion.effects,
                      switchOutCurve: ExpressiveMotion.exit,
                      layoutBuilder: (Widget? current, List<Widget> previous) =>
                          Stack(
                            alignment: AlignmentDirectional.centerStart,
                            children: <Widget>[...previous, ?current],
                          ),
                      child: Text(
                        _targetItem.label(l10n),
                        key: ValueKey<DiaryColorTarget>(widget.target),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DiaryColorHexChip(value: current, onPressed: _enterInputMode),
              ],
            ),
    );
  }

  /// 标题沿用工具栏上对应按钮的名称（文字颜色 / 背景颜色）。
  DiaryToolbarItem get _targetItem => switch (widget.target) {
    DiaryColorTarget.text => DiaryToolbarItem.textColor,
    DiaryColorTarget.background => DiaryToolbarItem.backgroundColor,
  };
}
