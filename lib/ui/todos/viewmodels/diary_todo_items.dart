import 'package:flutter/foundation.dart';

import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/diary_blocks/diary_blocks_walk.dart';

/// 日记正文里的一个待办列表项（“转为独立待办”的候选）。
@immutable
class DiaryTodoItem {
  const DiaryTodoItem({required this.text, required this.checked});

  final String text;
  final bool checked;
}

/// 取出日记正文里全部待办列表项（按文档顺序，含嵌套在其他块里的），去掉
/// 空项（纯函数）。正文经 [decodeStoredDiaryBlocks] 读取，历史 Delta、旧节点
/// 与纯文本都能处理；只读，不改动正文。
List<DiaryTodoItem> diaryTodoItems(String content) {
  final document = decodeStoredDiaryBlocks(content);
  return <DiaryTodoItem>[
    for (final (node, _) in walkDiaryBlocks(document))
      if (node[kDiaryBlockTypeKey] == kDiaryBlockTodoList)
        if (diaryBlockText(node).trim() case final text when text.isNotEmpty)
          DiaryTodoItem(
            text: text,
            checked: diaryBlockData(node)[kDiaryBlockCheckedKey] == true,
          ),
  ];
}
