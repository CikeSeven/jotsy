import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_controls.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_layout.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_time_format.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

/// 工具按钮的可见尺寸；触控区经 padded tapTargetSize 扩到
/// [kDiaryToolbarButtonExtent]。「更多」按钮复用同一尺寸。
const BoxConstraints kDiaryToolbarButtonConstraints = BoxConstraints(
  minWidth: 32,
  minHeight: 32,
  maxWidth: 32,
  maxHeight: 32,
);

/// 工具在当前选区上是否“正在生效”（加粗、引用、列表等），供「更多」按钮在
/// 面板收起时提示：收进面板的工具虽然看不见，选中态不能跟着丢。
/// 撤销、插入类等没有选中态的工具恒为 false。
bool isDiaryToolbarItemActive(
  DiaryToolbarItem item,
  Map<String, quill.Attribute> attributes,
) {
  bool has(quill.Attribute attribute) =>
      attributes[attribute.key]?.value != null;
  final list = attributes[quill.Attribute.list.key]?.value;
  return switch (item) {
    DiaryToolbarItem.bold => has(quill.Attribute.bold),
    DiaryToolbarItem.italic => has(quill.Attribute.italic),
    DiaryToolbarItem.underline => has(quill.Attribute.underline),
    DiaryToolbarItem.strikeThrough => has(quill.Attribute.strikeThrough),
    DiaryToolbarItem.inlineCode => has(quill.Attribute.inlineCode),
    DiaryToolbarItem.textColor => has(quill.Attribute.color),
    DiaryToolbarItem.backgroundColor => has(quill.Attribute.background),
    DiaryToolbarItem.headerStyle => has(quill.Attribute.header),
    DiaryToolbarItem.orderedList => list == quill.Attribute.ol.value,
    DiaryToolbarItem.bulletList => list == quill.Attribute.ul.value,
    DiaryToolbarItem.checkList =>
      list == quill.Attribute.checked.value ||
          list == quill.Attribute.unchecked.value,
    DiaryToolbarItem.codeBlock => has(quill.Attribute.codeBlock),
    DiaryToolbarItem.quote => has(quill.Attribute.blockQuote),
    DiaryToolbarItem.indent => has(quill.Attribute.indent),
    DiaryToolbarItem.link => has(quill.Attribute.link),
    DiaryToolbarItem.undo ||
    DiaryToolbarItem.redo ||
    DiaryToolbarItem.clearFormat ||
    DiaryToolbarItem.image ||
    DiaryToolbarItem.video ||
    DiaryToolbarItem.attachment ||
    DiaryToolbarItem.currentTime ||
    DiaryToolbarItem.recording => false,
  };
}

/// 仅负责 Quill 单项工具配置；文件选择与复制由媒体导入控制器处理。
/// 文字颜色与背景颜色不经这里（见 `DiaryToolbarColorButton`）。
quill.QuillSimpleToolbarConfig buildDiaryToolbarItemConfig(
  BuildContext context,
  DiaryToolbarItem item,
  quill.QuillController controller, {
  String? currentTimeFormatPattern,
  VoidCallback? onRecordingPressed,
  bool recordingOpen = false,
  void Function(DiaryMediaKind)? onMediaPressed,
  DiaryMediaKind? activeMediaKind,
  bool mediaImportBusy = false,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  // 显式固定移动端悬浮工具栏图标尺寸，避免受主题密度或系统缩放影响出现“放大”。
  // tapTargetSize 同样写死：桌面平台主题默认 shrinkWrap，按钮会缩到 32dp，
  // 与排布计算用的 kDiaryToolbarButtonExtent（40dp）对不上。
  final compactIconTheme = quill.QuillIconTheme(
    iconButtonUnselectedData: quill.IconButtonData(
      iconSize: 16,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.all(4),
      color: colorScheme.onSurface,
      disabledColor: colorScheme.onSurfaceVariant,
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: ExpressiveControls.shape,
        foregroundColor: WidgetStatePropertyAll<Color>(colorScheme.onSurface),
        iconColor: WidgetStatePropertyAll<Color>(colorScheme.onSurface),
      ),
      constraints: kDiaryToolbarButtonConstraints,
    ),
    iconButtonSelectedData: quill.IconButtonData(
      iconSize: 16,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.all(4),
      color: colorScheme.onPrimaryContainer,
      disabledColor: colorScheme.onSurfaceVariant,
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.padded,
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
      constraints: kDiaryToolbarButtonConstraints,
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

  final mediaKind = switch (item) {
    DiaryToolbarItem.image => DiaryMediaKind.image,
    DiaryToolbarItem.video => DiaryMediaKind.video,
    DiaryToolbarItem.attachment => DiaryMediaKind.attachment,
    _ => null,
  };

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
    if (mediaKind != null)
      quill.QuillToolbarCustomButtonOptions(
        icon: activeMediaKind == mediaKind
            ? ExpressiveLoadingIndicator(
                size: 16,
                semanticLabel: context.l10n.diaryMediaImporting,
              )
            : FaIcon(
                item.iconData,
                size: 14,
                color: mediaImportBusy || recordingOpen
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface,
              ),
        tooltip: item.label(context.l10n),
        onPressed: mediaImportBusy || recordingOpen || onMediaPressed == null
            ? null
            : () => onMediaPressed(mediaKind),
      ),
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
        onPressed: () => insertDiaryToolbarCurrentTime(
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
        onPressed: mediaImportBusy ? null : onRecordingPressed,
      ),
  ];

  return quill.QuillSimpleToolbarConfig(
    // 使用 Wrap 模式，避免每个工具项内部再生成可横向滚动容器。
    multiRowsDisplay: true,
    // 「缩进」的增/减两个按钮靠它隔开，排布按同一间距计算缩进的宽度。
    toolbarSectionSpacing: kDiaryToolbarIndentGap,
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
    // 文字颜色 / 背景颜色由 DiaryToolbarColorButton 渲染，展开卡片内的颜色
    // 面板；Quill 自带的取色对话框是新路由，会抢走正文焦点、收起键盘。
    showColorButton: false,
    showBackgroundColorButton: false,
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
