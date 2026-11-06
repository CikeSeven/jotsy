# AI 助手

用户用自己的 AI 服务接口（OpenAI 兼容 Chat、OpenAI Responses、Anthropic Claude、Google Gemini，以及本地的 Ollama / LM Studio 等），在 Jotsy 里获得写作助手、读后回应、写作灵感、回顾与“和日记对话”。功能管理里**默认关闭**；开启后还要配好至少一个服务商与模型，各处入口才会出现。界面规格见 DESIGN.md §5.29，协作规则见 AGENTS.md §6“AI 助手”。

## 1. 原则

- **只在用户操作时联网**：每个请求都由一次点按触发。唯一的自动行为“发表后自动回应”默认关闭，开启后也只发给已经确认过的服务（自动流程弹不了确认面板）。
- **私密内容不外流**：多篇上下文只经 `getAiContextDiaries`，它在范围过滤之外**总是**再排除私密日记（私密本自己的范围会把成员放进来），并排除回收站与未解封的时间胶囊；单篇功能（写作、回应、智能填写、图片描述）对私密日记默认不出现入口，用户在 AI 隐私里打开“允许对私密日记使用 AI”后才可以。
- **密钥只在本机**：服务商配置（含密钥）与用量只存于 `AiProviderStore`，不进备份、不同步。
- **生成的内容是用户的数据**：回应、回顾与对话存在 Drift 表里，随完整备份导出 / 恢复 / 合并；不参与局域网同步（与草稿箱同一口径）。

## 2. 代码结构

| 位置 | 职责 |
|---|---|
| `lib/core/services/ai/` | 纯 Dart 引擎：消息模型 `ai_models.dart`、错误分类 `ai_failure.dart`、HTTP 与取消 `ai_http.dart`（`HttpCancelToken`）、SSE 解码 `ai_sse.dart`、四种协议客户端 `ai_client_*.dart`、服务商与任务路由 `ai_provider_config.dart`、预设 `ai_provider_presets.dart`、存储 `ai_provider_store.dart`、用量 `ai_usage_ledger.dart`、图片 `ai_vision.dart`、编排 `ai_service.dart` |
| `lib/core/database/app_database_ai_*.dart` | 三张表（schema v17）、增删查与撤销、上下文查询 |
| `lib/ui/ai/` | 偏好、提示词、检索、各流程与页面（设置、回顾、主页、对话） |
| `lib/ui/diaries/widgets/diary_ai/` 与 `controllers/diary_ai_editing.dart` | 编辑页的写作面板、灵感条与写回编辑器 |
| `tool/ai_mock_server.dart` | 本地模拟四种协议的流式接口，手动验证用 |

## 3. 协议

所有请求都由 `AiChatClient` 发出，界面与流程只认 `AiRequest` → `Stream<AiChunk>`（正文增量、思考增量、用量、结束原因）。四种协议都支持关闭流式（一次性请求再按同样的块吐出）与拉取模型列表。

| 协议 | 路径 | 鉴权 | 要点 |
|---|---|---|---|
| OpenAI 兼容 | `{base}/chat/completions`、`{base}/models` | `Authorization: Bearer`（密钥为空不发） | 图片为 `image_url` data URL；思考过程读 `delta.reasoning_content` / `delta.reasoning` 与正文开头的 `<think>`；`stream_options.include_usage` 可关；`max_tokens` 只在模型配置写明时发送 |
| OpenAI Responses | `{base}/responses`、`{base}/models` | `Authorization: Bearer` | OpenAI 现行的主接口（OpenAI 预设用它）。系统提示词放 `instructions`、对话放 `input`（带图片时为 `input_text` / `input_image`），`store: false` 不在服务端留存；思考为 `reasoning: {summary: auto}`，读 `response.reasoning_summary_text.delta`；正文读 `response.output_text.delta`，用量与结束原因读 `response.completed` / `response.incomplete`，出错读 `response.failed` / `error`；开着思考时不发温度 |
| Anthropic | `{base}/v1/messages`、`{base}/v1/models` | `x-api-key` + `anthropic-version: 2023-06-01` | `max_tokens` 必填（默认 8192）；较新模型拒绝 `temperature`，预设默认不发，开着思考时一律不发；模型打开“思考过程”时发 `thinking: {type: adaptive, display: summarized}` |
| Gemini | `{base}/models/{m}:streamGenerateContent?alt=sse` | `x-goog-api-key` | `systemInstruction`；图片为 `inline_data`；思考为 `thinkingConfig.includeThoughts`，返回的部分带 `thought: true` |

