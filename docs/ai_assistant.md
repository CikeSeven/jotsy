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
| `lib/core/services/ai/agent/` | 智能体循环 `AiAgentLoop`（只管顺序，经 `AiAgentHost` 落库与执行）、工具参数 schema 与集中校验、结果限长 |
| `lib/ui/ai/` | 偏好、提示词、检索、各流程与页面（设置、回顾、主页、对话） |
| `lib/ui/ai/tools/` | 智能体的工具接口 `AiTool`、唯一的工具清单 `ai_tool_registry.dart`、可前往的页面 `ai_destinations.dart`、各领域工具 |
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

**思考强度**（`AiThinkingLevel`，对话页“模型与思考”面板，每段对话各自记住）：`AiRequest.thinking` 为 null 时是“自动”，不发任何强度参数（与加入强度之前完全一样）；关 / 低 / 中 / 高的写法：

| 协议 | 低 / 中 / 高 | 关 |
|---|---|---|
| OpenAI 兼容 | `reasoning_effort: low / medium / high` | `reasoning_effort: none` |
| OpenAI Responses | `reasoning.effort`（与 `summary: auto` 同在），不发温度 | `reasoning.effort: none`，不发温度 |
| Anthropic | `thinking: adaptive` + `output_config.effort`（强度不能写进 `thinking`） | `thinking: {type: disabled}`（新模型不写时默认就会思考） |
| Gemini | `thinkingConfig.thinkingLevel`（与 `includeThoughts` 同在） | `thinkingConfig.thinkingBudget: 0`（两者不能同时写） |

`prepareRequest`：模型设置里关了“请求思考”时强度一律不发；“关”时不请求思考过程（以前 `request || model` 使模型开着思考时无法关掉）。首个块之前的 400 降级顺序为：去图片 → **去强度**（保留思考本身，记在 `_rejectsEffort`）→ 去思考 → 带工具则记为不支持工具。对话标题与检索计划这两个短小的辅助请求固定为“关”。思考时长由 `AiThinkingClock` 按墙钟计（首个思考增量到首个正文 / 工具增量），检索问答记在消息 meta 的 `thinkingMs`，智能体按步骤记在步骤里、最后一段记在 meta。

**工具调用**（AI 助手直接操作应用用）：`AiRequest.tools` 为 `AiToolSpec`（名称、说明、JSON Schema 参数，只用四家都认的子集 type / properties / required / enum / items / description / minimum / maximum）。一步工具调用在消息里是：助手消息（可选的 `AiReplayPart` + 正文 + 若干 `AiToolCallPart`）后接一条用户消息（与每个调用对应的 `AiToolResultPart`）。

| 协议 | 定义 | 调用 | 结果 | 需要原样带回的数据 |
|---|---|---|---|---|
| OpenAI 兼容 | `tools[].function` | `delta.tool_calls[]` 按 `index` 拼接 | 每个结果一条 `role: tool` | `reasoning_content` / `reasoning` 字段与 OpenRouter 的 `reasoning_details`，只放进带调用的助手消息 |
| OpenAI Responses | `tools[]`，`strict: false` | `function_call` 条目，参数增量 + `output_item.done` 快照 | `function_call_output` | 本步全部输出条目（开着思考时请求 `include: reasoning.encrypted_content`；没有加密内容的推理条目不带回） |
| Anthropic | `tools[].input_schema` | `tool_use` 块 + `input_json_delta` | 同一条用户消息里的 `tool_result`（`is_error`） | 带签名的 `thinking` / `redacted_thinking` 块，放在最前；没签名的丢掉 |
| Gemini | `functionDeclarations` | `functionCall` 部分（整块到达） | 同一条消息里的 `functionResponse`（结果不是 JSON 对象时包成 `{result}` / `{error}`） | 调用上的 `thoughtSignature`；只在服务端给过 id 时回带 id |

参数片段由共用的 `AiToolCallAssembler` 拼接，流结束后才整体解析：不是 JSON 对象的调用带着 `argumentsError` 返回（由调用方把错误回传模型，不执行）；服务商没给 id 或 id 重复时生成本地 id。完整的调用只在流的最后一块里给出，中途只有 `toolCallStarted` 供界面提示。**只有 `AiFinishReason.isComplete`（正常收尾：`stop` / `toolCalls`）时才能执行调用**：截断（`length`）、服务端标为未完成、或流中断没有结束原因时，参数可能是半截的。一轮之内模型固定，回放数据总是同一模型产生的。

