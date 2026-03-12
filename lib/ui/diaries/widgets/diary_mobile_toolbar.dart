import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 编辑器工具项标识。
///
/// 该枚举用于：
/// 1. 设置页拖拽排序；
/// 2. 本地持久化；
/// 3. 悬浮工具栏按顺序渲染。
enum DiaryToolbarItem {
  undo,
  redo,
  bold,
  italic,
  underline,
  strikeThrough,
  inlineCode,
  textColor,
  backgroundColor,
  clearFormat,
  image,
  headerStyle,
  orderedList,
  bulletList,
  checkList,
  codeBlock,
  quote,
  indent,
  link,
}

/// 默认工具栏顺序（当用户未配置或配置异常时兜底）。
const List<DiaryToolbarItem> kDefaultDiaryToolbarOrder = <DiaryToolbarItem>[
  // 轻度日记用户高频功能前置：基础编辑 + 列表/待办 + 图片。
  DiaryToolbarItem.undo,
  DiaryToolbarItem.redo,
  DiaryToolbarItem.bold,
  DiaryToolbarItem.italic,
  DiaryToolbarItem.underline,
  DiaryToolbarItem.bulletList,
  DiaryToolbarItem.checkList,
  DiaryToolbarItem.orderedList,
  DiaryToolbarItem.image,
  DiaryToolbarItem.quote,
  DiaryToolbarItem.headerStyle,
  DiaryToolbarItem.link,
  DiaryToolbarItem.textColor,
  DiaryToolbarItem.backgroundColor,
  DiaryToolbarItem.clearFormat,
  DiaryToolbarItem.strikeThrough,
  DiaryToolbarItem.indent,
  DiaryToolbarItem.inlineCode,
  DiaryToolbarItem.codeBlock,
];

extension DiaryToolbarItemX on DiaryToolbarItem {
  /// 本地持久化键名。
  String get storageKey {
    return switch (this) {
      DiaryToolbarItem.undo => 'undo',
      DiaryToolbarItem.redo => 'redo',
      DiaryToolbarItem.bold => 'bold',
      DiaryToolbarItem.italic => 'italic',
      DiaryToolbarItem.underline => 'underline',
      DiaryToolbarItem.strikeThrough => 'strike_through',
      DiaryToolbarItem.inlineCode => 'inline_code',
      DiaryToolbarItem.textColor => 'text_color',
      DiaryToolbarItem.backgroundColor => 'background_color',
      DiaryToolbarItem.clearFormat => 'clear_format',
      DiaryToolbarItem.image => 'image',
      DiaryToolbarItem.headerStyle => 'header_style',
      DiaryToolbarItem.orderedList => 'ordered_list',
      DiaryToolbarItem.bulletList => 'bullet_list',
      DiaryToolbarItem.checkList => 'check_list',
      DiaryToolbarItem.codeBlock => 'code_block',
      DiaryToolbarItem.quote => 'quote',
      DiaryToolbarItem.indent => 'indent',
      DiaryToolbarItem.link => 'link',
    };
  }

  /// 设置页展示文案。
  String get label {
    return switch (this) {
      DiaryToolbarItem.undo => '撤销',
      DiaryToolbarItem.redo => '重做',
      DiaryToolbarItem.bold => '加粗',
      DiaryToolbarItem.italic => '斜体',
      DiaryToolbarItem.underline => '下划线',
      DiaryToolbarItem.strikeThrough => '删除线',
      DiaryToolbarItem.inlineCode => '行内代码（单行）',
      DiaryToolbarItem.textColor => '文字颜色',
      DiaryToolbarItem.backgroundColor => '背景颜色',
      DiaryToolbarItem.clearFormat => '清除格式',
      DiaryToolbarItem.image => '插入图片',
      DiaryToolbarItem.headerStyle => '标题样式',
      DiaryToolbarItem.orderedList => '有序列表',
      DiaryToolbarItem.bulletList => '无序列表',
      DiaryToolbarItem.checkList => '待办列表',
      DiaryToolbarItem.codeBlock => '代码块（多行）',
      DiaryToolbarItem.quote => '引用',
      DiaryToolbarItem.indent => '缩进（增/减）',
      DiaryToolbarItem.link => '链接',
    };
  }

