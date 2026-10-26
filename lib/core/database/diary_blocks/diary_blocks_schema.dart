/// 日记正文的块文档格式（与 AppFlowy Editor 的 `Document.toJson()` 同构）。
///
/// 存储形状：`{"document": {"type": "page", "children": [节点, …]}}`，节点为
/// `{"type": 类型, "data": {…}, "children": [子节点, …]}`（`data` 与
/// `children` 为空时省略，节点 id 不落盘）。文字块的 `data.delta` 是行内
/// Delta：`[{"insert": "文字", "attributes": {…}}, …]`，不含换行结尾。
///
/// 为什么直接采用编辑器的 JSON 而不另定格式：编辑器读写零转换，嵌套块
/// （子节点）天然表达；其余模块（导出、分享、搜索镜像、备份路径改写）只
/// 依赖这里列出的类型与键，是纯 Dart 的 Map 处理，不依赖编辑器包。
///
/// 键名与编辑器内置组件一致（paragraph / heading / bulleted_list / …、
/// `delta` / `level` / `checked` / `align`，行内 `bold` / `strikethrough` /
/// `href` / `font_color` / `bg_color`），编辑器自带的格式命令与 Markdown
/// 快捷输入写出的就是这些键。日记特有的块（代码块语言、录音、附件、视频）
/// 与行内字号档位 `size` 为本应用自定义。颜色值一律为大写 `#AARRGGBB`。
library;

/// 文档根节点类型。
const String kDiaryBlockPage = 'page';

/// 顶层键：`{"document": 根节点}`。
const String kDiaryBlocksDocumentKey = 'document';

// ---- 块类型 ----

const String kDiaryBlockParagraph = 'paragraph';
const String kDiaryBlockHeading = 'heading';
const String kDiaryBlockBulletedList = 'bulleted_list';
const String kDiaryBlockNumberedList = 'numbered_list';
const String kDiaryBlockTodoList = 'todo_list';
const String kDiaryBlockQuote = 'quote';

/// 代码块：`data.delta` 为整块代码（行间以 `\n` 分隔），`data.language`
/// 为 [kCodeBlockPlain] 或已知语言 id，缺省表示未指定（自动识别）。
const String kDiaryBlockCode = 'code';
const String kDiaryBlockDivider = 'divider';

/// 图片：`data.url` 为来源（私有目录路径、http(s) 或 data URI），可带
/// 显示上限 `width` / `height` / `style`（见 diaryImageEmbedBounds）与 `align`。
const String kDiaryBlockImage = 'image';

/// 视频：`data.url` 为来源。
const String kDiaryBlockVideo = 'video';

/// 录音：`data` 为 DiaryAudioAttachment 的字段（`path` / `durationMs` /
/// `name` / `waveform`）。
const String kDiaryBlockAudio = 'audio';

/// 附件：`data` 为 DiaryFileAttachment 的字段（`path` / `name` / `sizeBytes`）。
const String kDiaryBlockAttachment = 'attachment';

/// 认不出的 Quill 嵌入原样保留在 `data.value`，投影回 Delta 时还原，
/// 避免旧数据里未知的嵌入在转换中丢失。
const String kDiaryBlockUnknownEmbed = 'quill_embed';

/// 带行内文字（`data.delta`）的块类型。
const Set<String> kDiaryTextBlockTypes = <String>{
  kDiaryBlockParagraph,
  kDiaryBlockHeading,
  kDiaryBlockBulletedList,
  kDiaryBlockNumberedList,
  kDiaryBlockTodoList,
  kDiaryBlockQuote,
  kDiaryBlockCode,
};

/// 可以挂子块的类型：子块在界面上缩进显示在父块之下，必须与编辑器真正
/// 画出子块的组件一致（上游可缩进的四种类型，测试兜底）。标题、引用、
/// 代码块与媒体不画子块：旧数据里缩进的行遇到它们时挂到更外层，已存的
/// 这类子块读取时提到它后面（见 decodeStoredDiaryBlocks），否则会留在
/// 树里却看不见。
const Set<String> kDiaryContainerBlockTypes = <String>{
  kDiaryBlockParagraph,
  kDiaryBlockBulletedList,
  kDiaryBlockNumberedList,
  kDiaryBlockTodoList,
};

/// 独占一行、没有文字的块（媒体与分隔线）。
const Set<String> kDiaryEmbedBlockTypes = <String>{
  kDiaryBlockDivider,
  kDiaryBlockImage,
  kDiaryBlockVideo,
  kDiaryBlockAudio,
  kDiaryBlockAttachment,
  kDiaryBlockUnknownEmbed,
};

// ---- 节点键 ----

const String kDiaryBlockTypeKey = 'type';
const String kDiaryBlockDataKey = 'data';
const String kDiaryBlockChildrenKey = 'children';

// ---- data 键 ----

const String kDiaryBlockDeltaKey = 'delta';
const String kDiaryBlockLevelKey = 'level';
const String kDiaryBlockCheckedKey = 'checked';
const String kDiaryBlockAlignKey = 'align';
const String kDiaryBlockLanguageKey = 'language';
const String kDiaryBlockUrlKey = 'url';
const String kDiaryBlockPathKey = 'path';
const String kDiaryBlockValueKey = 'value';

/// 对齐取值（缺省为起始侧）。
const String kDiaryAlignCenter = 'center';
const String kDiaryAlignRight = 'right';
const String kDiaryAlignJustify = 'justify';

// ---- 行内属性键 ----

const String kDiaryInlineBold = 'bold';
const String kDiaryInlineItalic = 'italic';
const String kDiaryInlineUnderline = 'underline';
const String kDiaryInlineStrikethrough = 'strikethrough';
const String kDiaryInlineCode = 'code';
const String kDiaryInlineHref = 'href';
const String kDiaryInlineTextColor = 'font_color';
const String kDiaryInlineBackgroundColor = 'bg_color';

/// 字号档位：small / large / huge（或导入保留下来的数字），相对正文字号换算。
const String kDiaryInlineSize = 'size';

/// Quill 行内属性名 → 块文档行内属性名；不在表里的键原样保留。
const Map<String, String> kQuillToDiaryInlineKeys = <String, String>{
  'strike': kDiaryInlineStrikethrough,
  'link': kDiaryInlineHref,
  'color': kDiaryInlineTextColor,
  'background': kDiaryInlineBackgroundColor,
};

/// [kQuillToDiaryInlineKeys] 的反向表。
final Map<String, String> kDiaryToQuillInlineKeys = <String, String>{
  for (final entry in kQuillToDiaryInlineKeys.entries) entry.value: entry.key,
};
