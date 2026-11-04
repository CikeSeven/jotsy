import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/edit_diary_page.dart';
import '../providers/diary_detail_provider.dart';
import 'diary_editor_controller.dart' show Position;

/// 从阅读处（预览页、宽窗口日记页的右栏与它的 Enter 快捷键、列表右键菜单，
/// 以及“打开日记时直接编辑”开启时的 `openDiaryPage`）打开编辑页编辑已有的
/// 一篇。
///
/// 返回 true 表示用户在编辑页里删除了这一篇（编辑页以 true 结束），调用方
/// 按“已删除”收尾并给出撤销；否则刷新这一篇的详情（预览里显示的是编辑后
/// 的内容）。经发布页保存时编辑页以日记 id（String）结束，所以结果类型放宽
/// 为 Object?。[context] 在编辑页返回前被卸载时不再刷新。
///
/// [caret]：预览页双击正文处的文字位置，编辑页打开后把光标放在那里并弹出
/// 键盘（见 `EditDiaryPage.initialCaret`）；其余入口不传。
Future<bool> openDiaryEditorFromPreview(
  BuildContext context,
  WidgetRef ref,
  String diaryId, {
  Position? caret,
}) async {
  final result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute<Object?>(
      builder: (BuildContext context) {
        return EditDiaryPage(
          diaryId: diaryId,
          entryMode: EditDiaryEntryMode.edit,
          initialCaret: caret,
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
