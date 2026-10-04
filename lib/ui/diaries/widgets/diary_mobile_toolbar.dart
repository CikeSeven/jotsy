import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:node_diary/app/theme/expressive_controls.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:node_diary/ui/diaries/widgets/diary_audio_embed_builder.dart';

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
  currentTime,
  recording,
}

/// 默认工具栏顺序（当用户未配置或配置异常时兜底）。
const List<DiaryToolbarItem> kDefaultDiaryToolbarOrder = <DiaryToolbarItem>[
  // 轻度日记用户高频功能前置：基础操作 + 录音/媒体插入 + 基础排版 + 列表/待办。
  DiaryToolbarItem.undo,
  DiaryToolbarItem.redo,
  DiaryToolbarItem.recording,
  DiaryToolbarItem.bold,
  DiaryToolbarItem.italic,
  DiaryToolbarItem.underline,
  DiaryToolbarItem.bulletList,
  DiaryToolbarItem.checkList,
  DiaryToolbarItem.orderedList,
  DiaryToolbarItem.image,
  DiaryToolbarItem.currentTime,
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
      DiaryToolbarItem.currentTime => 'current_time',
      DiaryToolbarItem.recording => 'recording',
    };
  }

  /// 工具项默认图标（统一使用 FontAwesome）。
  FaIconData get iconData {
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
      DiaryToolbarItem.currentTime => FontAwesomeIcons.clock,
      DiaryToolbarItem.recording => FontAwesomeIcons.microphone,
    };
  }
}

DiaryToolbarItem? _diaryToolbarItemFromStorageKey(String value) {
  // Keep order/visibility settings from the briefly shipped speech-input tool.
  if (value == 'voice_input') return DiaryToolbarItem.recording;
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

/// 将持久化字符串反序列化为“隐藏工具项”集合。
///
/// 这里持久化隐藏项而不是启用项，是为了让未来新增工具默认出现在悬浮工具栏；
/// 只有用户明确取消勾选过的工具才会被过滤掉。
Set<DiaryToolbarItem> decodeDiaryToolbarHiddenItems(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return <DiaryToolbarItem>{};
  }

  final hiddenItems = <DiaryToolbarItem>{};
  for (final segment in raw.split(',')) {
    final item = _diaryToolbarItemFromStorageKey(segment.trim());
    if (item != null) {
      hiddenItems.add(item);
    }
  }
  return hiddenItems;
}

/// 将隐藏工具项集合编码为可持久化字符串。
String encodeDiaryToolbarHiddenItems(Set<DiaryToolbarItem> hiddenItems) {
  final normalized = <DiaryToolbarItem>[];
  for (final item in kDefaultDiaryToolbarOrder) {
    if (hiddenItems.contains(item)) {
      normalized.add(item);
    }
  }
  return normalized.map((item) => item.storageKey).join(',');
}

/// 按用户排序输出启用的工具项。
List<DiaryToolbarItem> filterEnabledDiaryToolbarOrder(
  List<DiaryToolbarItem> order,
  Set<DiaryToolbarItem> hiddenItems,
) {
  final normalized = _normalizeDiaryToolbarOrder(order);
  if (hiddenItems.isEmpty) {
    return normalized;
  }
  return normalized
      .where((DiaryToolbarItem item) => !hiddenItems.contains(item))
      .toList(growable: false);
}