  /// 工具项默认图标（统一使用 FontAwesome）。
  IconData get iconData {
    return switch (this) {
      DiaryToolbarItem.undo => FontAwesomeIcons.rotateLeft,
      DiaryToolbarItem.redo => FontAwesomeIcons.rotateRight,
      DiaryToolbarItem.bold => FontAwesomeIcons.bold,
      DiaryToolbarItem.italic => FontAwesomeIcons.italic,
      DiaryToolbarItem.underline => FontAwesomeIcons.underline,
      DiaryToolbarItem.strikeThrough => FontAwesomeIcons.strikethrough,
      DiaryToolbarItem.inlineCode => FontAwesomeIcons.code,
      DiaryToolbarItem.textColor => FontAwesomeIcons.palette,
      DiaryToolbarItem.backgroundColor => FontAwesomeIcons.highlighter,
      DiaryToolbarItem.clearFormat => FontAwesomeIcons.eraser,
      DiaryToolbarItem.image => FontAwesomeIcons.image,
      DiaryToolbarItem.headerStyle => FontAwesomeIcons.heading,
      DiaryToolbarItem.orderedList => FontAwesomeIcons.listOl,
      DiaryToolbarItem.bulletList => FontAwesomeIcons.listUl,
      DiaryToolbarItem.checkList => FontAwesomeIcons.squareCheck,
      DiaryToolbarItem.codeBlock => FontAwesomeIcons.fileCode,
      DiaryToolbarItem.quote => FontAwesomeIcons.quoteLeft,
      DiaryToolbarItem.indent => FontAwesomeIcons.indent,
      DiaryToolbarItem.link => FontAwesomeIcons.link,
    };
  }

}

DiaryToolbarItem? _diaryToolbarItemFromStorageKey(String value) {
  for (final item in DiaryToolbarItem.values) {
    if (item.storageKey == value) {
      return item;
    }
  }
  return null;
}

/// 将持久化字符串反序列化为工具栏顺序。
///
/// 为避免旧配置或脏数据影响渲染，会自动去重并补全缺失项。
List<DiaryToolbarItem> decodeDiaryToolbarOrder(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return List<DiaryToolbarItem>.from(kDefaultDiaryToolbarOrder);
  }

  final result = <DiaryToolbarItem>[];
  final seen = <DiaryToolbarItem>{};
  for (final segment in raw.split(',')) {
    final item = _diaryToolbarItemFromStorageKey(segment.trim());
    if (item == null || !seen.add(item)) {
      continue;
    }
    result.add(item);
  }

  for (final item in kDefaultDiaryToolbarOrder) {
    if (seen.add(item)) {
      result.add(item);
    }
  }
  return result;
}

/// 将工具栏顺序编码为可持久化字符串。
String encodeDiaryToolbarOrder(List<DiaryToolbarItem> order) {
  final normalized = _normalizeDiaryToolbarOrder(order);
  return normalized.map((item) => item.storageKey).join(',');
}

