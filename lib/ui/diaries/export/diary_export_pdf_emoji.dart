import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// PDF 里的 emoji：画成图片，按行内组件排进文字。
///
/// 为什么不写成文字：PDF 嵌入的字体（内置 HarmonyOS Sans SC 或导入字体）
/// 没有 emoji 字形，写进去只会印成方框；pdf 库也不做字形整形，即使另嵌
/// emoji 字体，👨‍👩‍👧、👍🏽、🇨🇳 这类由多个码位组合的 emoji 也拼不起来。所以由
/// Flutter 引擎用系统 emoji 字体把每个 emoji 画成位图（彩色、组合正确，与
/// 应用里看到的一致），代价是从 PDF 复制文字时不带 emoji。
///
/// 两步走，排版与栅格化分开：
/// 1. 建组件时，文字经 [split] 切出 emoji 字素，每个经 [span] 换成一个行内
///    组件并登记。组件的尺寸只取字号（宽 [_advance]、高 [_extent] 个字号，
///    基线下 [_descent] 个字号），排版不依赖位图；
/// 2. 全部组件建好之后、文档保存（绘制）之前，调用方 `await` [rasterize]
///    把登记过的 emoji 逐个画好。同一个 emoji 在整份文档里只画一次、只嵌一份
///    图片（pdf 库按文档缓存 [pw.ImageProvider]）。
///
/// 哪些字素算 emoji 见 [isDiaryPdfEmoji]：字体里有字形、又没要求彩色呈现的
/// 符号（©、★ 等）仍按文字写入，可以复制、搜索。
///
/// 栅格化失败（引擎画不出、读不出像素）的 emoji 留出同样大小的空白，不会
/// 让整次导出失败；系统没有 emoji 字体时画出的是方框，与应用里一致。
class DiaryPdfEmoji {
  DiaryPdfEmoji({
    required this._fontCovers,
    this._rasterizer = rasterizeDiaryEmoji,
  });

  final bool Function(int rune) _fontCovers;
  final DiaryPdfEmojiRasterizer _rasterizer;

  /// 登记过的 emoji（字素 → 图片），[rasterize] 之前图片为空。
  final Map<String, _DiaryPdfEmojiImage> _images =
      <String, _DiaryPdfEmojiImage>{};

  /// 组件宽度（字号的倍数）：应用里 emoji 的字宽约为 1.2 个字号，两侧留白
  /// 随之相同。
  static const double _advance = 1.2;

  /// 组件高度，也是 emoji 图片的最大边长（字号的倍数）。
  static const double _extent = 1.05;

  /// 组件底边在基线下多远（字号的倍数）。与 [_extent] 一起落在内置字体的
  /// 行高之内（上 0.928、下 0.244 个字号），带 emoji 的行不会变高。
  static const double _descent = 0.13;

  /// 把 [text] 切成 emoji 与其他文字交替的段（`(文字, 是否 emoji)`），一个
  /// emoji 字素一段；没有 emoji 时为 null（调用方原样写文字）。
  List<(String, bool)>? split(String text) {
    if (!text.runes.any(_mayBeEmoji)) {
      return null;
    }
    final parts = <(String, bool)>[];
    final buffer = StringBuffer();
    for (final grapheme in text.characters) {
      if (!isDiaryPdfEmoji(grapheme, fontCovers: _fontCovers)) {
        buffer.write(grapheme);
        continue;
      }
      if (buffer.isNotEmpty) {
        parts.add((buffer.toString(), false));
        buffer.clear();
      }
      parts.add((grapheme, true));
    }
    if (parts.isEmpty) {
      return null;
    }
    if (buffer.isNotEmpty) {
      parts.add((buffer.toString(), false));
    }
    return parts;
  }

  /// [emoji]（[split] 切出的一个字素）的行内组件，按 [style] 的字号定尺寸。
  /// [style] 原样交给片段，背景色与下划线照常画在它下面；[baseline] 为所在
  /// 片段的基线偏移（上下标）。
  pw.WidgetSpan span(
    String emoji, {
    required pw.TextStyle? style,
    double baseline = 0,
  }) {
    final fontSize = style?.fontSize ?? _themeFontSize;
    final image = _images.putIfAbsent(emoji, _DiaryPdfEmojiImage.new);
    return pw.WidgetSpan(
      style: style,
      baseline: baseline - fontSize * _descent,
      child: _DiaryPdfEmojiGlyph(
        image,
        width: fontSize * _advance,
        height: fontSize * _extent,
      ),
    );
  }