模型设置里“支持工具调用”默认开启（只记关掉的）。首个块之前收到 400 时依次去掉图片、思考，仍被拒且带着工具时把该模型记为不支持工具并照常报错——`AiService` 不悄悄去掉工具重发，由调用方据 `supportsTools` 改用不带工具的问答。

## 4. 服务商与任务路由

`AiProviderConfig`：名称、预设 id、协议、根地址、密钥、代理（按服务商）、自定义请求头、额外请求体 JSON（合并进每个请求）、流式、`include_usage`、是否发送温度、首字超时、重试次数，以及勾选的模型（显示名、是否支持图片、是否请求思考过程、是否支持工具调用（这三项默认开，只记关掉的）、上下文长度、最大输出）。

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

- `ai_conversations`：conversationId、title、personaId、scope（JSON：自动 / 最近 N 天 / 全部 / 时间范围 / 固定一篇）、options（v21，`AiConversationOptions`：换用的模型与思考强度，`{}` 为跟随默认；新对话沿用最近活动的那段对话的选项）、pinned、createdAt、updatedAt；
- `ai_messages`：messageId、conversationId、role（user / assistant）、content（Markdown）、reasoning、citations（被引用日记的编号、业务 id、标题、日期）、meta（服务商、模型、token、放进上下文的篇数、出错原因、所用思考强度 `thinking` 与思考时长 `thinkingMs`；智能体另有 `agent: true` 与没有正常作答的原因 `agentEnd`）、status（done / stopped / error）、steps（v20，智能体的工具步骤，见 §9；普通回答为 `[]`）、createdAt；
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

智能体的一轮（§9）只在发问前确认一次：工具会按需连续读日记，所以“多篇时”按“首次”处理，“每次”为每轮问一次，面板另有一行说明 AI 会按需查找、读取日记（私密日记除外）。

智能检索计划、各块回顾摘要、最终回答 / 回顾和自动起标题都在各自请求前确认实际使用的主机与模型；主模型的确认不授权另一个服务商。取消检索或摘要阶段的确认即停止后续流程，取消起标题则保留问题开头作为标题。固定单篇对话每次发送时重新读取日记，未解封胶囊与回收站中的正文不会读入上下文。编辑页的图片描述与文字功能共用单篇私密权限判断，草稿也检查日记本继承的私密性。

回应“存为留言”会完整预填到现有留言面板，用户确认后才写库；超过 1000 字时保留全文并禁用保存，由用户缩短，取消不写入。

## 9. 智能体（对话与操作）

对话模块里“让 AI 使用工具”（`AiAgentOptions.enabled`，默认开）打开、且所用模型支持工具调用（`AiService.supportsTools`：模型设置没关、本次运行里没被服务端拒过）时，对话走智能体：模型按需调用工具查日记、统计、看日历与待办、打开页面；否则走 §7 的检索问答。模型第一步就回 400 并被记为不支持工具（还没有任何输出）时，删掉占位消息，同一个问题改走检索问答。

**一轮的顺序**（`ai_chat_agent.dart` → `AiAgentLoop` → `AiAgentTurn`）：

1. 发送前确认（§8，智能体口径）；固定了一篇日记时把它放进上下文（私密日记只在用户允许时），时间范围写成一句提示，其余由模型调工具去查；
2. 建好助手消息行（状态 stopped）：进程被杀也看得到已执行的步骤；
3. 循环：请求（系统提示词 + 稳定顺序的工具定义）→ 收齐正文、思考与完整的调用 → **只有正常收尾才执行**（§3）→ 同一步的调用按顺序串行执行 → 结果回传 → 下一步；最多 `maxSteps` 步（10 / 20 / 40，默认 20），最后一步 `toolChoice: none` 让模型据已有结果作答，服务商无视时以“步数用完”结束并在回答下提示可以说“继续”；
4. 每一步的输出收齐后写入 `steps`（调用记为 executing），每个调用出结果后再写；写库串行，结束时写正文、引用、用量与状态。

**执行一个调用**：找工具 → 参数是坏 JSON 时直接回传错误 → 经工具的 schema 集中校验与转换（必填、未知参数报错、字符串数字转数字、单值转数组、日期 `YYYY-MM-DD` 转 `DateTime`、时间 `HH:MM` 转分钟）→ 执行 → 结果经 `aiToolResultText` 限长（默认 16000 字符，超出时换成“已截断 + 开头预览 + 缩小范围再查”的提示）。失败一律作为 `isError` 结果回传模型（让它改正或换个做法）；只有停止会中断循环。工具执行不自动重试。

