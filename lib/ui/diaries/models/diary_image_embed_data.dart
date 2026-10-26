import 'dart:convert' show base64Decode;
import 'dart:io' show File;

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart'
    show AlignmentDirectional, BoxConstraints;
import 'package:appflowy_editor/appflowy_editor.dart' as af;

/// 把图片 embed 上记录的宽高解析为显示上限，而不是强制尺寸。
///
/// 尺寸有两个来源：HTML 导入写入的独立 `width/height` 属性，以及上游缩放菜单
/// 写入的 `style: "width: 300.0; height: 600.0; "`，后者覆盖前者，与上游
/// 解析顺序一致。缩放菜单总是同时写入宽和高（未拖动的一边默认取屏幕尺寸），
/// 若当作强制尺寸，图片会在超高的盒子里缩小居中并留下大片空白；作为上限后
/// 图片按原始比例放进去，圆角裁切才能贴合真实画面。上游绘制用 scaleDown，
/// 本就不会放大小图，作为上限后可见画面尺寸与原先一致。
/// 只识别纯数字与 px，百分比/vw 等单位按未设置处理，交给布局宽度兜底。
BoxConstraints diaryImageEmbedBounds(af.Node node) {
  final attributes = node.attributes;
  var width = _parseLength(attributes['width']);
  var height = _parseLength(attributes['height']);
  final style = attributes['style'];
  if (style is String) {
    for (final declaration in style.split(';')) {
      final separator = declaration.indexOf(':');
      if (separator < 0) continue;
      final value = _parseLength(declaration.substring(separator + 1));
      switch (declaration.substring(0, separator).trim()) {
        case 'width':
          width = value ?? width;
        case 'height':
          height = value ?? height;
      }
    }
  }
  return BoxConstraints(
    maxWidth: width ?? double.infinity,
    maxHeight: height ?? double.infinity,
  );
}

/// 比列宽窄的正文图片在行内的水平位置：默认靠行首（缩放菜单缩小后应贴着
/// 正文左缘，而不是悬在中间）；所在行带对齐属性（导入的 HTML 居中/居右段落）
/// 时从之。上游缩放菜单只写宽高，不写对齐。
AlignmentGeometry diaryImageEmbedAlignment(af.Node node) {
  final align = node.attributes['align'];
  return switch (align) {
    'center' => Alignment.center,
    'right' => Alignment.centerRight,
    _ => AlignmentDirectional.centerStart,
  };
}

/// 把缩放菜单的宽高写进图片 embed 的 `style` 属性，保留其中其他声明。
///
/// 与上游缩放菜单同一写法（`width: 300.0; height: 600.0; `），已有数据与上游
/// 解析都按它读；读取时只作上限，见 [diaryImageEmbedBounds]。
String diaryImageStyleWithSize(
  String? style, {
  required double width,
  required double height,
}) {
  final declarations = <String, String>{};
  for (final declaration in (style ?? '').split(';')) {
    final separator = declaration.indexOf(':');
    if (separator < 0) continue;
    declarations[declaration.substring(0, separator).trim()] = declaration
        .substring(separator + 1)
        .trim();
  }
  declarations['width'] = width.toString();
  declarations['height'] = height.toString();
  return declarations.entries
      .map((entry) => '${entry.key}: ${entry.value}; ')
      .join();
}

/// 图片 embed 当前的 `style` 属性（缩放菜单写入的宽高等）；没有时为 null。
String? diaryImageStyleOf(af.Node node) {
  final style = node.attributes['style'];
  return style is String ? style : null;
}

double? _parseLength(Object? raw) {
  if (raw == null) return null;
  var text = raw.toString().trim();
  if (text.endsWith('px')) text = text.substring(0, text.length - 2).trim();
  final value = double.tryParse(text);
  return value != null && value.isFinite && value > 0 ? value : null;
}

/// 正文图片来源与上游保持同一套识别：http(s) 走网络，data URI 解码 base64，
/// 其余视为本地文件（导入时已复制到私有目录）。base64 解码失败时退回文件
/// 分支，由图片的 errorBuilder 统一展示失败占位，而不是在构建期抛异常。
ImageProvider resolveDiaryImageProvider(String source) {
  final uri = Uri.tryParse(source);
  if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
    return NetworkImage(source);
  }
  const base64Marker = 'base64,';
  final marker = source.indexOf(base64Marker);
  if (marker >= 0) {
    try {
      return MemoryImage(
        base64Decode(source.substring(marker + base64Marker.length)),
      );
    } on FormatException {
      // 交给 FileImage 失败后走占位。
    }
  }
  return FileImage(File(source));
}
