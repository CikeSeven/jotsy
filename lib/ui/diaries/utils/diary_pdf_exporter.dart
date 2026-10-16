import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_to_pdf/flutter_quill_to_pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/diary_export_document.dart';

/// 把日记正文生成 A4 PDF。
///
/// 字体策略：
/// - 统一使用一套中文字体，避免中英混排时字体风格跳变；
/// - `pw.Font.ttf` 会在生成时按实际字符做子集嵌入，减少体积；
/// - 只保留一套 Regular 字体（粗体、斜体也用它），避免多字重导致导出包体
///   膨胀。
///
/// 字体加载一次后随实例缓存；并发调用共用同一次加载。
class DiaryPdfExporter {
  static const String _fontAsset =
      'assets/fonts/harmonyos_sans_sc/HarmonyOS_Sans_SC_Regular.ttf';

  pw.Font? _cachedFont;
  Future<pw.Font>? _fontLoading;

  /// 生成 PDF 字节；转换失败时抛出异常。
  Future<Uint8List> build(
    quill.Document document, {
    required TextDirection textDirection,
  }) async {
    final unifiedFont = await _loadFont();
    final unifiedTheme = pw.ThemeData.withFont(
      base: unifiedFont,
      bold: unifiedFont,
      italic: unifiedFont,
      boldItalic: unifiedFont,
      fontFallback: <pw.Font>[unifiedFont],
    );
    final converter = PDFConverter(
      pageFormat: PDFPageFormat.a4,
      document: buildDiaryPdfExportDocument(document).toDelta(),
      textDirection: textDirection,
      themeData: unifiedTheme,
      codeBlockFont: unifiedFont,
      fallbacks: <pw.Font>[unifiedFont],
      onRequestFontFamily: (FontFamilyRequest _) {
        return FontFamilyResponse(
          fontNormalV: unifiedFont,
          boldFontV: unifiedFont,
          italicFontV: unifiedFont,
          boldItalicFontV: unifiedFont,
          fallbacks: <pw.Font>[unifiedFont],
        );
      },
    );
    final doc = await converter.createDocument();
    if (doc == null) {
      throw Exception('PDF build failed');
    }
    return Uint8List.fromList(await doc.save());
  }

  Future<pw.Font> _loadFont() async {
    final cached = _cachedFont;
    if (cached != null) {
      return cached;
    }
    final loading = _fontLoading;
    if (loading != null) {
      return loading;
    }
    final task = () async {
      try {
        final font = pw.Font.ttf(await rootBundle.load(_fontAsset));
        _cachedFont = font;
        return font;
      } finally {
        _fontLoading = null;
      }
    }();
    _fontLoading = task;
    return task;
  }
}
