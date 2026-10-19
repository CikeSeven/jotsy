import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_hex_input.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_spectrum.dart';

/// 自定义取色页的高度：饱和度 / 亮度面与竖条同高，右侧预览 + 颜色代码。
const double kDiaryColorCustomPickerHeight = 128;

/// 竖条宽度：放得下拖动中放大的圆点（直径 26dp）。
const double _kTrackWidth = 28;

/// 右侧一列（预览 + 颜色代码输入框）的宽度：放得下 `#` 加六位代码。
const double _kSideWidth = 96;
const double _kFieldHeight = 40;

/// 选区没有颜色时色谱从这里开始：中等饱和度的蓝，拖哪个方向都有余地。
final HSVColor _kStartColor = HSVColor.fromAHSV(1, 210, 0.65, 0.85);

/// 背景色的默认不透明度：与预设高亮相同（0x4D），正文墨色叠上去仍清楚。
const double _kDefaultBackgroundAlpha = 0x4D / 0xFF;

/// 颜色面板的「自定义」页：饱和度 / 亮度面 + 色相条（背景色另有不透明度条）
/// + 所见即所得预览 + 颜色代码输入框。
///
/// - 输入：正文控制器、目标、选区当前颜色 [current]（由面板随选区刷新）；
/// - 输出：拖动中只改面板里的预览，松手才经 `formatSelection` 写入正文
///   （每次松手一步撤销），随后 [onColorUsed] 让工具栏记入最近颜色；
/// - 同步：选区颜色变化（移动光标、撤销）时色谱跟过去；拖动中或正在输入
///   代码时不跟，以免抢走手上的操作。刚写入的颜色经 8 位取整后再读回来，
///   与 [_syncedArgb] 相同就不重新换算，圆点不会被取整拖动；
/// - 灰色没有色相、黑色没有饱和度：从这类颜色同步时保留原来的色相 / 饱和度，
///   色相条不会跳回红色。
///
/// 颜色代码的焦点交接：手指按下输入框时记下当前焦点（正文编辑器），应用代码
/// 或开始拖动色谱时把焦点还给它——先写入、再还焦点：光标未选中文字时 Quill
/// 把颜色记在 `toggledStyle` 里等下一次输入套用，还焦点只重新接上输入连接、
/// 不改选区，待套用的颜色得以保留。输入框因用户点了别处而失焦时不应用、
/// 不抢回焦点，色谱回到输入前的颜色（选区有颜色时跟到选区）。
class DiaryColorCustomPicker extends StatefulWidget {
  const DiaryColorCustomPicker({
    super.key,
    required this.controller,
    required this.target,
    required this.current,
    required this.active,
    required this.onColorUsed,
  });

  final quill.QuillController controller;
  final DiaryColorTarget target;
  final DiaryColorValue current;

  /// 面板是否仍展开着；收起时正在输入的代码作废，焦点立即还给正文。
  final bool active;
  final ValueChanged<Color> onColorUsed;

  @override
  State<DiaryColorCustomPicker> createState() => _DiaryColorCustomPickerState();
}

class _DiaryColorCustomPickerState extends State<DiaryColorCustomPicker> {
  final TextEditingController _hexController = TextEditingController();
  final FocusNode _hexFocus = FocusNode(debugLabel: 'diary-color-hex');

  HSVColor _hsv = _kStartColor;
  double _alpha = _kDefaultBackgroundAlpha;
  bool _dragging = false;

  /// 最近一次从选区读到或写入正文的颜色（ARGB）。
  int? _syncedArgb;

  /// 开始输入代码前的焦点（通常是正文编辑器），应用后交还。
  FocusNode? _returnFocus;

  /// 开始输入代码前面板上的颜色：放弃输入时回到这里（选区没有颜色可同步时
  /// 不会停在输入到一半的预览色上）。应用代码后清空。
  HSVColor? _hsvBeforeHex;

  bool get _isBackground => widget.target == DiaryColorTarget.background;

  /// 面板上的颜色：文字色不透明，背景色带不透明度条的值。
  Color get _color {
    final rgb = _hsv.toColor();
    return _isBackground ? rgb.withAlpha((_alpha * 0xFF).round()) : rgb;
  }

  @override
  void initState() {
    super.initState();
    _hexFocus.addListener(_handleHexFocusChanged);
    _syncFrom(widget.current);
    _showHex();
  }