**停止与中断**：停止时取消请求与正在执行的工具，已收到的正文与已完成的步骤保留，未完成的调用记为已停止；离开页面等同停止。落库的 executing 在不进行中的消息里按“已中断”显示，**绝不重放**。

**历史**：以前各轮只回传问题与最终回答（去掉旧编号、截到 1500 字），回答后面附一行本地生成的“这一轮做过的操作”（只列改动与跳转的工具名与参数，查询不列）；不回放旧轮的工具消息与签名，换模型、换协议都不出错。现在几点、对话范围放在最后一条用户消息开头，系统提示词与工具定义保持不变，利于提示缓存。

**引用**：一轮之内同一篇日记不论被哪个工具返回都用同一个 `[Dn]`（`AiCitationBook`）；回答与步骤说明里用到的才记进 citations。

**工具**（`lib/ui/ai/tools/`，清单只在 `ai_tool_registry.dart`）：

| 工具 | 作用 | 数据来源 |
|---|---|---|
| `get_app_context` | 今天（含农历、节气、法定节假日）、平台、界面语言、开启的功能、心情选项、本轮剩余字数 | `CalendarLunarDay`、`AppPlatform`、`AppFeatures`、`SettingsService.moodOptions` |
| `search_diaries` | 按关键词（任一命中）/ 日期（含两端）/ 标签（全部命中）/ 心情 / 日记本找日记，返回编号、id、日期、标题与摘录 | `getAiContextDiaries`、`aiRankDiaries` |
| `read_diaries` | 按 id 读全文（一次最多 10 篇） | `getAiDiary`；私密日记、排除的本子与标签一律不给 |
| `diary_stats` | 篇数、字数、记录天数、最长 / 当前连续天数、常用心情与标签，可按日 / 周 / 月 / 年分组 | `getAiContextDiaries`、`AiRecapStats`、`ExploreStatsBuilder` |
| `get_calendar_day` | 某天的农历、节假日、这天的心情、写的日记（只给标题）、到期待办、纪念日 | 日记、待办、纪念日、这天的心情各自的查询 |
| `list_todos` | 未完成 / 已完成 / 全部，可按到期日或关键词（待办功能开启时） | 待办查询 |
| `list_anniversaries` | 纪念日与下一次日期、还有几天（纪念日功能开启时） | `AnniversaryCountdown` |
| `list_tags` | 标签与使用篇数（排除的标签不列） | `watchAllTags`、`watchTagUsageCounts` |
| `list_notebooks` | 日记本树（私密 / 上锁本与排除的本子不列） | `notebookTreeProvider` |
| `open_page` | 给用户一个“前往”按钮；用户明确说“打开”时（`now`）本轮结束后自动打开 | `AiDestination` |

**改动类工具**（“允许 AI 改动数据”默认开，关掉后只有查询与前往；“每次改动前确认”默认关）：

