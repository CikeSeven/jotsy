import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'diary_export_pdf_canvas.dart';

/// 为 PDF 正文的字体登记绘制效果，不改字形度量或换行结果。内置与导入
/// 字体通常没有斜体字面，且导入字体可能只有一个字重，所以在绘制时补上
/// 倾斜与适量描边。字体仍按原字符子集嵌入，文字可搜索、链接也保持原位。
class DiaryPdfTextEffects {
  DiaryPdfTextEffects({
    required this.regular,
    required this.bold,
    required this.bundled,
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font bundled;
  final _variants = <({pw.Font font, bool bold, bool italic}), pw.Font>{};
  final _effects = <PdfFont, ({bool bold, bool italic})>{};

  pw.TextStyle apply(
    pw.TextStyle style, {
    required bool isBold,
    required bool isItalic,
    bool isCodeBlock = false,
  }) {
    final font = _variant(
      isCodeBlock ? bundled : (isBold ? bold : regular),
      isBold,
      isItalic,
    );
    // 四种字面都显式指定，避免 copyWith 保留旧的 fontItalic / fontBold
    // 后又选回原字面；缺字回落也须使用相同效果，否则中文会恢复成直立。
    return style.copyWith(
      fontNormal: font,
      fontBold: font,
      fontItalic: font,
      fontBoldItalic: font,
      fontFallback: <pw.Font>[_variant(bundled, isBold, isItalic)],
    );
  }

  pw.Font _variant(pw.Font font, bool bold, bool italic) {
    if (!bold && !italic) {
      return font;
    }
    final key = (font: font, bold: bold, italic: italic);
    return _variants.putIfAbsent(key, () {
      // 使用独立的惰性字体引用标记效果，不能修改共享的 regular：一段里的
      // 常规、斜体和粗斜体可能源自同一字面，必须能在绘制时区分。
      return _EffectFont(font, (bold: bold, italic: italic), _effects);
    });
  }

  pw.Widget wrap(pw.Widget child) => _TextEffectsWidget(child, _effects);
}

class _EffectFont extends pw.Font {
  _EffectFont(this.delegate, this.effects, this.registry);

  final pw.Font delegate;
  final ({bool bold, bool italic}) effects;
  final Map<PdfFont, ({bool bold, bool italic})> registry;

  @override
  String get fontName => delegate.fontName;

  @override
  PdfFont buildFont(PdfDocument document) {
    final source = delegate;
    if (source is pw.TtfFont) {
      return PdfTtfFont(document, source.data, protect: source.protect);
    }
    // Font.type1 默认按名称复用 PdfFont，会把常规与斜体重新合成同一个
    // 引用；直接创建字面，确保标准字体也能按效果区分。
    return switch (source.font!) {
      pw.Type1Fonts.courier => PdfFont.courier(document),
      pw.Type1Fonts.courierBold => PdfFont.courierBold(document),
      pw.Type1Fonts.courierBoldOblique => PdfFont.courierBoldOblique(document),
      pw.Type1Fonts.courierOblique => PdfFont.courierOblique(document),
      pw.Type1Fonts.helvetica => PdfFont.helvetica(document),
      pw.Type1Fonts.helveticaBold => PdfFont.helveticaBold(document),
      pw.Type1Fonts.helveticaBoldOblique => PdfFont.helveticaBoldOblique(
        document,
      ),
      pw.Type1Fonts.helveticaOblique => PdfFont.helveticaOblique(document),
      pw.Type1Fonts.times => PdfFont.times(document),
      pw.Type1Fonts.timesBold => PdfFont.timesBold(document),
      pw.Type1Fonts.timesBoldItalic => PdfFont.timesBoldItalic(document),
      pw.Type1Fonts.timesItalic => PdfFont.timesItalic(document),
      pw.Type1Fonts.symbol => PdfFont.symbol(document),
      pw.Type1Fonts.zapfDingbats => PdfFont.zapfDingbats(document),
    };
  }

  @override
  PdfFont getFont(pw.Context context) {
    final font = super.getFont(context);
    registry[font] = effects;
    return font;
  }
}

class _TextEffectsWidget extends pw.StatelessWidget {
  _TextEffectsWidget(this.child, this.effects);

  final pw.Widget child;
  final Map<PdfFont, ({bool bold, bool italic})> effects;
  DiaryPdfTextCanvas? _canvas;

  @override
  pw.Widget build(pw.Context context) => child;

  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    // Directionality 等 InheritedWidget 会缓存布局时的 context，绘制时
    // 忽略传入的 context；必须两阶段都用同一画布，才能覆盖它们的子树。
    _canvas = DiaryPdfTextCanvas(context.canvas, effects);
    super.layout(
      context.copyWith(canvas: _canvas),
      constraints,
      parentUsesSize: parentUsesSize,
    );
  }

  @override
  void paint(pw.Context context) {
    super.paint(context.copyWith(canvas: _canvas));
  }
}