SSE 解码处理跨块的 UTF-8、CRLF、多行 `data:`、`event:`、注释行与 `[DONE]`。错误按状态码与各家的错误体分类为 `AiFailureKind`（未配置、网络、超时、密钥无效、无权限、模型不存在、请求错误、限流、额度、上下文太长、内容被拦、服务错误、返回格式不对、已取消），界面经 `aiErrorMessage` 给出友好说明，原始信息可在“详情”里看。

**超时与重试**：连接 15 秒，首个字节默认 90 秒（推理模型慢，可在服务商高级设置里改），两块数据之间空闲 60 秒。只在收到第一个块**之前**按服务商的重试次数（默认 1）重试网络错误、5xx 与 429；开始输出后不重试，免得重复的文字。

**图片与思考默认都发，被拒时自动降级**：现在的主流模型几乎都能看图、会思考，所以模型设置里“支持图片输入”“请求思考过程”默认开启。首个块之前收到 400 时，`AiService` 先去掉图片再试；仍被拒、且请求里带了思考参数（Claude、Gemini、OpenAI Responses 才会带；OpenAI Chat 兼容接口只读返回里的思考字段，请求不变）时再去掉思考试一次。被拒过的模型记在本次运行的内存里，之后的请求直接不带。

## 4. 服务商与任务路由

`AiProviderConfig`：名称、预设 id、协议、根地址、密钥、代理（按服务商）、自定义请求头、额外请求体 JSON（合并进每个请求）、流式、`include_usage`、是否发送温度、首字超时、重试次数，以及勾选的模型（显示名、是否支持图片、是否请求思考过程（这两项默认开，只记关掉的）、上下文长度、最大输出）。

预设（`ai_provider_presets.dart`，新增服务商只在这里加一项）只给地址、协议与几个兼容开关，**不带模型**——模型更新太快，写死的推荐很快就过时；新建后在编辑页“获取模型列表”勾选，或手动添加模型名：

- 国内：DeepSeek、阿里云百炼（通义）、Moonshot（Kimi）、智谱、火山方舟（豆包）、硅基流动、腾讯混元、MiniMax
- 国际：OpenAI（Responses 接口）、Anthropic、Google Gemini、OpenRouter、Groq、xAI、Mistral
- 本地：Ollama（`http://localhost:11434/v1`）、LM Studio（`http://localhost:1234/v1`）
- 自定义：OpenAI 兼容 / OpenAI Responses / Anthropic 格式 / Gemini 格式

任务（`AiTaskKind`）：writing、suggest、reply、prompts、recap、chat、vision、utility。每个任务可以单独指定模型；没指定时，suggest / utility 这类“快速”任务先用“快速模型”，其余用“默认模型”，都没设时用第一个可用的模型。

## 5. 存储

| 内容 | 位置 | 备份 | 同步 |
|---|---|---|---|
| 服务商、密钥、任务路由、已确认的主机 | SharedPreferences `app.ai.providers`（`AiProviderStore`，写入串行化） | 否 | 否 |
| 用量（按月 × 服务商 × 模型的请求数与 token，保留 24 个月） | `app.ai.usage` | 否 | 否 |
| 偏好（模块开关、人设、写作指令、关于我、输出、隐私、图片、回应、灵感、回顾、对话） | `app.settings.ai_prefs`（`AiPreferences`，稀疏写入、逐字段容错，与默认相同时删除键） | 是（`aiPrefsRaw`） | 随“同步设置” |
| 功能开关 | `AppFeatures.ai` | 是 | 界面类开关，随“同步设置” |
| 对话、消息、回应与回顾 | Drift `ai_conversations` / `ai_messages` / `ai_results` | 完整备份（日记包不带） | 否 |

偏好里用户自建的人设与自定义写作指令各最多 50 个；用户自己写的提示词文字（人设提示词、写作指令提示词与内置指令的改写、关于我、文风偏好）共用上限 `kAiPromptTextMaxLength`（10 万字），输入框按它限字，读取时超出部分截掉。