| 工具 | 作用 | 写库 | 撤销 |
|---|---|---|---|
| `create_diary` | 新建日记（Markdown 正文、日期与时刻、标签（没有的就建）、心情（只能取心情选项）、天气、地点、手动日记本） | `publishNewDiaryDirectly` | 摘掉顺带新建的标签、移入回收站、删掉没人用的新标签 |
| `append_to_diary` | 在日记末尾追加 Markdown | `updateDiaryContent` | 写回原正文 |
| `update_diary` | 改标题、日期、时刻、心情、天气、地点（空字符串清空） | `patchDiaryFields`（不碰归档、删除、标签与正文） | 写回原值 |
| `tag_diaries` | 批量加减标签 | `applyDiaryTagBatch` | `restoreDiaryTagBatch` |
| `pin_diaries` / `archive_diaries` | 置顶 / 归档（或取消） | batch writes | 按每篇原来的状态写回 |
| `trash_diaries` | 移入回收站（**确认**） | `softDeleteDiaries` | `restoreDiaries` |
| `add_comment` | 留言（留言功能开启时） | `addDiaryComment` | 删掉这条 |
| `create_tag` / `rename_tag` | 新建、改名或改色 | `ensureTagsByName` / `updateTag` | 删掉没人用的新标签 / 改回 |
| `merge_tags` / `delete_tag` | 合并 / 删除标签（**确认**，覆盖私密与回收站里的日记） | `mergeTags` / `deleteTagWithSnapshot` + `forgetDeletedTags` | 按快照原样放回（期间建了同名标签时报冲突） |
| `create_notebook` / `rename_notebook` | 新建手动本（可选上级）/ 改名 | `createNotebook` / `updateNotebook` | 删掉（已收了日记时先报冲突）/ 改回 |
| `add_to_notebook` / `remove_from_notebook` | 收录 / 移出（只动手动、非私密的本子） | 日记本成员 ops | 移出新收的 / 放回原成员行 |
| `create_todo` / `update_todos` / `complete_todos` / `delete_todos`（**确认**） | 待办（清单按名称，带提醒时按待办页口径申请通知权限） | 待办 ops | 删掉 / `restoreTodoFields` 与改回标题备注 / `undoTodoCompletion` / `restoreTodos` |
| `create_anniversary` / `delete_anniversary`（**确认**） | 纪念日（不重复 / 每年 / 农历每年） | `AnniversaryEditController.save` / `deleteAnniversary` | 删掉 / `restoreAnniversary` |
| `set_day_mood` | 这天的心情（或清空） | `setDayMood` / `clearDayMood` | 恢复原来的心情或清空 |
| `set_theme` / `set_app_language` / `set_font_scale` / `set_feature_enabled` | 明暗与主题色 / 界面语言 / 字体大小 / 功能开关（不含 AI 本身；有私密本时不关日记本） | `SettingsService` / `saveAppFeatures` | 写回原值 |

共同约束：写日记只经 `aiWritableDiary`（私密、回收站、未解封胶囊、AI 隐私排除的一律不写，批量里有一篇不能写就整批不做）；`EditingSessionRegistry` 有编辑页时不写（编辑页整份保存会盖掉改动），执行期间登记为编辑会话；写后一次性 provider 手动失效。

**确认与撤销**：删除类（以及打开“每次改动前确认”时的写操作）执行前，步骤行下展开确认卡（工具的 `preview` 列出要删 / 要改的内容），用户点“删除 / 执行”才继续，点“取消”回传“用户拒绝了，不要换别的方式达成同样效果”；等待期间可停止。成功的改动在保存后的回答里有“撤销”，可撤销的有两个以上时另有“撤销本轮全部改动”（`undoAiAgentCalls`，从后往前撤）。改日记的撤销前按内容指纹（`aiDiaryFingerprint`：标题、正文、元数据、发表与更新时间的 FNV-1a，库里的时间只到秒）核对之后有没有被改过，改过就问用户要不要覆盖。撤过的在步骤记录里标为已撤销。

**只给前往、不提供工具的**：彻底删除与清空回收站、备份 / 恢复 / 导入 / 导出 / 分享、网盘、局域网同步配对、应用锁与密码、私密与上锁日记本的设置、AI 服务商与密钥、存储清理，以及关闭 AI 助手本身。

工具的名称、说明与参数 schema 是接口定义，用英文写在工具类里（不进 ARB，说明只写作用、参数含义与必要限制）；卡片标题与结果说明走 l10n。schema 只用四家都认的子集（type / properties / required / enum / items / description / minimum / maximum）。工具不持有 BuildContext：要打开页面时返回 `AiToolNavigation`，由对话页显示前往卡片、经 `AiDestination` 的统一入口打开（日记经 `openDiaryLinkTarget`、日记本经 `openNotebookFromAnywhere`、各 Tab 经 `homeTabRequestProvider`）。`AiDestination` 写明类别、位置（首页 / 设置）、图标与色调；会关掉对话页的目标（首页各 Tab 与日记本，`leavesChat`）打开前登记 `aiChatReturnProvider`，首页与日记页的返回键、以及落地后的提示条据此重新打开那段对话（打开后对话页仍在栈里就撤销登记）。`open_page` 打开具体的一篇 / 一本 / 一项前核对存在且 AI 可以碰（私密与 AI 隐私排除的按找不到），名称只给界面。

