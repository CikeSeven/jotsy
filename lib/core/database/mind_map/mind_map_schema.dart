/// 思维导图文档的键名与上限（纯 Dart，正文、导出、导入与同步共用）。
///
/// 导图存在日记正文的 `mind_map` 块里（见 diary_blocks_schema.dart 的
/// `kDiaryBlockMindMap`）：
///
/// ```json
/// {"type": "mind_map", "data": {"mode": "page", "map": {导图文档}}}
/// ```
///
/// `mode` 为 `page` 时这篇日记就是一张导图（正文只有这一块），没有 `mode`
/// 时是普通日记里嵌入的导图卡片。导图文档：
///
/// ```json
/// {"v": 1, "root": 节点, "structure": "mind_map", "theme": "follow",
///  "line": "curve", "rainbow": true, "spacing": "standard", "grid": false,
///  "relations": […], "summaries": […]}
/// ```
///
/// 节点：`{"id", "text", "delta", "children": [节点…], "collapsed", "side",
/// "style", "icons", "labels", "note", "href", "image", "task", "boundary"}`，
/// 空值与缺省值不落盘。结构、主题、连线与间距存原文字符串：新版本写出的取值旧版本
/// 认不出时按缺省显示，但原样写回，不丢。认不出的键同样原样保留（见
/// mind_map_document.dart 的 `extra`）。
library;

/// 当前文档版本。
const int kMindMapVersion = 1;

// ---- 文档键 ----

const String kMindMapVersionKey = 'v';
const String kMindMapRootKey = 'root';
const String kMindMapStructureKey = 'structure';
const String kMindMapThemeKey = 'theme';
const String kMindMapLineKey = 'line';
const String kMindMapRainbowKey = 'rainbow';
const String kMindMapSpacingKey = 'spacing';
const String kMindMapGridKey = 'grid';
const String kMindMapRelationsKey = 'relations';
const String kMindMapSummariesKey = 'summaries';

// ---- 节点键 ----

const String kMindMapNodeIdKey = 'id';
const String kMindMapNodeTextKey = 'text';

/// 文字的局部样式：AppFlowy delta 同形的
/// `[{"insert": 文字, "attributes": {样式}}…]`，各段 insert 拼起来必须等于
/// `text`（对不上就当没有：旧版本改了文字后不显示错位的样式）。属性名与
/// `style` 同一套（`bold` / `italic` / `underline` / `strike` 为三态：false
/// 是在整条样式之上局部取消；`color` / `highlight` 按原色存）。读写只经
/// mind_map_rich_text.dart；`text` 仍是唯一的权威文字（搜索、字数、AI、
/// 大纲与各文件格式都只读它）。
const String kMindMapNodeDeltaKey = 'delta';
const String kMindMapNodeChildrenKey = 'children';
const String kMindMapNodeCollapsedKey = 'collapsed';

/// 根的子节点固定在哪一侧（`l` / `r`），只在左右平衡的结构里生效；缺省时
/// 由布局按子树高度分配。
const String kMindMapNodeSideKey = 'side';
const String kMindMapSideLeft = 'l';
const String kMindMapSideRight = 'r';

/// 节点样式覆盖（对象）：`fill` / `branch`（`#AARRGGBB` 种子色，按明暗
/// 换算）、`color` / `highlight`（`#AARRGGBB` 原色，与正文的文字色 / 背景色
/// 同一套）、`shape`、`bold` / `italic` / `underline` / `strike`（bool）、
/// `size`（s / m / l / xl）。
const String kMindMapNodeStyleKey = 'style';
const String kMindMapNodeIconsKey = 'icons';
const String kMindMapNodeLabelsKey = 'labels';
const String kMindMapNodeNoteKey = 'note';

/// 链接：网址，或日记链接的内部地址（`jotsy://diary/<id>`，与正文的
/// `href` 同一写法，反向链接的 LIKE 查询因此能找到导图节点）。
const String kMindMapNodeHrefKey = 'href';

/// 图片：`{"url": 托管路径, "w": 宽, "h": 高}`。
const String kMindMapNodeImageKey = 'image';
const String kMindMapNodeTaskKey = 'task';
const String kMindMapNodeBoundaryKey = 'boundary';

// ---- 样式键 ----

const String kMindMapStyleFillKey = 'fill';
const String kMindMapStyleColorKey = 'color';
const String kMindMapStyleBranchKey = 'branch';
const String kMindMapStyleShapeKey = 'shape';
const String kMindMapStyleBoldKey = 'bold';
const String kMindMapStyleItalicKey = 'italic';
const String kMindMapStyleStrikeKey = 'strike';

/// 文字下划线（与形状里的“下划线”不同：那是节点下方的一条线）。
const String kMindMapStyleUnderlineKey = 'underline';

/// 文字高亮：字后面的底色（原色，可带透明度），与节点框的底色 `fill` 不同，
/// 不带形状的主题也能用。
const String kMindMapStyleHighlightKey = 'highlight';
const String kMindMapStyleSizeKey = 'size';

// ---- 正文块 data 键 ----

/// `mind_map` 块的显示方式：[kMindMapModePage] 为整篇日记就是这张导图，
/// 缺省为嵌入在普通日记里的卡片。
const String kMindMapBlockModeKey = 'mode';
const String kMindMapModePage = 'page';

/// `mind_map` 块里的导图文档。
const String kMindMapBlockMapKey = 'map';

// ---- 上限 ----

/// 一张导图最多的节点数：编辑与导入在此为止，读取时不截断已有数据。
const int kMindMapMaxNodes = 2000;

/// 编辑时允许的最大层级（根为 0）。
const int kMindMapMaxDepth = 32;

/// 读取时递归解析的最大深度：更深的子树不解析、原文保留在节点的 `extra`
/// 里写回，防止异常数据压垮调用栈。
const int kMindMapParseDepthLimit = 64;

/// 单个节点文字的最大长度（字符）。
const int kMindMapMaxTextLength = 2000;