三张表都存业务 id、不建外键：

- `ai_conversations`：conversationId、title、personaId、scope（JSON：自动 / 最近 N 天 / 全部 / 时间范围 / 固定一篇）、pinned、createdAt、updatedAt；
- `ai_messages`：messageId、conversationId、role（user / assistant）、content（Markdown）、reasoning、citations（被引用日记的编号、业务 id、标题、日期）、meta（服务商、模型、token、放进上下文的篇数、出错原因）、status（done / stopped / error）、createdAt；
- `ai_results`：resultId、kind（reply / recap）、diaryId（回应）、periodStart / periodEnd、scope（回顾的预设与日记本快照）、title、content、personaId、meta（人设快照、模型、统计、引用、思考过程、token）、createdAt。

彻底删除日记时在同一事务里删掉它的回应。备份合并按业务 id：本机没有的新增，“合并”保留本机，“合并并覆盖”替换；引用的日记已不存在的回应丢弃。

## 6. 提示词

提示词文本全部在 ARB 里（`aiPrompt*`），由 `AiPromptKit` 按“回答语言”选中文或英文：跟随日记（按要处理的文字判断）、跟随界面（日文、俄文等非中文界面用英文提示词，再加一句“请用界面语言回答”，语言名经 `aiPromptAppLanguageName`），或指定语言（语言名是中文写的就用中文提示词，再加一句“请用某某语言回答”）。日文、俄文 ARB 里的 `aiPrompt*` 只为键集合一致而翻译，不会发给模型；内置写作指令与内置人设的提示词（`aiAction*Prompt`、人设提示词）则按界面语言取、原样发送，日文、俄文界面发的就是日文、俄文版本。内置“翻译”在界面语言与英文之间互译（中文、英文界面为中↔英）。系统提示词 = 基础身份 + 任务说明 + 人设 + 关于我 + 文风（写作类）+ 回答长度 + 回答语言。日记按隐私设置附带日期、心情、标签、天气、地点（地点默认不发）。正文整篇发送，不设每篇上限；唯一的上限是 AI 隐私里的“最多发送”（`AiPrivacyOptions.contextBudget`，1 万 – 100 万字，默认 10 万字，`TextStats` 口径），对话、回顾的每一块与单篇功能（写作、智能填写、回应、写作灵感）都按它：超过时放不下的那篇截到剩余字数并注明“后文省略”，之后的不再放。旧版的档位（最高 96000）读取时换成最接近的新档位，旧版的“每篇最多”读取时忽略。

温度以“创造力”（精确 / 平衡 / 有创意）为基准按任务微调并夹在 0–1：智能填写与内部任务 0.2，图片 0.3，回顾略低，回应与灵感略高。服务商关掉“发送温度”时不发。

## 7. 各模块

