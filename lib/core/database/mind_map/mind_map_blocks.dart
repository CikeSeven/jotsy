import '../diary_blocks/diary_blocks_codec.dart';
import '../diary_blocks/diary_blocks_schema.dart';
import '../diary_blocks/diary_blocks_walk.dart';
import 'mind_map_document.dart';
import 'mind_map_schema.dart';
import 'mind_map_text.dart';

/// 正文块文档里的导图：`mind_map` 块的构造、识别与读取（纯 Dart）。
///
/// 导图日记 = 正文顶层第一块是 `mode: page` 的 `mind_map` 块、其余顶层块都是
/// 空段落（编辑器偶尔在文末补的空行不影响判断）。标记写在块上而不是靠结构
/// 推断：普通日记删到只剩一张嵌入导图时仍是普通日记。

/// 一个 `mind_map` 块（[page] 为真时整篇日记就是这张导图）。
Map<String, Object?> mindMapBlockNode(
  MindMapDocument map, {
  bool page = false,
}) => <String, Object?>{
  kDiaryBlockTypeKey: kDiaryBlockMindMap,
  kDiaryBlockDataKey: mindMapBlockData(map, page: page),
};

/// `mind_map` 块的 data。
Map<String, Object?> mindMapBlockData(
  MindMapDocument map, {
  bool page = false,
}) => <String, Object?>{
  if (page) kMindMapBlockModeKey: kMindMapModePage,
  kMindMapBlockMapKey: map.toJson(),
};

/// 只有这张导图的正文块文档（导图日记的正文）。
Map<String, Object?> mindMapDiaryDocument(MindMapDocument map) =>
    <String, Object?>{
      kDiaryBlocksDocumentKey: <String, Object?>{
        kDiaryBlockTypeKey: kDiaryBlockPage,
        kDiaryBlockChildrenKey: <Map<String, Object?>>[
          mindMapBlockNode(map, page: true),
        ],
      },
    };

bool isMindMapBlock(Map<String, Object?> node) =>
    node[kDiaryBlockTypeKey] == kDiaryBlockMindMap;

/// 块 data 是否为整篇导图（`mode: page`）。
bool isMindMapPageData(Map<String, Object?> data) =>
    data[kMindMapBlockModeKey] == kMindMapModePage;

/// 从块 data 读出导图。
MindMapDocument mindMapOfBlockData(Map<String, Object?> data) =>
    MindMapDocument.decode(data[kMindMapBlockMapKey]);

/// 从块节点读出导图。
MindMapDocument mindMapOfBlock(Map<String, Object?> node) =>
    mindMapOfBlockData(diaryBlockData(node));

/// 正文是导图日记时返回那张导图，否则为 null。
MindMapDocument? diaryMindMapPage(Map<String, Object?> document) {
  final root = diaryBlocksRoot(document);
  if (root == null) return null;
  final children = diaryBlockChildren(root);
  if (children.isEmpty) return null;
  final first = children.first;
  if (!isMindMapBlock(first) || !isMindMapPageData(diaryBlockData(first))) {
    return null;
  }
  for (final rest in children.skip(1)) {
    if (rest[kDiaryBlockTypeKey] != kDiaryBlockParagraph ||
        diaryBlockText(rest).trim().isNotEmpty ||
        diaryBlockChildren(rest).isNotEmpty) {
      return null;
    }
  }
  return mindMapOfBlock(first);
}

/// 存储原文（`diaries.content`）是导图日记时返回那张导图，否则为 null。先经
/// [storedContentMayHaveMindMap] 预判，普通日记不解析整篇正文。
MindMapDocument? storedDiaryMindMapPage(String content) =>
    storedContentMayHaveMindMap(content)
    ? diaryMindMapPage(decodeStoredDiaryBlocks(content))
    : null;

/// 存储原文里可能有导图（便宜的预判，避免为每张卡片解析整篇正文）。块文档
/// 是紧凑 JSON（`encodeDiaryBlocks`），正文文字里的引号会被转义，不会误中。
bool storedContentMayHaveMindMap(String content) =>
    content.contains(kDiaryMindMapTypePattern);

/// 存储原文里 `mind_map` 块类型的片段（智能日记本规则的 LIKE 同一写法）。
const String kDiaryMindMapTypePattern = '"type":"$kDiaryBlockMindMap"';

/// 块是否没有任何内容（空导图）：正文“有没有内容”的判断用。
bool mindMapBlockIsBlank(Map<String, Object?> data) =>
    mindMapIsBlank(mindMapOfBlockData(data));

/// 块的纯文本镜像。
String mindMapBlockPlainText(Map<String, Object?> data) =>
    mindMapPlainText(mindMapOfBlockData(data));
