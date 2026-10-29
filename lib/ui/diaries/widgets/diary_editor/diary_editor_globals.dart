import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';

/// 上游编辑器的全局登记（进程内只做一次）。
///
/// 为什么是全局：AppFlowy 把“哪些行内属性随输入沿用”登记在静态可变列表
/// [af.AppFlowyRichTextKeys] 上，所有编辑器实例共用，没有按实例配置的入口。
/// 这里把应用自己的行内属性补进去，必须在任何编辑器构建之前完成——
/// [DiaryEditor] 在 `initState` 里调用；重复调用不重复添加。
///
/// 目前登记：
/// - 字号 `size`（[kDiaryInlineSize]，工具栏「字号」面板写入）：
///   - `supportSliced`：在带字号的文字后面（含段首、紧挨着的第一个字带
///     字号时）接着打字，新字沿用同一字号。上游在段首切取属性时，只要有一个
///     属性不在这张表里就整组放弃；
///   - `supportToggled`：折叠光标上选了字号后接着打的字带上它（上游输入时在
///     调试模式下断言“下次输入”的样式键都在这张表里）。选“正文”时写入 null，
///     上游把它原样并进新字的属性（与关闭粗体相同），渲染按正文字号。
void ensureDiaryEditorGlobals() {
  if (_registered) return;
  _registered = true;
  for (final keys in [
    af.AppFlowyRichTextKeys.supportSliced,
    af.AppFlowyRichTextKeys.supportToggled,
  ]) {
    if (!keys.contains(kDiaryInlineSize)) keys.add(kDiaryInlineSize);
  }
}

bool _registered = false;