  @override
  void didUpdateWidget(covariant DiaryColorCustomPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 本次构建会重建色谱与输入框，这里只改状态、不调用 setState。
    if (oldWidget.active && !widget.active) _leaveHex(restoreFocus: true);
    if (oldWidget.target != widget.target) {
      _leaveHex(restoreFocus: true);
      _syncedArgb = null;
      _alpha = _kDefaultBackgroundAlpha;
      _syncFrom(widget.current);
      _showHex();
    } else if (!_dragging && !_hexFocus.hasFocus) {
      _syncFrom(widget.current);
      _showHex();
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

  /// 色谱跟到选区的颜色；没有颜色时保留面板上的颜色（下次取色从这里开始）。
  void _syncFrom(DiaryColorValue value) {
    final color = value.color;
    if (color == null) {
      _syncedArgb = null;
      return;
    }
    if (color.toARGB32() == _syncedArgb) return;
    _syncedArgb = color.toARGB32();
    _hsv = _keepHue(HSVColor.fromColor(color.withAlpha(0xFF)));
    if (_isBackground) _alpha = color.a;
  }

  HSVColor _keepHue(HSVColor next) {
    var result = next;
    if (next.saturation == 0 || next.value == 0) {
      result = result.withHue(_hsv.hue);
    }
    if (next.value == 0) result = result.withSaturation(_hsv.saturation);
    return result;
  }

  /// 输入框没在编辑时显示面板上颜色的代码。
  void _showHex() {
    if (_hexFocus.hasFocus) return;
    _hexController.text = diaryColorRgbHex(_color).substring(1);
  }

  /// 写入颜色；与选区当前值相同则不动正文（不多出一步撤销）。
  void _apply(Color color) {
    if (widget.current.matches(color)) return;
    _syncedArgb = color.toARGB32();
    widget.controller.formatSelection(widget.target.attributeFor(color));
    widget.onColorUsed(color);
  }

  void _handleChangeStart() {
    _dragging = true;
    // 正在输入代码时去拖色谱：放弃输入，焦点先回到正文。
    _leaveHex(restoreFocus: true);
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _showHex();
    });
  }

  void _handleChangeEnd() {
    _dragging = false;
    _apply(_color);
  }

  void _handleHexPointerDown() {
    if (_hexFocus.hasFocus) return;
    final focused = FocusManager.instance.primaryFocus;
    if (focused != _hexFocus) _returnFocus = focused;
  }

  void _handleHexFocusChanged() {
    if (_hexFocus.hasFocus) {
      _hsvBeforeHex ??= _hsv;
      return;
    }
    // 焦点离开输入框（点了正文、开始拖色谱或应用了代码）：没应用的输入作废，
    // 回到输入前的颜色，再跟到选区的颜色。拖动中由拖动决定颜色，不回退。
    _returnFocus = null;
    final before = _hsvBeforeHex;
    _hsvBeforeHex = null;
    if (!mounted || _dragging) return;
    setState(() {
      if (before != null) _hsv = before;
      _syncedArgb = null;
      _syncFrom(widget.current);
      _showHex();
    });
  }

  /// 输入中的有效代码只改预览，按“完成”才写入。
  void _handleHexChanged(String text) {
    final parsed = parseDiaryHexInput(text);
    if (parsed == null) return;
    setState(() => _hsv = _keepHue(HSVColor.fromColor(parsed)));
  }

  void _handleHexSubmitted(Color input) {
    _hsv = _keepHue(HSVColor.fromColor(input));
    _hsvBeforeHex = null;
    _apply(_color);
    _leaveHex(restoreFocus: true);
  }

  void _leaveHex({required bool restoreFocus}) {
    if (!_hexFocus.hasFocus) {
      _returnFocus = null;
      return;
    }
    if (restoreFocus && _returnFocus != null) {
      _restoreFocus();
    } else {
      _returnFocus = null;
      _hexFocus.unfocus();
    }
  }

  void _restoreFocus() {
    final node = _returnFocus;
    _returnFocus = null;
    if (node != null && node.context != null && node.canRequestFocus) {
      node.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return SizedBox(
      height: kDiaryColorCustomPickerHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: DiaryColorSaturationValueArea(
              color: _hsv,
              onChangeStart: _handleChangeStart,
              onChanged: (HSVColor next) => _update(() => _hsv = next),
              onChangeEnd: _handleChangeEnd,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: _kTrackWidth,
            child: DiaryColorHueSlider(
              hue: _hsv.hue,
              onChangeStart: _handleChangeStart,
              onChanged: (double hue) =>
                  _update(() => _hsv = _hsv.withHue(hue)),
              onChangeEnd: _handleChangeEnd,
            ),
          ),
          if (_isBackground) ...<Widget>[
            const SizedBox(width: 8),
            SizedBox(
              width: _kTrackWidth,
              child: DiaryColorAlphaSlider(
                color: color,
                onChangeStart: _handleChangeStart,
                onChanged: (double alpha) => _update(() => _alpha = alpha),
                onChangeEnd: _handleChangeEnd,
              ),
            ),
          ],
          const SizedBox(width: 12),
          SizedBox(
            width: _kSideWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _ColorPreview(color: color, target: widget.target),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: _kFieldHeight,
                  child: Listener(
                    onPointerDown: (_) => _handleHexPointerDown(),
                    child: DiaryColorHexField(
                      controller: _hexController,
                      focusNode: _hexFocus,
                      onChanged: _handleHexChanged,
                      onSubmitted: _handleHexSubmitted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 所见即所得的预览：文字色写出“Aa”，背景色在纸面上叠出高亮、上面是正文
/// 墨色的“Aa”。
class _ColorPreview extends StatelessWidget {
  const _ColorPreview({required this.color, required this.target});

  final Color color;
  final DiaryColorTarget target;

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
          child: Center(
            child: Text(
              'Aa',
              style: TextStyle(
                fontSize: 26,
                height: 1,
                fontWeight: FontWeight.w700,
                color: background ? colors.onSurface : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