/// 构建支持自定义顺序的日记编辑悬浮工具栏。
Widget buildDiaryFloatingToolbar({
  required quill.QuillController controller,
  required List<DiaryToolbarItem> order,
  Set<DiaryToolbarItem> hiddenItems = const <DiaryToolbarItem>{},
  String? currentTimeFormatPattern,
  VoidCallback? onRecordingPressed,
  bool recordingOpen = false,
}) {
  final normalizedOrder = filterEnabledDiaryToolbarOrder(order, hiddenItems);
  if (normalizedOrder.isEmpty) {
    return const SizedBox.shrink();
  }
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
                      currentTimeFormatPattern: currentTimeFormatPattern,
                      onRecordingPressed: onRecordingPressed,
                      recordingOpen: recordingOpen,
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
///
/// [onImageClicked] 仅用于阅读态覆盖图片默认菜单；编辑态不传入时仍保留
/// flutter_quill_extensions 自带的图片操作菜单，避免影响编辑/调整尺寸流程。
List<quill.EmbedBuilder> buildDiaryQuillEmbedBuilders({
  void Function(String imageSource)? onImageClicked,
}) {
  if (onImageClicked == null || kIsWeb) {
    return [
      ...FlutterQuillEmbeds.defaultEditorBuilders(),
      const DiaryAudioEmbedBuilder(),
    ];
  }

  return [
    ...FlutterQuillEmbeds.editorBuilders(
      imageEmbedConfig: QuillEditorImageEmbedConfig(
        onImageClicked: onImageClicked,
      ),
    ),
    const DiaryAudioEmbedBuilder(),
  ];
}

/// 对外部传入顺序做去重 + 补全，防止配置异常导致工具项缺失。
List<DiaryToolbarItem> _normalizeDiaryToolbarOrder(
  List<DiaryToolbarItem> order,
) {
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
  quill.QuillController controller, {
  String? currentTimeFormatPattern,
  VoidCallback? onRecordingPressed,
  bool recordingOpen = false,
}) {
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
        shape: ExpressiveControls.shape,
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
        shape: WidgetStateProperty.resolveWith(
          (states) => RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              states.contains(WidgetState.pressed) ? 8 : 12,
            ),
          ),
        ),
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
  final showCurrentTime = item == DiaryToolbarItem.currentTime;
  final showRecording = item == DiaryToolbarItem.recording;

  // 图片按钮使用自定义拣选并复制到私有目录，避免外部路径失效。
  final embedButtons = item == DiaryToolbarItem.image
      ? FlutterQuillEmbeds.toolbarButtons(
          imageButtonOptions: QuillToolbarImageButtonOptions(
            iconData: FontAwesomeIcons.image.data,
            imageButtonConfig: QuillToolbarImageConfig(
              onRequestPickImage: _pickAndPersistDiaryImage,
            ),
          ),
          videoButtonOptions: null,
          cameraButtonOptions: null,
        )
      : null;

  // Quill 的 iconData API 仍只接受 Flutter IconData，因此仅在此边界解包
  // FontAwesome 11 的 .data；设置预览继续使用同源 FaIconData + FaIcon。
  final buttonOptions = quill.QuillSimpleToolbarButtonOptions(
    base: quill.QuillToolbarBaseButtonOptions(
      iconSize: 13,
      iconButtonFactor: 1.2,
      iconTheme: compactIconTheme,
    ),
    undoHistory: quill.QuillToolbarHistoryButtonOptions(
      iconData: FontAwesomeIcons.rotateLeft.data,
    ),
    redoHistory: quill.QuillToolbarHistoryButtonOptions(
      iconData: FontAwesomeIcons.rotateRight.data,
    ),
    bold: quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.bold.data,
    ),
    italic: quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.italic.data,
    ),
    underLine: quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.underline.data,
    ),
    strikeThrough: quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.strikethrough.data,
    ),
    inlineCode: quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.code.data,
    ),
    color: quill.QuillToolbarColorButtonOptions(
      iconData: FontAwesomeIcons.palette.data,
    ),
    backgroundColor: quill.QuillToolbarColorButtonOptions(
      iconData: FontAwesomeIcons.highlighter.data,
    ),
    clearFormat: quill.QuillToolbarClearFormatButtonOptions(
      iconData: FontAwesomeIcons.eraser.data,
    ),
    listNumbers: quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.listOl.data,
    ),
    listBullets: quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.listUl.data,
    ),
    toggleCheckList: quill.QuillToolbarToggleCheckListButtonOptions(
      iconData: FontAwesomeIcons.squareCheck.data,
    ),
    codeBlock: quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.fileCode.data,
    ),
    quote: quill.QuillToolbarToggleStyleButtonOptions(
      iconData: FontAwesomeIcons.quoteLeft.data,
    ),
    indentIncrease: quill.QuillToolbarIndentButtonOptions(
      iconData: FontAwesomeIcons.indent.data,
    ),
    indentDecrease: quill.QuillToolbarIndentButtonOptions(
      iconData: FontAwesomeIcons.outdent.data,
    ),
    linkStyle: quill.QuillToolbarLinkStyleButtonOptions(
      iconData: FontAwesomeIcons.link.data,
    ),
  );

  final customButtons = <quill.QuillToolbarCustomButtonOptions>[
    if (item == DiaryToolbarItem.headerStyle)
      quill.QuillToolbarCustomButtonOptions(
        icon: const FaIcon(FontAwesomeIcons.heading, size: 14),
        tooltip: context.l10n.autoT0208,
        onPressed: () => _cycleHeaderStyle(controller),
      ),
    if (showCurrentTime)
      quill.QuillToolbarCustomButtonOptions(
        icon: const FaIcon(FontAwesomeIcons.clock, size: 14),
        tooltip: context.l10n.diaryToolbarInsertCurrentTime,
        onPressed: () => _insertCurrentSystemTime(
          context,
          controller,
          formatPattern: currentTimeFormatPattern,
        ),
      ),
    if (showRecording)
      quill.QuillToolbarCustomButtonOptions(
        icon: FaIcon(
          FontAwesomeIcons.microphone,
          size: 14,
          color: recordingOpen ? colorScheme.primary : colorScheme.onSurface,
        ),
        tooltip: context.l10n.diaryToolbarRecording,
        onPressed: onRecordingPressed,
      ),
  ];

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
    customButtons: customButtons,
    embedButtons: embedButtons,
    buttonOptions: buttonOptions,
  );
}

