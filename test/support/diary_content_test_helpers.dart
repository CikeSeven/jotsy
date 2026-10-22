import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_to_delta.dart';

/// 导入器测试继续按文字、行格式与嵌入断言语义；存储结构由块文档专项测试
/// 验证，避免每个来源的测试都依赖正文 JSON 的外层布局。
List<Map<String, Object?>> diaryContentQuillOps(String content) =>
    diaryBlocksToQuillOps(decodeStoredDiaryBlocks(content));