/// 构建支持自定义顺序的日记编辑悬浮工具栏。
Widget buildDiaryFloatingToolbar({
  required quill.QuillController controller,
  required List<DiaryToolbarItem> order,
}) {
  final normalizedOrder = _normalizeDiaryToolbarOrder(order);
  return LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      // 外层统一负责横向滚动，避免每个单项工具自身再出现滚动行为。
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                for (var i = 0; i < normalizedOrder.length; i++) ...<Widget>[
                  quill.QuillSimpleToolbar(
                    controller: controller,
                    config: _buildSingleItemConfig(
                      context,
                      normalizedOrder[i],
                      controller,
                    ),
                  ),
                  if (i != normalizedOrder.length - 1) const SizedBox(width: 2),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 统一返回 Quill Embed 渲染器（发布预览与编辑器保持一致）。
List<quill.EmbedBuilder> buildDiaryQuillEmbedBuilders() {
  return FlutterQuillEmbeds.defaultEditorBuilders();
}

/// 对外部传入顺序做去重 + 补全，防止配置异常导致工具项缺失。
List<DiaryToolbarItem> _normalizeDiaryToolbarOrder(List<DiaryToolbarItem> order) {
  if (order.isEmpty) {
    return List<DiaryToolbarItem>.from(kDefaultDiaryToolbarOrder);
  }

  final normalized = <DiaryToolbarItem>[];
  final seen = <DiaryToolbarItem>{};
  for (final item in order) {
    if (seen.add(item)) {
      normalized.add(item);
    }
  }
  for (final item in kDefaultDiaryToolbarOrder) {
    if (seen.add(item)) {
      normalized.add(item);
    }
  }
  return normalized;
}

quill.QuillSimpleToolbarConfig _buildSingleItemConfig(
  BuildContext context,
  DiaryToolbarItem item,
  quill.QuillController controller,
) {
  final colorScheme = Theme.of(context).colorScheme;
  // 显式固定移动端悬浮工具栏图标尺寸，避免受主题密度或系统缩放影响出现“放大”。
  final compactIconTheme = quill.QuillIconTheme(
    iconButtonUnselectedData: quill.IconButtonData(
      iconSize: 16,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.all(4),
      color: colorScheme.onSurface,
      disabledColor: colorScheme.onSurfaceVariant,
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll<Color>(colorScheme.onSurface),
        iconColor: WidgetStatePropertyAll<Color>(colorScheme.onSurface),
      ),
      constraints: BoxConstraints(
        minWidth: 32,
        minHeight: 32,
        maxWidth: 32,
        maxHeight: 32,
      ),
    ),
    iconButtonSelectedData: quill.IconButtonData(
      iconSize: 16,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.all(4),
      color: colorScheme.onPrimaryContainer,
      disabledColor: colorScheme.onSurfaceVariant,
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll<Color>(
          colorScheme.onPrimaryContainer,
        ),
        iconColor: WidgetStatePropertyAll<Color>(
          colorScheme.onPrimaryContainer,
        ),
        backgroundColor: WidgetStatePropertyAll<Color>(
          colorScheme.primaryContainer,
        ),
      ),
      constraints: BoxConstraints(
        minWidth: 32,
        minHeight: 32,
        maxWidth: 32,
        maxHeight: 32,
      ),
    ),
  );

  // 按“单个工具项”生成开关矩阵，保证一个 QuillSimpleToolbar 只渲染一个按钮。
  final showUndo = item == DiaryToolbarItem.undo;
  final showRedo = item == DiaryToolbarItem.redo;
  final showBold = item == DiaryToolbarItem.bold;
  final showItalic = item == DiaryToolbarItem.italic;
  final showUnderline = item == DiaryToolbarItem.underline;
  final showStrikeThrough = item == DiaryToolbarItem.strikeThrough;
  final showInlineCode = item == DiaryToolbarItem.inlineCode;
  final showTextColor = item == DiaryToolbarItem.textColor;
  final showBackgroundColor = item == DiaryToolbarItem.backgroundColor;
  final showClearFormat = item == DiaryToolbarItem.clearFormat;
  final showHeaderStyle = false;
  final showOrderedList = item == DiaryToolbarItem.orderedList;
  final showBulletList = item == DiaryToolbarItem.bulletList;
  final showCheckList = item == DiaryToolbarItem.checkList;
  final showCodeBlock = item == DiaryToolbarItem.codeBlock;
  final showQuote = item == DiaryToolbarItem.quote;
  final showIndent = item == DiaryToolbarItem.indent;
  final showLink = item == DiaryToolbarItem.link;

  // 图片按钮使用自定义拣选并复制到私有目录，避免外部路径失效。
  final embedButtons =
      item == DiaryToolbarItem.image
          ? FlutterQuillEmbeds.toolbarButtons(
            imageButtonOptions: QuillToolbarImageButtonOptions(
              iconData: FontAwesomeIcons.image,
              imageButtonConfig: QuillToolbarImageConfig(
                onRequestPickImage: _pickAndPersistDiaryImage,
              ),
            ),
            videoButtonOptions: null,
            cameraButtonOptions: null,
          )
          : null;

  // 所有工具按钮图标统一映射为 FontAwesome，避免风格不一致。
  final buttonOptions = quill.QuillSimpleToolbarButtonOptions(
    base: quill.QuillToolbarBaseButtonOptions(
      iconSize: 13,
      iconButtonFactor: 1.2,
      iconTheme: compactIconTheme,
    ),
    undoHistory: const quill.QuillToolbarHistoryButtonOptions(
      iconData: FontAwesomeIcons.rotateLeft,
    ),
    redoHistory: const quill.QuillToolbarHistoryButtonOptions(
      iconData: FontAwesomeIcons.rotateRight,
    ),
    bold: const quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.bold,
    ),
    italic: const quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.italic,
    ),
    underLine: const quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.underline,
    ),
    strikeThrough: const quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.strikethrough,
    ),
    inlineCode: const quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.code,
    ),
    color: const quill.QuillToolbarColorButtonOptions(
      iconData: FontAwesomeIcons.palette,
    ),
    backgroundColor: const quill.QuillToolbarColorButtonOptions(
      iconData: FontAwesomeIcons.highlighter,
    ),
    clearFormat: const quill.QuillToolbarClearFormatButtonOptions(
      iconData: FontAwesomeIcons.eraser,
    ),
    listNumbers: const quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.listOl,
    ),
    listBullets: const quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.listUl,
    ),
    toggleCheckList: const quill.QuillToolbarToggleCheckListButtonOptions(
      iconData: FontAwesomeIcons.squareCheck,
    ),
    codeBlock: const quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.fileCode,
    ),
    quote: const quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.quoteLeft,
    ),
    indentIncrease: const quill.QuillToolbarIndentButtonOptions(
      iconData: FontAwesomeIcons.indent,
    ),
    indentDecrease: const quill.QuillToolbarIndentButtonOptions(
      iconData: FontAwesomeIcons.outdent,
    ),
    linkStyle: const quill.QuillToolbarLinkStyleButtonOptions(
      iconData: FontAwesomeIcons.link,
    ),
  );

  // 标题样式属于自定义循环按钮，不依赖 Quill 默认 header 组。
  final customButtons =
      item == DiaryToolbarItem.headerStyle
          ? <quill.QuillToolbarCustomButtonOptions>[
            quill.QuillToolbarCustomButtonOptions(
              icon: const FaIcon(FontAwesomeIcons.heading, size: 14),
              tooltip: context.l10n.tr(
                '标题样式（点击切换）',
                en: 'Header style (tap to cycle)',
              ),
              onPressed: () => _cycleHeaderStyle(controller),
            ),
          ]
          : <quill.QuillToolbarCustomButtonOptions>[];

  return quill.QuillSimpleToolbarConfig(
    // 使用 Wrap 模式，避免每个工具项内部再生成可横向滚动容器。
    multiRowsDisplay: true,
    showDividers: false,
    decoration: const BoxDecoration(color: Colors.transparent),
    showFontFamily: false,
    showFontSize: false,
    showBoldButton: showBold,
    showItalicButton: showItalic,
    showSmallButton: false,
    showUnderLineButton: showUnderline,
    showLineHeightButton: false,
    showStrikeThrough: showStrikeThrough,
    showInlineCode: showInlineCode,
    showColorButton: showTextColor,
    showBackgroundColorButton: showBackgroundColor,
    showClearFormat: showClearFormat,
    showAlignmentButtons: false,
    showLeftAlignment: false,
    showCenterAlignment: false,
    showRightAlignment: false,
    showJustifyAlignment: false,
    showHeaderStyle: showHeaderStyle,
    showListNumbers: showOrderedList,
    showListBullets: showBulletList,
    showListCheck: showCheckList,
    showCodeBlock: showCodeBlock,
    showQuote: showQuote,
    showIndent: showIndent,
    showLink: showLink,
    showUndo: showUndo,
    showRedo: showRedo,
    showDirection: false,
    showSearchButton: false,
    showSubscript: false,
    showSuperscript: false,
    showClipboardCut: false,
    showClipboardCopy: false,
    showClipboardPaste: false,
    customButtons: customButtons,
    embedButtons: embedButtons,
    buttonOptions: buttonOptions,
  );
}

