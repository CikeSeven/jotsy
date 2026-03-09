import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  DiaryToolbarItem.undo,
  DiaryToolbarItem.redo,
  DiaryToolbarItem.bold,
  DiaryToolbarItem.italic,
  DiaryToolbarItem.underline,
  DiaryToolbarItem.strikeThrough,
  DiaryToolbarItem.inlineCode,
  DiaryToolbarItem.textColor,
  DiaryToolbarItem.backgroundColor,
  DiaryToolbarItem.clearFormat,
  DiaryToolbarItem.image,
  DiaryToolbarItem.headerStyle,
  DiaryToolbarItem.orderedList,
  DiaryToolbarItem.bulletList,
  DiaryToolbarItem.checkList,
  DiaryToolbarItem.codeBlock,
  DiaryToolbarItem.quote,
  DiaryToolbarItem.indent,
  DiaryToolbarItem.link,
];

extension DiaryToolbarItemX on DiaryToolbarItem {
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

  String get label {
    return switch (this) {
      DiaryToolbarItem.undo => '撤销',
      DiaryToolbarItem.redo => '重做',
      DiaryToolbarItem.bold => '加粗',
      DiaryToolbarItem.italic => '斜体',
      DiaryToolbarItem.underline => '下划线',
      DiaryToolbarItem.strikeThrough => '删除线',
      DiaryToolbarItem.inlineCode => '行内代码',
      DiaryToolbarItem.textColor => '文字颜色',
      DiaryToolbarItem.backgroundColor => '背景颜色',
      DiaryToolbarItem.clearFormat => '清除格式',
      DiaryToolbarItem.image => '插入图片',
      DiaryToolbarItem.headerStyle => '标题样式',
      DiaryToolbarItem.orderedList => '有序列表',
      DiaryToolbarItem.bulletList => '无序列表',
      DiaryToolbarItem.checkList => '任务列表',
      DiaryToolbarItem.codeBlock => '代码块',
      DiaryToolbarItem.quote => '引用',
      DiaryToolbarItem.indent => '缩进',
      DiaryToolbarItem.link => '链接',
    };
  }

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
      DiaryToolbarItem.checkList => FontAwesomeIcons.listCheck,
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
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      children: <Widget>[
        for (var i = 0; i < normalizedOrder.length; i++) ...<Widget>[
          quill.QuillSimpleToolbar(
            controller: controller,
            config: _buildSingleItemConfig(normalizedOrder[i]),
          ),
          if (i != normalizedOrder.length - 1) const SizedBox(width: 2),
        ],
      ],
    ),
  );
}

List<quill.EmbedBuilder> buildDiaryQuillEmbedBuilders() {
  return FlutterQuillEmbeds.defaultEditorBuilders();
}

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

quill.QuillSimpleToolbarConfig _buildSingleItemConfig(DiaryToolbarItem item) {
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
  final showHeaderStyle = item == DiaryToolbarItem.headerStyle;
  final showOrderedList = item == DiaryToolbarItem.orderedList;
  final showBulletList = item == DiaryToolbarItem.bulletList;
  final showCheckList = item == DiaryToolbarItem.checkList;
  final showCodeBlock = item == DiaryToolbarItem.codeBlock;
  final showQuote = item == DiaryToolbarItem.quote;
  final showIndent = item == DiaryToolbarItem.indent;
  final showLink = item == DiaryToolbarItem.link;

  final embedButtons =
      item == DiaryToolbarItem.image
          ? FlutterQuillEmbeds.toolbarButtons(
            imageButtonOptions: QuillToolbarImageButtonOptions(
              imageButtonConfig: QuillToolbarImageConfig(
                onRequestPickImage: _pickAndPersistDiaryImage,
              ),
            ),
            videoButtonOptions: null,
            cameraButtonOptions: null,
          )
          : null;

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
    embedButtons: embedButtons,
  );
}

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