  /// 把登记过、还没画的 emoji 画成图片。须在全部组件建好之后、文档保存
  /// 之前调用（之后登记的不会画出）。
  Future<void> rasterize() async {
    for (final entry in _images.entries) {
      final image = entry.value;
      if (image.attempted) continue;
      image.attempted = true;
      try {
        final bitmap = await _rasterizer(entry.key);
        if (bitmap != null) image.bitmap = bitmap;
      } catch (_) {
        // 画不出时留白（见类注释），不中断导出。
      }
    }
  }

  /// 没给字号的样式按 PDF 主题的默认字号（pdf 库 `TextStyle.defaultStyle`）。
  static const double _themeFontSize = 12;
}

/// 不带行内格式的一段文字（日记标题、信息行、标签、留言、扉页与目录）：
/// 没有 emoji 时就是 [pw.Text]，有时换成同样样式的 [pw.RichText]，emoji 经
/// [DiaryPdfEmoji.span] 画成图片。
pw.Widget buildDiaryPdfText(
  String text, {
  required DiaryPdfEmoji emoji,
  pw.TextStyle? style,
  pw.TextAlign? textAlign,
}) {
  final parts = emoji.split(text);
  if (parts == null) {
    return pw.Text(text, style: style, textAlign: textAlign);
  }
  return pw.RichText(
    textAlign: textAlign,
    text: pw.TextSpan(
      style: style,
      children: <pw.InlineSpan>[
        for (final (part, isEmoji) in parts)
          isEmoji ? emoji.span(part, style: style) : pw.TextSpan(text: part),
      ],
    ),
  );
}

/// 一个 emoji 字素是否画成图片（[fontCovers] 为 PDF 字体是否有这个码位的
/// 字形）：
/// - 旗帜（区域指示符）与键帽（`1️⃣`）总是；
/// - 否则须含象形符号（Unicode `Extended_Pictographic`），并且：
///   - 字体里没有它的字形（写成文字只会是方框），或
///   - 要求彩色呈现：带 U+FE0F、零宽连接符或肤色修饰，且没有 U+FE0E；
/// - 字体有字形、没要求彩色的符号（©、™、★、↔ 等）仍是文字。
@visibleForTesting
bool isDiaryPdfEmoji(
  String grapheme, {
  required bool Function(int rune) fontCovers,
}) {
  var pictographic = false;
  var uncovered = false;
  var emojiStyle = false;
  var textStyle = false;
  for (final rune in grapheme.runes) {
    if (rune == 0x20E3 || _isRegionalIndicator(rune)) {
      return true;
    }
    if (rune == 0xFE0F || rune == 0x200D || _isSkinTone(rune)) {
      emojiStyle = true;
    } else if (rune == 0xFE0E) {
      textStyle = true;
    }
    if (_isPictographic(rune)) {
      pictographic = true;
      uncovered = uncovered || !fontCovers(rune);
    }
  }
  return pictographic && (uncovered || (emojiStyle && !textStyle));
}

/// [fonts] 合起来是否有某个码位的字形（PDF 缺字时依次回落这几个字体）。
/// 字符映射表在第一次查询时才解析（一份字体只解析一次）：只有正文里出现
/// ©、★ 这类拿不准的符号时才用得到。不是 TrueType 的字体（测试用的标准
/// 字体）按没有字形处理。
bool Function(int rune) diaryPdfFontCoverage(List<pw.Font> fonts) {
  List<Map<int, int>>? maps;
  return (int rune) {
    maps ??= <Map<int, int>>[
      for (final font in fonts)
        if (font is pw.TtfFont) ?_characterMap(font.data),
    ];
    return maps!.any((Map<int, int> map) => map.containsKey(rune));
  };
}

Map<int, int>? _characterMap(ByteData data) {
  try {
    return TtfParser(data).charToGlyphIndexMap;
  } catch (_) {
    // 嵌入前已经试解析过（DiaryPdfFonts.embeddable），这里只是兜底。
    return null;
  }
}

/// 画一个 emoji 字素：返回去掉四周透明边的位图，画不出时为 null。
typedef DiaryPdfEmojiRasterizer =
    Future<DiaryPdfEmojiBitmap?> Function(String emoji);

