import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../models/diary_code_block/diary_code_theme.dart';

// 代码块标题栏的绘制：底色、与代码块主体相接的边框、语言名与复制图标。
//
// 输入：代码块配色、圆角 / 边框设置、语言名的文字样式与缩放，以及每次绘制
// 时的标题栏矩形、语言名和“刚复制过”状态。
// 输出：直接画在传入的 Canvas 上；不做布局、不处理手势。
// 副作用：缓存语言名与图标的 TextPainter（同一份文字只排版一次），用完
// 须调用 [dispose]。
//
// 标题栏由 RenderDiaryCodeBlockChrome 在绘制阶段逐块调用（那时编辑器的
// 布局已定），所以这里只是一组纯绘制，不持有任何几何状态。
//
// 为什么图标不用 FaIcon：标题栏不是 widget（见 RenderDiaryCodeBlockChrome
// 的说明），图标按 FaIcon 的同一套字形参数（字族、包名、height 1.0）用
// TextPainter 直接画出。
//
// 标题栏一律按从左到右排布（语言名在左、复制在右），与代码本身的书写方向
// 一致，不随界面的 RTL 镜像。

/// 一个代码块标题栏的几何常量与绘制。
class DiaryCodeBlockHeaderPainter {
  DiaryCodeBlockHeaderPainter({
    required this._palette,
    required this._radius,
    required this._border,
    required this._labelStyle,
    required this._textScaler,
  });

  /// 语言名距标题栏左缘。
  static const double labelInset = 12;

  /// 复制图标右缘距标题栏右缘。
  static const double iconInset = 12;

  /// 复制 / 已复制图标的字号。
  static const double iconSize = 14;

  /// 复制按钮的点按区域宽度（高度为整个标题栏）。
  static const double copyHitWidth = 40;

  /// 语言名的不透明度（相对代码正文字色）。
  static const double labelOpacity = 0.7;

  /// 边框宽度，与代码块主体的边框一致（DiaryCodeBlockLook）。
  static const double borderWidth = 0.8;

  /// 底色向代码块主体多铺的高度。
  ///
  /// 标题栏与主体是两次绘制、在同一条水平线上相接；这条线落在小数像素
  /// 上时，两边的抗锯齿各自只盖住那一行像素的一部分，页面底色会从缝里
  /// 透出一条细线。让标题栏底色（画在主体之上）往下多铺 1dp 盖住接缝，
  /// 主体内容区上方有 16dp 的内边距，不会盖到代码文字。
  static const double seamOverlap = 1;

  /// 复制按钮在 [header] 中的点按区域。
  static Rect copyRect(Rect header) => Rect.fromLTRB(
    header.right - copyHitWidth,
    header.top,
    header.right,
    header.bottom,
  );

  DiaryCodePalette _palette;
  double _radius;
  bool _border;
  TextStyle _labelStyle;
  TextScaler _textScaler;

  /// 语言名的排版缓存：同一份文字在同一可用宽度下只排版一次。
  final Map<String, TextPainter> _labels = <String, TextPainter>{};
  double? _labelWidth;
  TextPainter? _copyIcon;
  TextPainter? _checkIcon;

  /// 更新外观；返回是否有变化（调用方据此决定是否重绘）。
  bool update({
    required DiaryCodePalette palette,
    required double radius,
    required bool border,
    required TextStyle labelStyle,
    required TextScaler textScaler,
  }) {
    final textChanged = labelStyle != _labelStyle || textScaler != _textScaler;
    final iconChanged = palette != _palette;
    final changed =
        textChanged || iconChanged || radius != _radius || border != _border;
    _palette = palette;
    _radius = radius;
    _border = border;
    _labelStyle = labelStyle;
    _textScaler = textScaler;
    if (textChanged) {
      _clearLabels();
    }
    if (textChanged || iconChanged) {
      _clearIcons();
    }
    return changed;
  }

  /// 在 [header]（已含绘制偏移）处画一个标题栏。[copied] 为 true 时复制
  /// 图标换成对勾。
  void paint(
    Canvas canvas,
    Rect header, {
    required String label,
    required bool copied,
  }) {
    final radius = Radius.circular(_radius);
    // 往下多铺 seamOverlap，见其说明；圆角只在上方两角，下方与主体直角相接。
    final body = Rect.fromLTRB(
      header.left,
      header.top,
      header.right,
      header.bottom + seamOverlap,
    );
    final shape = RRect.fromRectAndCorners(
      body,
      topLeft: radius,
      topRight: radius,
    );
    canvas.drawRRect(shape, Paint()..color = _palette.header);
    if (_border) {
      _paintBorder(canvas, shape, body);
    }

    final icon = copied ? _check() : _copy();
    final iconOffset = Offset(
      header.right - iconInset - icon.width,
      header.center.dy - icon.height / 2,
    );
    icon.paint(canvas, iconOffset);

    final maxLabelWidth = header.width - labelInset - copyHitWidth;
    if (maxLabelWidth > 0) {
      final text = _label(label, maxLabelWidth);
      text.paint(
        canvas,
        Offset(header.left + labelInset, header.center.dy - text.height / 2),
      );
    }
  }

  /// 上、左、右三条边：外缘是标题栏形状，内缘向内收一个边框宽度、下边
  /// 与形状底边重合（不画），与主体只有左右下三边的边框接成一圈。和
  /// BoxDecoration 的边框一样画在形状内侧。
  void _paintBorder(Canvas canvas, RRect shape, Rect body) {
    final inner = Rect.fromLTRB(
      body.left + borderWidth,
      body.top + borderWidth,
      body.right - borderWidth,
      body.bottom,
    );
    if (inner.isEmpty) {
      return;
    }
    final innerRadius = Radius.circular(
      (_radius - borderWidth).clamp(0, double.infinity),
    );
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(shape)
      ..addRRect(
        RRect.fromRectAndCorners(
          inner,
          topLeft: innerRadius,
          topRight: innerRadius,
        ),
      );
    canvas.drawPath(ring, Paint()..color = _palette.border);
  }

  Color get _labelColor {
    final foreground = _palette.foreground;
    return foreground.withValues(alpha: foreground.a * labelOpacity);
  }

  TextPainter _label(String text, double maxWidth) {
    if (_labelWidth != maxWidth) {
      _clearLabels();
      _labelWidth = maxWidth;
    }
    return _labels.putIfAbsent(text, () {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: _labelStyle.copyWith(color: _labelColor),
        ),
        textDirection: TextDirection.ltr,
        textScaler: _textScaler,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);
    });
  }

  TextPainter _copy() =>
      _copyIcon ??= _icon(FontAwesomeIcons.copy.data, _labelColor);

  // 复制成功的对勾用 diff 新增色：各主题里都是绿色系、表示“成功”；字符串
  // 色在不少主题里偏红，容易被看成出错。
  TextPainter _check() => _checkIcon ??= _icon(
    FontAwesomeIcons.check.data,
    _palette.tokens[DiaryCodeTokenRole.addition] ?? _palette.foreground,
  );

  /// 与 FaIcon 相同的字形参数；图标不随系统字号缩放（与其他图标一致）。
  static TextPainter _icon(IconData icon, Color color) {
    return TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          inherit: false,
          color: color,
          fontSize: iconSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _clearLabels() {
    for (final painter in _labels.values) {
      painter.dispose();
    }
    _labels.clear();
    _labelWidth = null;
  }

  void _clearIcons() {
    _copyIcon?.dispose();
    _checkIcon?.dispose();
    _copyIcon = null;
    _checkIcon = null;
  }

  void dispose() {
    _clearLabels();
    _clearIcons();
  }
}