void _cycleHeaderStyle(quill.QuillController controller) {
  final currentHeader =
      controller.getSelectionStyle().attributes[quill.Attribute.header.key];
  final nextHeader = switch (currentHeader?.value) {
    1 => quill.Attribute.h2,
    2 => quill.Attribute.h3,
    3 => quill.Attribute.header,
    _ => quill.Attribute.h1,
  };
  controller.formatSelection(nextHeader);
}

/// 拾取图片并返回可插入编辑器的最终路径。
Future<String?> _pickAndPersistDiaryImage(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    type: FileType.image,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }

  final path = result.files.first.path;
  if (path == null || path.isEmpty) {
    return null;
  }

  return _persistDiaryImage(path);
}

/// 将外部图片复制到应用私有目录，确保日记长期可访问。
Future<String> _persistDiaryImage(String sourcePath) async {
  final sourceFile = File(sourcePath);
  if (!await sourceFile.exists()) {
    return sourcePath;
  }

  final appDir = await getApplicationDocumentsDirectory();
  final imageDir = Directory(p.join(appDir.path, 'diary_images'));
  if (!await imageDir.exists()) {
    await imageDir.create(recursive: true);
  }

  final extension = p.extension(sourcePath);
  final targetName =
      'img_${DateTime.now().microsecondsSinceEpoch}${extension.isEmpty ? '.jpg' : extension}';
  final targetPath = p.join(imageDir.path, targetName);

  await sourceFile.copy(targetPath);
  return targetPath;
}