/// 一个 emoji 的位图：[rgba] 为逐行的非预乘 RGBA 像素。
@immutable
class DiaryPdfEmojiBitmap {
  const DiaryPdfEmojiBitmap({
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int width;
  final int height;
  final Uint8List rgba;
}

/// 默认的栅格化：用引擎的默认字体（缺字回落到系统 emoji 字体，与应用里
/// 一样）按 [_rasterFontSize] 排一行、画成图片，再裁掉四周透明的边——各平台
/// emoji 字体的行高与留白不同，裁剪后图片只有字形本身，PDF 里大小一致。
///
/// 单色的符号字形按黑色画（纸面文字的颜色）。
Future<DiaryPdfEmojiBitmap?> rasterizeDiaryEmoji(String emoji) async {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontSize: _rasterFontSize,
            textDirection: ui.TextDirection.ltr,
          ),
        )
        ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF000000)))
        ..addText(emoji);
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: double.infinity));
  final width = paragraph.maxIntrinsicWidth.ceil();
  final height = paragraph.height.ceil();
  if (width <= 0 || height <= 0) {
    paragraph.dispose();
    return null;
  }
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawParagraph(paragraph, ui.Offset.zero);
  final picture = recorder.endRecording();
  paragraph.dispose();
  final image = await picture.toImage(width, height);
  picture.dispose();
  try {
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    return data == null
        ? null
        : cropDiaryEmojiBitmap(
            DiaryPdfEmojiBitmap(
              width: width,
              height: height,
              rgba: data.buffer.asUint8List(
                data.offsetInBytes,
                data.lengthInBytes,
              ),
            ),
          );
  } finally {
    image.dispose();
  }
}

/// 栅格化的字号（逻辑像素）：字形约 80px 见方，正文里的 emoji 折合 400 DPI
/// 以上，20pt 的日记标题里也有 250 DPI 左右，打印清晰。
const double _rasterFontSize = 72;

/// 裁掉 [bitmap] 四周完全透明的行与列；整张透明（没画出任何东西）时为
/// null。
@visibleForTesting
DiaryPdfEmojiBitmap? cropDiaryEmojiBitmap(DiaryPdfEmojiBitmap bitmap) {
  final width = bitmap.width;
  final height = bitmap.height;
  final rgba = bitmap.rgba;
  var left = width;
  var right = -1;
  var top = height;
  var bottom = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (rgba[(y * width + x) * 4 + 3] == 0) continue;
      left = math.min(left, x);
      right = math.max(right, x);
      top = math.min(top, y);
      bottom = math.max(bottom, y);
    }
  }
  if (right < 0) {
    return null;
  }
  final cropWidth = right - left + 1;
  final cropHeight = bottom - top + 1;
  if (cropWidth == width && cropHeight == height) {
    return bitmap;
  }
  final cropped = Uint8List(cropWidth * cropHeight * 4);
  for (var y = 0; y < cropHeight; y++) {
    final from = ((top + y) * width + left) * 4;
    cropped.setRange(y * cropWidth * 4, (y + 1) * cropWidth * 4, rgba, from);
  }
  return DiaryPdfEmojiBitmap(
    width: cropWidth,
    height: cropHeight,
    rgba: cropped,
  );
}

/// 一个 emoji 在整份文档里共用的图片：[bitmap] 由 [DiaryPdfEmoji.rasterize]
/// 写入，[image] 在第一次绘制时建好，pdf 库按文档缓存它，只嵌一份。
class _DiaryPdfEmojiImage {
  /// 是否已经试着栅格化过（失败的不再重试）。
  bool attempted = false;
  DiaryPdfEmojiBitmap? bitmap;
  pw.ImageProvider? _image;

  pw.ImageProvider? get image => switch (bitmap) {
    final bitmap? => _image ??= pw.RawImage(
      bytes: bitmap.rgba,
      width: bitmap.width,
      height: bitmap.height,
    ),
    null => null,
  };
}

/// 行内的 emoji 组件：排版时只占 [width] × [height]（见 [DiaryPdfEmoji] 的
/// 尺寸常量），绘制时把位图等比放进以高为边长的方格、居中，没有位图时
/// 留白。
class _DiaryPdfEmojiGlyph extends pw.Widget {
  _DiaryPdfEmojiGlyph(this.image, {required this.width, required this.height});

  final _DiaryPdfEmojiImage image;
  final double width;
  final double height;

  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    box = PdfRect.fromPoints(
      PdfPoint.zero,
      constraints.constrain(PdfPoint(width, height)),
    );
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    final bitmap = image.bitmap;
    final provider = image.image;
    final rect = box!;
    if (bitmap == null || provider == null) return;
    final side = math.min(rect.width, rect.height);
    final scale = math.min(side / bitmap.width, side / bitmap.height);
    final w = bitmap.width * scale;
    final h = bitmap.height * scale;
    context.canvas.drawImage(
      provider.resolve(context, PdfPoint(w, h)),
      rect.left + (rect.width - w) / 2,
      rect.bottom + (rect.height - h) / 2,
      w,
      h,
    );
  }
}

bool _isRegionalIndicator(int rune) => rune >= 0x1F1E6 && rune <= 0x1F1FF;

