import 'package:flutter/foundation.dart';

import '../../../core/services/diary_font_storage_service.dart';
import '../../../core/services/diary_typography.dart';
import '../../../core/services/font_file_info.dart';

/// 导出用的正文字体：用户在正文排版里选了导入字体时，导出文档跟随它。
///
/// - PDF 嵌入字体本身（[bytes]，由 PDF 写出器判断能否嵌入，不能时回落内置
///   字体）；
/// - Word 与网页不嵌入字体文件（中文字体动辄十几 MB），按 [families] 引用，
///   打开文档的设备装有该字体时显示它，否则由阅读器换用默认字体。
///
/// 内置字体与系统字体没有可交给文档的字体文件，[load] 返回 null，各写出器
/// 保持原有字体。
@immutable
class DiaryExportFont {
  const DiaryExportFont({required this.bytes, required this.families});

  /// 字体文件原样内容（TTC 为整个集合）。
  final Uint8List bytes;

  /// name 表里的字族名，英文名在前（各平台最容易按它匹配），再是中文名与
  /// 其他语言的名称；字体没有 name 表时为空。
  final List<String> families;

  /// 解析导入字体；不是受支持的字体文件时返回 null。
  static DiaryExportFont? fromBytes(Uint8List bytes) {
    final info = readFontFileInfo(bytes);
    if (info == null) {
      return null;
    }
    final names = info.familyNames;
    return DiaryExportFont(
      bytes: bytes,
      families: <String>{
        for (final language in const <String>['en', 'zh', 'und'])
          ?names[language],
        ...names.values,
      }.toList(),
    );
  }

  /// 按正文排版偏好读取导入字体；没选导入字体、字体已被删除或文件读不出
  /// 时返回 null（与应用内正文的回落一致）。
  static Future<DiaryExportFont?> load(
    DiaryTypography typography,
    DiaryFontStorageService storage,
  ) async {
    if (!typography.usesImportedFont) {
      return null;
    }
    final bytes = await storage.readFontBytes(typography.fontId);
    return bytes == null ? null : fromBytes(bytes);
  }
}
