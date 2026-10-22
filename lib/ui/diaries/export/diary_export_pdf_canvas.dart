import 'package:flutter/widgets.dart' show Matrix4;
import 'package:pdf/pdf.dart';

/// 正文绘制适配器：仅在画文字时补斜体与粗体，其余操作原样转交原画布。
/// 使用 pdf 的公开画布接口，不改写 PDF 字节，也不拆成图片或逐字组件，
/// 因而保留原排版、分页、背景、装饰线与链接的几何。
class DiaryPdfTextCanvas implements PdfGraphics {
  DiaryPdfTextCanvas(this.delegate, this.effects);

  final PdfGraphics delegate;
  final Map<PdfFont, ({bool bold, bool italic})> effects;
  PdfColor? _fillColor;
  final _fillColors = <PdfColor?>[];

  @override
  void drawString(
    PdfFont font,
    double size,
    String s,
    double x,
    double y, {
    double? charSpace,
    double? wordSpace,
    double? scale,
    PdfTextRenderingMode mode = PdfTextRenderingMode.fill,
    double? rise,
  }) {
    final effect = effects[font];
    if (effect != null) {
      delegate.saveContext();
    }
    if (effect?.italic == true) {
      // 约 12° 的合成斜体，围绕每段文字的基线倾斜。抵消 y 带来的横移，
      // 保持字的起点、宽度与链接区域不变；下划线仍由原排版器水平绘制。
      const shear = 0.21256;
      delegate.setTransform(
        Matrix4.identity()
          ..setEntry(0, 1, shear)
          ..setEntry(0, 3, -shear * y),
      );
    }
    if (effect?.bold == true && mode == PdfTextRenderingMode.fill) {
      delegate
        ..setStrokeColor(_fillColor ?? PdfColors.black)
        ..setLineWidth(size * 0.018);
      mode = PdfTextRenderingMode.fillAndStroke;
    }
    delegate.drawString(
      font,
      size,
      s,
      x,
      y,
      charSpace: charSpace,
      wordSpace: wordSpace,
      scale: scale,
      mode: mode,
      rise: rise,
    );
    // PDF 的文字绘制模式、描边与矩阵也属于图形状态；每次恢复，防止
    // 下一段普通文字继承粗斜体或污染装饰线。
    if (effect != null) {
      delegate.restoreContext();
    }
  }

  @override
  void setFillColor(PdfColor? color) {
    _fillColor = color;
    delegate.setFillColor(color);
  }

  @override
  void setColor(PdfColor? color) {
    _fillColor = color;
    delegate.setColor(color);
  }

  @override
  void saveContext() {
    _fillColors.add(_fillColor);
    delegate.saveContext();
  }

  @override
  void restoreContext() {
    if (_fillColors.isNotEmpty) {
      _fillColor = _fillColors.removeLast();
    }
    delegate.restoreContext();
  }

  @override
  PdfFont? get defaultFont => delegate.defaultFont;
  @override
  bool get altered => delegate.altered;
  @override
  void fillPath({bool evenOdd = false}) => delegate.fillPath(evenOdd: evenOdd);
  @override
  void strokePath({bool close = false}) => delegate.strokePath(close: close);
  @override
  void closePath() => delegate.closePath();
  @override
  void clipPath({bool evenOdd = false, bool end = true}) =>
      delegate.clipPath(evenOdd: evenOdd, end: end);
  @override
  void fillAndStrokePath({bool evenOdd = false, bool close = false}) =>
      delegate.fillAndStrokePath(evenOdd: evenOdd, close: close);
  @override
  void applyShader(PdfShading shader) => delegate.applyShader(shader);

  // PdfFormXObject 没有由 pdf.dart 公开导出；放宽参数类型后直接转交，
  // 避免为接口转发引入 package:pdf/src 的私有实现依赖。
  @override
  void drawXObject(dynamic xobj, double x, double y, {double? w, double? h}) =>
      delegate.drawXObject(xobj, x, y, w: w, h: h);
  @override
  void drawImage(PdfImage img, double x, double y, [double? w, double? h]) =>
      delegate.drawImage(img, x, y, w, h);
  @override
  void drawLine(double x1, double y1, double x2, double y2) =>
      delegate.drawLine(x1, y1, x2, y2);
  @override
  void drawEllipse(
    double x,
    double y,
    double r1,
    double r2, {
    bool clockwise = true,
  }) => delegate.drawEllipse(x, y, r1, r2, clockwise: clockwise);
  @override
  void drawRect(double x, double y, double w, double h) =>
      delegate.drawRect(x, y, w, h);
  @override
  void drawBox(PdfRect box) => delegate.drawBox(box);
  @override
  void drawRRect(
    double x,
    double y,
    double w,
    double h,
    double rv,
    double rh,
  ) => delegate.drawRRect(x, y, w, h, rv, rh);
  @override
  void setFont(
    PdfFont font,
    double size, {
    double? charSpace,
    double? wordSpace,
    double? scale,
    PdfTextRenderingMode mode = PdfTextRenderingMode.fill,
    double? rise,
  }) => delegate.setFont(
    font,
    size,
    charSpace: charSpace,
    wordSpace: wordSpace,
    scale: scale,
    mode: mode,
    rise: rise,
  );
  @override
  void reset() => delegate.reset();
  @override
  void setStrokeColor(PdfColor? color) => delegate.setStrokeColor(color);
  @override
  void setFillPattern(PdfPattern pattern) => delegate.setFillPattern(pattern);
  @override
  void setStrokePattern(PdfPattern pattern) =>
      delegate.setStrokePattern(pattern);
  @override
  void setGraphicState(PdfGraphicState state) =>
      delegate.setGraphicState(state);
  @override
  void setTransform(Matrix4 t) => delegate.setTransform(t);
  @override
  Matrix4 getTransform() => delegate.getTransform();
  @override
  void lineTo(double x, double y) => delegate.lineTo(x, y);
  @override
  void moveTo(double x, double y) => delegate.moveTo(x, y);
  @override
  void curveTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => delegate.curveTo(x1, y1, x2, y2, x3, y3);
  @override
  void bezierArc(
    double x1,
    double y1,
    double rx,
    double ry,
    double x2,
    double y2, {
    bool large = false,
    bool sweep = false,
    double phi = 0.0,
  }) => delegate.bezierArc(
    x1,
    y1,
    rx,
    ry,
    x2,
    y2,
    large: large,
    sweep: sweep,
    phi: phi,
  );
  @override
  void drawShape(String d) => delegate.drawShape(d);
  @override
  void setLineCap(PdfLineCap cap) => delegate.setLineCap(cap);
  @override
  void setLineJoin(PdfLineJoin join) => delegate.setLineJoin(join);
  @override
  void setLineWidth(double width) => delegate.setLineWidth(width);
  @override
  void setMiterLimit(double limit) => delegate.setMiterLimit(limit);
  @override
  void setLineDashPattern([List<num> array = const <num>[], int phase = 0]) =>
      delegate.setLineDashPattern(array, phase);
  @override
  void markContentBegin(PdfName tag) => delegate.markContentBegin(tag);
  @override
  void markContentEnd() => delegate.markContentEnd();
}