bool _isSkinTone(int rune) => rune >= 0x1F3FB && rune <= 0x1F3FF;

/// 可能落在 emoji 字素里的码位：[split] 先按它快速排除没有 emoji 的文字。
bool _mayBeEmoji(int rune) =>
    rune == 0x20E3 || _isRegionalIndicator(rune) || _isPictographic(rune);

/// Unicode `Extended_Pictographic`（emoji-data.txt）里已分配的部分，外加肤色
/// 修饰符（单独出现时也画成色块）。
bool _isPictographic(int rune) {
  if (rune < 0xA9) return false;
  if (rune >= 0x1F000) {
    return (rune <= 0x1F0FF) ||
        (rune >= 0x1F10D && rune <= 0x1F10F) ||
        rune == 0x1F12F ||
        (rune >= 0x1F16C && rune <= 0x1F171) ||
        (rune >= 0x1F17E && rune <= 0x1F17F) ||
        rune == 0x1F18E ||
        (rune >= 0x1F191 && rune <= 0x1F19A) ||
        (rune >= 0x1F1AD && rune <= 0x1F1E5) ||
        (rune >= 0x1F201 && rune <= 0x1F20F) ||
        rune == 0x1F21A ||
        rune == 0x1F22F ||
        (rune >= 0x1F232 && rune <= 0x1F23A) ||
        (rune >= 0x1F23C && rune <= 0x1F23F) ||
        (rune >= 0x1F249 && rune <= 0x1F53D) ||
        (rune >= 0x1F546 && rune <= 0x1F64F) ||
        (rune >= 0x1F680 && rune <= 0x1F6FF) ||
        (rune >= 0x1F774 && rune <= 0x1F77F) ||
        (rune >= 0x1F7D5 && rune <= 0x1F7FF) ||
        (rune >= 0x1F80C && rune <= 0x1F80F) ||
        (rune >= 0x1F848 && rune <= 0x1F84F) ||
        (rune >= 0x1F85A && rune <= 0x1F85F) ||
        (rune >= 0x1F888 && rune <= 0x1F88F) ||
        (rune >= 0x1F8AE && rune <= 0x1F8FF) ||
        (rune >= 0x1F90C && rune <= 0x1F93A) ||
        (rune >= 0x1F93C && rune <= 0x1F945) ||
        (rune >= 0x1F947 && rune <= 0x1FAFF) ||
        (rune >= 0x1FC00 && rune <= 0x1FFFD);
  }
  return _bmpPictographic.any(
    ((int, int) range) => rune >= range.$1 && rune <= range.$2,
  );
}

/// 基本多文种平面里的 `Extended_Pictographic` 区间（含两端）。
const List<(int, int)> _bmpPictographic = <(int, int)>[
  (0x00A9, 0x00A9),
  (0x00AE, 0x00AE),
  (0x203C, 0x203C),
  (0x2049, 0x2049),
  (0x2122, 0x2122),
  (0x2139, 0x2139),
  (0x2194, 0x2199),
  (0x21A9, 0x21AA),
  (0x231A, 0x231B),
  (0x2328, 0x2328),
  (0x2388, 0x2388),
  (0x23CF, 0x23CF),
  (0x23E9, 0x23F3),
  (0x23F8, 0x23FA),
  (0x24C2, 0x24C2),
  (0x25AA, 0x25AB),
  (0x25B6, 0x25B6),
  (0x25C0, 0x25C0),
  (0x25FB, 0x25FE),
  (0x2600, 0x2605),
  (0x2607, 0x2612),
  (0x2614, 0x2685),
  (0x2690, 0x2705),
  (0x2708, 0x2712),
  (0x2714, 0x2714),
  (0x2716, 0x2716),
  (0x271D, 0x271D),
  (0x2721, 0x2721),
  (0x2728, 0x2728),
  (0x2733, 0x2734),
  (0x2744, 0x2744),
  (0x2747, 0x2747),
  (0x274C, 0x274C),
  (0x274E, 0x274E),
  (0x2753, 0x2755),
  (0x2757, 0x2757),
  (0x2763, 0x2767),
  (0x2795, 0x2797),
  (0x27A1, 0x27A1),
  (0x27B0, 0x27B0),
  (0x27BF, 0x27BF),
  (0x2934, 0x2935),
  (0x2B05, 0x2B07),
  (0x2B1B, 0x2B1C),
  (0x2B50, 0x2B50),
  (0x2B55, 0x2B55),
  (0x3030, 0x3030),
  (0x303D, 0x303D),
  (0x3297, 0x3297),
  (0x3299, 0x3299),
];
