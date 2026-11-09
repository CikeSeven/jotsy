import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

const double _kIconSize = 16;
const double _kIconGap = 4;
const double _kLabelSize = 11;
const double _kCellRadius = 12;

/// 按住连发：按住这么久之后开始，之后每隔一段触发一次（上移 / 下移一格）。
/// 不是动画时长：只决定多久再执行一次动作。
const Duration _kRepeatDelay = Duration(milliseconds: 420);
const Duration _kRepeatInterval = Duration(milliseconds: 130);

/// 面板里的一格操作（表格面板、段落操作栏及其面板共用）：图标在上、短标签
/// 在下；选中时垫 primaryContainer 圆角方块，经 [ExpressiveStateBlend]
/// 补间；停用时变淡（38%）；危险操作（删除）用错误色。只是按钮，不请求
/// 焦点——面板在工具栏卡片里，抢走焦点会收起键盘。
///
/// 段落操作栏用到的几种变化（默认都关着，表格面板保持原样）：
/// - [filled]：平时也垫一块很淡的底（`onSurface` 6%），一排排格子像磁贴，
///   看得出每格的范围；半透明，玻璃材质的卡片上同样成立；
/// - [wide]：横排（图标在左、标签在右），给占两格宽的长标签；
/// - [glyph]：用一两个字（H1 / H2 / H3）代替图标——三级标题的图标是同一个；
/// - [repeatOnHold]：按住不放连续触发 [onTap]，松手即停；格子停用（已经
///   移到头）时也停；
/// - [scale]：图标与标签随工具栏大小等比缩放（操作栏的工具一排）；
/// - [maxLines] 为 1 时标签放不下就整体缩小，不截断（操作栏的短标签，
///   译文偏长的语言里同样看得全）。
class DiaryPanelActionCell extends StatefulWidget {
  const DiaryPanelActionCell({
    super.key,
    this.icon,
    this.glyph,
    required this.label,
    required this.enabled,
    this.selected = false,
    this.destructive = false,
    this.filled = false,
    this.wide = false,
    this.repeatOnHold = false,
    this.maxLines = 2,
    this.scale = 1,
    required this.onTap,
  }) : assert(icon != null || glyph != null);

  final FaIconData? icon;
  final String? glyph;
  final String label;
  final bool enabled;
  final bool selected;
  final bool destructive;
  final bool filled;
  final bool wide;
  final bool repeatOnHold;
  final int maxLines;
  final double scale;
  final VoidCallback onTap;

  @override
  State<DiaryPanelActionCell> createState() => _DiaryPanelActionCellState();
}

class _DiaryPanelActionCellState extends State<DiaryPanelActionCell> {
  Timer? _hold;

  /// 这次按下已经连发过：松手时不再补一次点按。
  bool _repeated = false;

  @override
  void didUpdateWidget(DiaryPanelActionCell old) {
    super.didUpdateWidget(old);
    if (!widget.enabled || !widget.repeatOnHold) _stopHold();
  }

  @override
  void dispose() {
    _stopHold();
    super.dispose();
  }

  void _startHold() {
    _repeated = false;
    _hold?.cancel();
    _hold = Timer(_kRepeatDelay, () {
      _fire();
      _hold = Timer.periodic(_kRepeatInterval, (_) => _fire());
    });
  }

  void _fire() {
    if (!mounted || !widget.enabled) {
      _stopHold();
      return;
    }
    _repeated = true;
    widget.onTap();
  }

  void _stopHold() {
    _hold?.cancel();
    _hold = null;
  }

  void _tap() {
    if (_repeated) {
      _repeated = false;
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_kCellRadius),
    );
    final base = widget.destructive ? colors.error : colors.onSurface;
    final rest = widget.filled
        ? colors.onSurface.withValues(alpha: 0.06)
        : colors.primaryContainer.withValues(alpha: 0);
    final repeat = widget.repeatOnHold && widget.enabled;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: ExpressiveStateBlend(
        active: widget.selected,
        builder: (BuildContext context, double t, Widget? child) {
          final foreground = Color.lerp(
            base,
            colors.onPrimaryContainer,
            t,
          )!.withValues(alpha: widget.enabled ? 1 : 0.38);
          final mark = widget.glyph == null
              ? FaIcon(
                  widget.icon,
                  size: _kIconSize * widget.scale,
                  color: foreground,
                )
              : SizedBox(
                  height: _kIconSize * widget.scale,
                  child: Center(
                    child: Text(
                      widget.glyph!,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 14 * widget.scale,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                  ),
                );
          final text = Text(
            widget.label,
            maxLines: widget.maxLines,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _kLabelSize * widget.scale,
              height: 1.2,
              color: foreground,
            ),
          );
          final label = widget.maxLines == 1 && !widget.wide
              ? FittedBox(fit: BoxFit.scaleDown, child: text)
              : text;
          return Material(
            color: Color.lerp(rest, colors.primaryContainer, t),
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.enabled ? _tap : null,
              onTapDown: repeat ? (_) => _startHold() : null,
              onTapUp: repeat ? (_) => _stopHold() : null,
              onTapCancel: repeat ? _stopHold : null,
              customBorder: shape,
              canRequestFocus: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.wide ? 10 : 2,
                  // 两行标签高 16 + 4 + 26.4，58dp 的格子里上下各留 5 才放得下。
                  vertical: 5,
                ),
                child: widget.wide
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          mark,
                          const SizedBox(width: 8),
                          Flexible(child: label),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          mark,
                          SizedBox(height: _kIconGap * widget.scale),
                          label,
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