void _cycleHeaderStyle(quill.QuillController controller) {
  final currentHeader = controller
      .getSelectionStyle()
      .attributes[quill.Attribute.header.key];
  final nextHeader = switch (currentHeader?.value) {
    1 => quill.Attribute.h2,
    2 => quill.Attribute.h3,
    3 => quill.Attribute.header,
    _ => quill.Attribute.h1,
  };
  controller.formatSelection(nextHeader);
}

/// 将当前系统时间插入到编辑器当前选区。
///
/// 如果用户已选中文字，则替换选区；如果编辑器暂时没有有效选区，则插入到文档末尾。
void _insertCurrentSystemTime(
  BuildContext context,
  quill.QuillController controller, {
  String? formatPattern,
}) {
  final now = DateTime.now();
  final insertedText = formatDiaryToolbarCurrentTime(
    context.l10n,
    now,
    customPattern: formatPattern,
  );
  final documentLength = controller.document.length;
  final selection = controller.selection;
  final start = selection.isValid
      ? _clampQuillOffset(selection.start, documentLength)
      : _clampQuillOffset(documentLength - 1, documentLength);
  final end = selection.isValid
      ? _clampQuillOffset(selection.end, documentLength)
      : start;
  final replaceLength = end - start;
  controller.replaceText(
    start,
    replaceLength < 0 ? 0 : replaceLength,
    insertedText,
    TextSelection.collapsed(offset: start + insertedText.length),
  );
}

const String kDefaultDiaryToolbarCurrentTimeFormat = 'M月d日 HH:mm';

String formatDiaryToolbarCurrentTime(
  AppLocalizations l10n,
  DateTime value, {
  String? customPattern,
}) {
  final local = value.toLocal();
  final normalizedPattern = customPattern?.trim();
  if (normalizedPattern != null && normalizedPattern.isNotEmpty) {
    return DateFormat(normalizedPattern, l10n.localeName).format(local);
  }
  return DateFormat(kDefaultDiaryToolbarCurrentTimeFormat, 'zh').format(local);
}

bool isValidDiaryToolbarCurrentTimeFormat(
  AppLocalizations l10n,
  String formatPattern,
) {
  final normalized = formatPattern.trim();
  if (normalized.isEmpty) {
    return true;
  }
  try {
    formatDiaryToolbarCurrentTime(
      l10n,
      DateTime(2026, 3, 11, 21, 30),
      customPattern: normalized,
    );
    return true;
  } catch (_) {
    return false;
  }
}

int _clampQuillOffset(int offset, int documentLength) {
  final maxOffset = documentLength <= 0 ? 0 : documentLength - 1;
  if (offset < 0) {
    return maxOffset;
  }
  if (offset > maxOffset) {
    return maxOffset;
  }
  return offset;
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
