import '../../../utils/tri_state_pick.dart';

export '../../../utils/tri_state_pick.dart';

// 日记本收录选择器的三态与勾选状态：通用三态选择（TriStatePick 等，多选
// 日记的标签面板共用同一套）以日记本业务 id 为键的别名。

/// 一本日记本对“这批日记”的收录状态：全都在 / 部分在 / 都不在。
typedef NotebookPickState = TriStatePick;

/// 收录选择器的结果：[TriStatePickResult.add] 里的每本把这批日记全部收进，
/// [TriStatePickResult.remove] 里的每本把它们全部移出。
typedef NotebookPickerResult = TriStatePickResult<String>;

/// 收录选择器的勾选状态；点按循环见 [TriStatePickSelection]。
typedef NotebookPickSelection = TriStatePickSelection<String>;

/// 由每篇日记所在的本子（`getNotebookIdsForDiaries` 的结果）算出各本子的
/// 三态：这批日记全在某本里为 all，只有部分在为 some；一篇都不在的本子不
/// 出现在结果里（读取方按 none 处理）。[membership] 为空时结果也为空。
Map<String, NotebookPickState> notebookPickStatesFor(
  Map<String, Set<String>> membership,
) => triStatePicksFor<String>(membership.values);
