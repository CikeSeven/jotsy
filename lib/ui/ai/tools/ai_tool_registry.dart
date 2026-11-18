// AI 助手的工具清单：唯一的登记处。新工具写好后加进 [aiTools]，再补测试
// （`test/ui/ai/ai_tools_test.dart` 会检查名称唯一、schema 合法、标题有文案、
// 写工具能撤销）。

import 'ai_tool.dart';
import 'ai_tools_app.dart';
import 'ai_tools_calendar.dart';
import 'ai_tools_calendar_writes.dart';
import 'ai_tools_diaries.dart';
import 'ai_tools_diary_edit.dart';
import 'ai_tools_diary_writes.dart';
import 'ai_tools_images.dart';
import 'ai_tools_organize.dart';
import 'ai_tools_organize_writes.dart';
import 'ai_tools_preferences.dart';
import 'ai_tools_settings.dart';
import 'ai_tools_template_removals.dart';
import 'ai_tools_template_use.dart';
import 'ai_tools_template_writes.dart';
import 'ai_tools_templates.dart';
import 'ai_tools_todo_list_writes.dart';
import 'ai_tools_todo_status_writes.dart';
import 'ai_tools_todo_writes.dart';
import 'ai_tools_todos.dart';

/// 全部工具（顺序即发给模型的顺序；保持稳定，利于服务商的提示缓存）。
const List<AiTool> aiTools = <AiTool>[
  // 查询与前往。
  GetAppContextTool(),
  ReadGuideTool(),
  SearchDiariesTool(),
  ReadDiariesTool(),
  ViewImagesTool(),
  DiaryStatsTool(),
  GetCalendarDayTool(),
  ListTodosTool(),
  ListTodoListsTool(),
  ListAnniversariesTool(),
  ListTagsTool(),
  ListNotebooksTool(),
  ListTemplatesTool(),
  GetTemplateTool(),
  GetSettingsTool(),
  OpenPageTool(),
  // 日记。
  CreateDiaryTool(),
  EditDiaryTool(),
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
  // 日记模板。
  CreateTemplateTool(),
  UpdateTemplateTool(),
  DeleteTemplateTool(),
  ResetTemplateTool(),
  RestoreTemplatesTool(),
  ReorderTemplatesTool(),
  SetTemplateAutoApplyTool(),
  SetNotebookTemplateTool(),
  CreateDiaryFromTemplateTool(),
  // 待办与待办清单。
  CreateTodoTool(),
  UpdateTodosTool(),
  CompleteTodosTool(),
  ReopenTodosTool(),
  EditTodoStepsTool(),
  DeleteTodosTool(),
  CreateTodoListTool(),
  RenameTodoListTool(),
  DeleteTodoListTool(),
  // 纪念日、这天的心情。
  CreateAnniversaryTool(),
  DeleteAnniversaryTool(),
  SetDayMoodTool(),
  // 设置。
  SetThemeTool(),
  SetAppLanguageTool(),
  SetFontScaleTool(),
  SetFeatureEnabledTool(),
  ChangeSettingsTool(),
];

final Map<String, AiTool> _byName = <String, AiTool>{
  for (final tool in aiTools) tool.name: tool,
};

/// 已经撤下、但以前的对话记录里还有调用的工具 → 接手它的工具：卡片标题、
/// 可读详情与“撤销”照常（撤销数据的格式相同）。不发给模型。
/// - `append_to_diary`（在末尾追加正文）：由 `edit_diary` 取代，撤销同样是
///   写回原正文。
const Map<String, String> _retiredTools = <String, String>{
  'append_to_diary': 'edit_diary',
};

AiTool? aiToolByName(String name) =>
    _byName[name] ?? _byName[_retiredTools[name]];

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
