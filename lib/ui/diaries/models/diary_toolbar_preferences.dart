import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

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
  video,
  attachment,
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
  DiaryToolbarItem.video,
  DiaryToolbarItem.attachment,
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
      DiaryToolbarItem.video => 'video',
      DiaryToolbarItem.attachment => 'attachment',
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
      DiaryToolbarItem.video => FontAwesomeIcons.video,
      DiaryToolbarItem.attachment => FontAwesomeIcons.paperclip,
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

  String label(AppLocalizations l10n) {
    return switch (this) {
      DiaryToolbarItem.undo => l10n.autoT0006,
      DiaryToolbarItem.redo => l10n.autoT0007,
      DiaryToolbarItem.bold => l10n.autoT0008,
      DiaryToolbarItem.italic => l10n.autoT0009,
      DiaryToolbarItem.underline => l10n.autoT0010,
      DiaryToolbarItem.strikeThrough => l10n.autoT0011,
      DiaryToolbarItem.inlineCode => l10n.autoT0012,
      DiaryToolbarItem.textColor => l10n.autoT0013,
      DiaryToolbarItem.backgroundColor => l10n.autoT0014,
      DiaryToolbarItem.clearFormat => l10n.autoT0015,
      DiaryToolbarItem.image => l10n.autoT0016,
      DiaryToolbarItem.video => l10n.diaryToolbarInsertVideo,
      DiaryToolbarItem.attachment => l10n.diaryToolbarInsertAttachment,
      DiaryToolbarItem.headerStyle => l10n.autoT0017,
      DiaryToolbarItem.orderedList => l10n.autoT0018,
      DiaryToolbarItem.bulletList => l10n.autoT0019,
      DiaryToolbarItem.checkList => l10n.autoT0020,
      DiaryToolbarItem.codeBlock => l10n.autoT0021,
      DiaryToolbarItem.quote => l10n.autoT0022,
      DiaryToolbarItem.indent => l10n.autoT0023,
      DiaryToolbarItem.link => l10n.autoT0024,
      DiaryToolbarItem.currentTime => l10n.diaryToolbarInsertCurrentTime,
      DiaryToolbarItem.recording => l10n.diaryToolbarRecording,
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
