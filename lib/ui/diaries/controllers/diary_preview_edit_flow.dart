import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/edit_diary_page.dart';
import '../providers/diary_detail_provider.dart';

/// 从阅读处（预览页、宽窗口日记页的右栏与它的 Enter 快捷键）打开编辑页
/// 编辑已有的一篇。
///
/// 返回 true 表示用户在编辑页里删除了这一篇（编辑页以 true 结束），调用方
/// 按“已删除”收尾并给出撤销；否则刷新这一篇的详情（预览里显示的是编辑后
/// 的内容）。经发布页保存时编辑页以日记 id（String）结束，所以结果类型放宽
/// 为 Object?。[context] 在编辑页返回前被卸载时不再刷新。
Future<bool> openDiaryEditorFromPreview(
  BuildContext context,
  WidgetRef ref,
  String diaryId,
) async {
  final result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute<Object?>(
      builder: (BuildContext context) {
        return EditDiaryPage(
          diaryId: diaryId,
          entryMode: EditDiaryEntryMode.edit,
        );
      },
    ),
  );
  if (result == true) {
    return true;
  }
  if (context.mounted) {
    ref.invalidate(diaryDetailProvider(diaryId));
  }
  return false;
}