- **写作助手**：工具栏、`/` 菜单、选区菜单 / 桌面右键菜单与图片菜单进入。面板是编辑页自己的浮层（与录音面板同位），会话由编辑页持有，键盘收起、工具栏卸载时生成不中断。作用范围为选中文字、当前段落、全文，续写为光标前的内容。15 个内置指令（续写、润色、扩写、精简、纠错、五种语气、翻译、总结、列成要点、提取待办、改成诗）可排序、隐藏、改提示词；自定义指令的提示词可用变量 `{{文字}}` `{{全文}}` `{{标题}}` `{{日期}}` `{{心情}}`（英文别名 `{{text}}` `{{diary}}` `{{title}}` `{{date}}` `{{mood}}` 同样认，认不出的原样保留），输出方式为替换 / 插在下方 / 只复制。写回只经 `diary_ai_editing.dart`：AI 输出的 Markdown 经 `diaryMarkdownPasteNodes` 转成块，一次事务替换或插入，一步撤销；代码块与表格格子里只写原文；生成期间目标被改动时退回到末尾插入。
- **智能填写**：一次请求拿到标题、标签与心情（JSON 输出，`aiExtractJsonObject` 稳健提取），优先用快速模型。标签按名称匹配已有的，新标签经就地新建流程；心情只能从用户自己的心情选项里选。
- **图片理解**（默认开）：开启且模型没被标为不支持图片时，回应与“AI 描述图片”附带正文里的图片（模型实际不认图片时按上文自动只发文字）：原图够小原样发送，否则按长边（默认 1024）缩小为 PNG，最多 N 张（默认 3，可在 1–20 之间调）。
- **读后回应**：预览页“更多”与回应区；进行中的任务在常驻的 `aiReplyJobsProvider` 里（离开预览页再回来进度还在），完成即保存。“继续聊聊”以那篇日记为固定范围、那条回应开头开一段对话。
- **写作灵感**：新建空白日记时标题下的灵感条，点了才生成 3–5 个问题（日期、中文另加农历与节气、可选天气，以及可选的最近 3 篇非私密日记的摘录）。
- **回顾**：范围（本周 / 上周 / 本月 / 上月 / 今年 / 自定义）、日记本（可见的手动本与智能本，含子孙本子）、章节与口吻。先在本地算篇数、字数、心情分布与常用标签，发给模型的统计遵守“发送心情 / 标签”开关，本地展示保留完整统计。放得进字数预算时一次写完，否则按时间顺序切块、先用快速模型逐块总结，再汇总；每篇整篇放入（比一块还长的那篇截到一块的大小），只有 16 块也装不下时才按实际装箱结果压低每篇字数，严格限制最多 16 块且每块不超预算。极端情况下连每篇 1 字都装不下时按时间均匀取样，保留时段首尾。日记按时间全局编号 `[Dn]`，分块摘要里保留编号，最终回顾里的引用可点按打开原文。完成即保存，可另存为日记（写一份草稿后打开新建编辑页）。
- **与日记对话**：检索方式为智能（快速模型把问题转成关键词与可能的日期范围的 JSON 计划，失败退回本地关键词）、关键词（本地抽取：中文去掉虚词后取 2–4 字整段与 2-gram，英文去停用词；查不到时退回最近 N 天）或最近 N 天；对话也可以固定一个范围。候选按关键词命中（标题与标签加权）与时间远近排序，取前 N 篇（“最多引用”）放进字数预算，再按时间编号。历史问答带最近 12 条，去掉旧编号；出错的回答不进历史，相邻同一角色的消息合并，开头是助手时补一句“请回应这篇日记”（各家协议对消息顺序的要求不同）。第一轮后先用问题开头作标题，开了“自动起标题”再请快速模型起一个。离开页面时正在生成的回答按“已停止”保存。

## 8. 发送前确认

`confirmAiSend` 按 AI 隐私里的“发送前确认”决定：首次（第一次发往某个主机时问，可勾“不再询问”）、多篇时（默认：首次之外，多篇上下文每次都问）、每次。面板写明主机、模型、篇数与字数、图片张数。

智能检索计划、各块回顾摘要、最终回答 / 回顾和自动起标题都在各自请求前确认实际使用的主机与模型；主模型的确认不授权另一个服务商。取消检索或摘要阶段的确认即停止后续流程，取消起标题则保留问题开头作为标题。固定单篇对话每次发送时重新读取日记，未解封胶囊与回收站中的正文不会读入上下文。编辑页的图片描述与文字功能共用单篇私密权限判断，草稿也检查日记本继承的私密性。

回应“存为留言”会完整预填到现有留言面板，用户确认后才写库；超过 1000 字时保留全文并禁用保存，由用户缩短，取消不写入。

## 9. 开发与验证

- 单元与 widget 测试用 `test/support/fake_ai.dart` 的 `FakeAiChatClient` / `fakeAiService` 替换 `aiServiceProvider`，不联网；协议客户端的测试在本地 `HttpServer.bind(loopback, 0)` 上回放准备好的流（`test/core/services/ai/`）。
- 手动验证用 `dart run tool/ai_mock_server.dart`：在本机起一个同时实现四种协议的服务（默认端口 8787），流式回显请求、可注入错误与思考过程，见脚本开头的说明。在 Jotsy 里添加“自定义（OpenAI 兼容）”服务，地址填 `http://127.0.0.1:8787/v1`（OpenAI Responses 同一地址；Anthropic 格式填 `http://127.0.0.1:8787`，Gemini 格式填 `http://127.0.0.1:8787/v1beta`），密钥随便填。