**涉及对象与可读详情**：工具执行时顺手记下涉及的对象（`AiToolOutcome.subjects`：日记、日记本、标签、待办、纪念日、某一天；参数指向的标 `input`），存进调用记录（单个调用最多 12 个，其余计数），改动类工具成功时必须给。界面据此写出具体标题（`AiTool.labelWith`）、列出可点的对象胶囊；详情经 `aiToolFacts` 把原始参数写成“标签 — 值”（日期范围合并、枚举译名、id 换成对象名，绝不显示 UUID），个别参数由工具的 `describeArg` 给读法。回答的分段只经 `buildAiAnswerSegments`：思考、过渡句、只读与失败的调用折进“思考过程”，前往、改动、确认卡片与正文露在外面。

**隐私**：多篇只经 `getAiContextDiaries`；`read_diaries` 比单篇功能更严，私密日记即使打开了“允许对私密日记使用 AI”也不给；日期、心情、标签、天气、地点按“发送”开关给；摘录与正文从本轮“最多发送”预算里扣，用完只给标题与日期。

**接入新功能**：在对应领域的 `ai_tools_<领域>.dart` 写一个 `AiTool`（功能开关经 `isAvailable`），加进清单；改动数据的工具同时实现 `undo`（删除类再实现 `preview`），并加进 `test/ui/ai/ai_write_tools_test.dart` 的清单补“执行再撤销”的测试；需要页面时在 `aiDestinations` 加一项；补“功能关闭时工具不出现”与主流程测试（`test/ui/ai/ai_tools_test.dart` 会检查名称、schema 与标题）。

## 10. 使用指南

借鉴 Skill 的做法：**目录常驻、正文按需读取**。文章在 `assets/ai_guide/zh/<id>.md` 与 `assets/ai_guide/en/<id>.md`（pubspec 登记这两个目录，加载经资源清单枚举，新文章随构建出现），中英两份 id 一致；日文、俄文界面读英文版、按界面语言回答（与 `aiPrompt*` 同口径：取提示词语言 `kit.l10n.localeName`）。

- 头信息：`id`（与文件名相同）、`title`、`summary`（目录里的一行）、`features`（相关的 `AppFeatures` 字段名）、`platforms`（只在部分平台有的整篇功能，空为全平台）、`destinations`（相关的 `AiDestination` id，不含需要具体 id 的 diary / notebook / todo）、`keywords`；列表写成 `[a, b]`。正文只用 `##` 小标题、段落、列表与粗体，写入口路径（“设置 → 数据管理 → 网盘备份”）、步骤与注意事项，界面文字以 ARB 为准。
- 智能体每轮把目录（每篇一行“id: 标题 — 摘要”）接在系统提示词里（`aiPromptAgentGuide`，属于稳定前缀），模型回答“怎么用 / 在哪里 / 能不能”前先调 `read_guide` 读正文（一次最多 3 篇，每篇一次最多 8000 字，长文用 `offset` 接着读）；结果按当前功能开关与平台注明“这个功能现在关着 / 本设备没有”，并列出现在能打开的相关页面，模型据此给“前往”按钮。
- 一致性测试 `test/ui/ai/ai_guide_test.dart`：中英 id 一致且与文件名相同、头信息合法、引用的页面都在登记表里、每个功能开关与设置首页能进的每个页面至少被一篇文章覆盖、目录长度有上限。

## 11. 开发与验证

- 单元与 widget 测试用 `test/support/fake_ai.dart` 的 `FakeAiChatClient` / `fakeAiService` 替换 `aiServiceProvider`，不联网；智能体用按队列回放的 `scriptedAiService` 与 `textTurn` / `toolTurn` 编排每一步（`test/ui/ai/ai_agent_chat_test.dart`、`test/core/services/ai/ai_agent_loop_test.dart`）；协议客户端的测试在本地 `HttpServer.bind(loopback, 0)` 上回放准备好的流（`test/core/services/ai/`，工具调用见 `ai_tool_calls_test.dart`）。
- 手动验证用 `dart run tool/ai_mock_server.dart`：在本机起一个同时实现四种协议的服务（默认端口 8787），流式回显请求、可注入错误与思考过程，见脚本开头的说明。在 Jotsy 里添加“自定义（OpenAI 兼容）”服务，地址填 `http://127.0.0.1:8787/v1`（OpenAI Responses 同一地址；Anthropic 格式填 `http://127.0.0.1:8787`，Gemini 格式填 `http://127.0.0.1:8787/v1beta`），密钥随便填。请求带着工具时，在问题里写 `/tool 工具名 {"参数": 1}` 让它按该协议调用这个工具（参数分两段流式发出），收到工具结果后它回答结果内容。
