// AI 助手的工具清单：唯一的登记处。新工具写好后加进 [aiTools]，再补测试
// （`test/ui/ai/ai_tools_test.dart` 会检查名称唯一、schema 合法、标题有文案）。

import 'ai_tool.dart';
import 'ai_tools_app.dart';
import 'ai_tools_calendar.dart';
import 'ai_tools_diaries.dart';
import 'ai_tools_organize.dart';

/// 全部工具（顺序即发给模型的顺序；保持稳定，利于服务商的提示缓存）。
const List<AiTool> aiTools = <AiTool>[
  GetAppContextTool(),
  SearchDiariesTool(),
  ReadDiariesTool(),
  DiaryStatsTool(),
  GetCalendarDayTool(),
  ListTodosTool(),
  ListAnniversariesTool(),
  ListTagsTool(),
  ListNotebooksTool(),
  OpenPageTool(),
];

final Map<String, AiTool> _byName = <String, AiTool>{
  for (final tool in aiTools) tool.name: tool,
};

AiTool? aiToolByName(String name) => _byName[name];

/// 这次运行能用的工具（功能开关、平台）。
List<AiTool> aiAvailableTools(AiToolEnv env) => [
  for (final tool in aiTools)
    if (tool.isAvailable(env)) tool,
];
