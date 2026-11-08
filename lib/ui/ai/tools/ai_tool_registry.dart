// AI 助手的工具清单：唯一的登记处。新工具写好后加进 [aiTools]，再补测试
// （`test/ui/ai/ai_tools_test.dart` 会检查名称唯一、schema 合法、标题有文案、
// 写工具能撤销）。

import 'ai_tool.dart';
import 'ai_tools_app.dart';
import 'ai_tools_calendar.dart';
import 'ai_tools_calendar_writes.dart';
import 'ai_tools_diaries.dart';
import 'ai_tools_diary_writes.dart';
import 'ai_tools_organize.dart';
import 'ai_tools_organize_writes.dart';
import 'ai_tools_settings.dart';

/// 全部工具（顺序即发给模型的顺序；保持稳定，利于服务商的提示缓存）。
const List<AiTool> aiTools = <AiTool>[
  // 查询与前往。
  GetAppContextTool(),
  ReadGuideTool(),
  SearchDiariesTool(),
  ReadDiariesTool(),
  DiaryStatsTool(),
  GetCalendarDayTool(),
  ListTodosTool(),
  ListAnniversariesTool(),
  ListTagsTool(),
  ListNotebooksTool(),
  OpenPageTool(),
  // 日记。
  CreateDiaryTool(),
  AppendToDiaryTool(),
  UpdateDiaryTool(),
  TagDiariesTool(),
  PinDiariesTool(),
  ArchiveDiariesTool(),
  TrashDiariesTool(),
  AddCommentTool(),
  // 标签与日记本。
  CreateTagTool(),
  RenameTagTool(),
  MergeTagsTool(),
  DeleteTagTool(),
  CreateNotebookTool(),
  RenameNotebookTool(),
  AddToNotebookTool(),
  RemoveFromNotebookTool(),
  // 待办、纪念日、这天的心情。
  CreateTodoTool(),
  UpdateTodosTool(),
  CompleteTodosTool(),
  DeleteTodosTool(),
  CreateAnniversaryTool(),
  DeleteAnniversaryTool(),
  SetDayMoodTool(),
  // 设置。
  SetThemeTool(),
  SetAppLanguageTool(),
  SetFontScaleTool(),
  SetFeatureEnabledTool(),
];

final Map<String, AiTool> _byName = <String, AiTool>{
  for (final tool in aiTools) tool.name: tool,
};

AiTool? aiToolByName(String name) => _byName[name];

/// 会改动数据的工具（写与删除类）。
bool aiToolChangesData(AiTool tool) =>
    tool.effect == AiToolEffect.write ||
    tool.effect == AiToolEffect.destructive;

/// 这次运行能用的工具：功能开关、平台，以及 AI 设置里“允许 AI 改动数据”。
List<AiTool> aiAvailableTools(AiToolEnv env) => [
  for (final tool in aiTools)
    if (tool.isAvailable(env) &&
        (env.prefs.agent.allowChanges || !aiToolChangesData(tool)))
      tool,
];
