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
/// - 上标 / 下标 `script`（[kDiaryInlineScript]，工具栏「上标」「下标」写入）：
///   与字号同理——在上下标文字后面（含段首）接着打字沿用它；折叠光标上点了
///   上标 / 下标后接着打的字带上它，再点一次写入 null 即恢复普通文字。
/// - 提示块（[kDiaryBlockCallout]）登记进 [af.convertibleBlockTypes]：光标在
///   提示块开头按退格时转为正文段落（与引用、标题、列表相同），而不是并进
///   上一块。软键盘的删除走上游输入法回调、直接调用同一条“转为段落”命令，
///   不经快捷键列表，所以只能在这张全局表里登记。
/// - 折叠块（[kDiaryBlockToggleList]）：
///   - 登记进 [af.indentableBlockTypes]：上游的缩进 / 取消缩进（Tab、工具栏
///     「缩进」）只认这张表——折叠块后面的段落缩进即成为它的子块（折叠的
///     内容），折叠块里的内容也能取消缩进移出来；折叠块自己也能缩进。登记
///     后这张表与 [kDiaryContainerBlockTypes] 严格相等（测试兜底）：能挂子块的
///     就是编辑器画得出子块、能缩进进去的那几种；
///   - 登记进 [af.convertibleBlockTypes]：标题开头按退格原地转为正文段落，
///     子块（折叠的内容）留在段落下面，理由同提示块。
void ensureDiaryEditorGlobals() {
  if (_registered) return;
  _registered = true;
  if (!af.convertibleBlockTypes.contains(kDiaryBlockCallout)) {
    af.convertibleBlockTypes.add(kDiaryBlockCallout);
  }
  if (!af.convertibleBlockTypes.contains(kDiaryBlockToggleList)) {
    af.convertibleBlockTypes.add(kDiaryBlockToggleList);
  }
  af.indentableBlockTypes.add(kDiaryBlockToggleList);
  for (final keys in [
    af.AppFlowyRichTextKeys.supportSliced,
    af.AppFlowyRichTextKeys.supportToggled,
  ]) {
    for (final key in [kDiaryInlineSize, kDiaryInlineScript]) {
      if (!keys.contains(key)) keys.add(key);
    }
  }
}

bool _registered = false;
