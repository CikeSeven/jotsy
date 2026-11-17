# AI 助手

> 专题约束，与 AGENTS.md 同等效力；改动本主题前先读本文件，新规则写在这里。界面规格见 DESIGN.md §5.29；接口、数据与提示词见 `docs/ai_assistant.md`。

## 总则
- 必须：功能管理里默认关闭，只用用户自己配置的服务；请求都由用户点按触发，唯一的自动行为“发表后自动回应”默认关闭。
- 必须：发请求前一律经 `confirmAiSend` 按隐私设置确认，禁止绕过；智能体每轮最多确认一次。
- 必须：入口只在配好服务且所属模块开启时出现，总入口为 `openAiAssistant`；新增入口补“关闭 / 未配置时不出现”的测试。
- 必须：协议只经 `AiChatClient`，请求只经 `AiService`（生成中一律可停止）；HTTP 只用 `dart:io`，禁止引入第三方 AI SDK。
- 禁止：硬编码模型列表或按模型名猜能力：预设不带模型；图片与思考默认开，被拒后降级重试并记住；带工具被拒时不得悄悄去掉工具重发。
- 必须：提示词只在 ARB（`aiPrompt*`）；例外：工具名、说明与参数 schema 是英文接口定义，不进 ARB。

## 数据与隐私
- 必须：服务商配置（含密钥）与用量只存 `AiProviderStore`，不随备份、不同步；偏好只存 JSON 键 `app.settings.ai_prefs`（随备份，不含密钥）。
- 必须：AI 内容只存 `ai_conversations` / `ai_messages` / `ai_results`：随完整备份，合并按业务 id，日记包不带，不同步；彻底删除日记时同事务删其回应。
- 必须：多篇日记只经 `getAiContextDiaries`（排除私密、回收站、未解封胶囊与 AI 隐私排除项），禁止自拼查询；智能体读全文时私密一律不给。
- 必须：单篇功能经 `aiDiaryAllowed`，私密日记只在打开“允许对私密日记使用 AI”后可用。
- 必须：引用写作 `[Dn]`，复制、分享、另存时去掉；正文写回只经 `diary_ai_editing.dart`（一步撤销），写作面板禁止放进工具栏卡片。
- 必须：另存为日记只经 `saveAiTextAsDiary`（原样未动不算草稿）；例外：智能体 `create_diary` 经 `publishNewDiaryDirectly`，可撤销。
- 必须：附图存进 `ai_messages.images`，存储管理删除只写墓碑；超出请求上限时永久换成占位，禁止悄悄丢图；写进日记只认 P 编号，禁止让模型给本机路径。

## 智能体
- 必须：工具只登记在 `ai_tool_registry.dart`，读写只经现有 ops / 控制器，禁止另写 SQL；打开页面只经 `AiDestination`；功能关闭或本平台没有的不出现。
- 必须：新增功能须评估接入工具与前往页面；接收日记 id 的参数登记 `AiTool.diaryIdArgs`（`ai_tools_test.dart` 兜底）。
- 必须：协议正常收尾才执行调用，失败回传模型、不自动重试；被中断的步骤禁止重放。
- 必须：历史只经 `aiAgentHistory` 原样回放，禁止拼本地摘要；会变的内容只放本轮问题、不进系统提示词，以免缓存失效。
- 必须：改动类工具记下涉及对象（`ai_write_tools_test.dart` 兜底）；禁止向用户显示 JSON 或 UUID。
- 必须：AI 能改的设置只登记在 `aiSettingSpecs`，经该设置自己的保存函数只改这一项；新增用户可见设置须评估登记。
- 必须：改动类工具一律可撤销（`ai_write_tools_test.dart` 往返兜底）；撤销前日记又被改过时先问再强制。
- 必须：删除类执行前在对话里确认；“允许 AI 改动数据”关掉时改动类工具不出现；有编辑页登记时改动类工具不执行。
- 必须：写日记只经 `aiWritableDiary`，批量有一条不合规整批不做；只动手动、非私密的日记本；待办写法同待办页（见 `todos.md`）。
- 必须：模板工具正文只经模板 Markdown 进出，禁止让模型写块文档 JSON；模板白名单扩充时在 `ai_template_markdown_test.dart` 覆盖往返。
- 禁止：给智能体彻底删除、清空回收站、备份 / 恢复 / 导入 / 导出 / 分享、网盘、同步配对、应用锁、私密设置、AI 自身设置、存储清理的工具，只给 `open_page`。
- 必须：使用指南只在 `assets/ai_guide/zh|en/<id>.md`，禁止写不存在的功能；用户可见功能改动须同步文章（`ai_guide_test.dart` 兜底）。
