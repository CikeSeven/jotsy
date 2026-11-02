import 'package:meta/meta.dart';

import 'ai_models.dart';
import 'ai_provider_config.dart';

/// 预设在挑选面板里的分组。
enum AiPresetGroup { china, international, local, custom }

/// 一个服务商预设：只提供地址、协议与几个兼容开关，用户照样可以改任何一项。
///
/// 预设**不带模型**：模型更新太快，写死的推荐很快就过时，新建后由用户在
/// 编辑页“获取模型列表”勾选（也可以手动添加）。新增服务商只在
/// [aiProviderPresets] 里加一项（名称经 `ai_labels.dart` 本地化）。
@immutable
class AiProviderPreset {
  const AiProviderPreset({
    required this.id,
    required this.brand,
    required this.protocol,
    required this.baseUrl,
    required this.group,
    this.keyUrl,
    this.includeUsage = true,
    this.sendTemperature = true,
    this.needsKey = true,
  });

  final String id;

  /// 品牌名（英文 / 通用名）；界面上中英文不同的名称由 `ai_labels.dart` 给出。
  final String brand;
  final AiProtocol protocol;
  final String baseUrl;
  final AiPresetGroup group;

  /// “获取 API 密钥”打开的页面。
  final String? keyUrl;

  /// OpenAI 兼容：是否请求流式用量（不认识该字段的服务会报 400）。
  final bool includeUsage;

  /// 是否发送温度（较新的 Claude 与 OpenAI 推理模型会拒绝）。
  final bool sendTemperature;

  /// 本地服务不需要密钥。
  final bool needsKey;

  /// 以本预设新建一个服务商配置。
  AiProviderConfig create({required String id, required String name}) {
    return AiProviderConfig(
      id: id,
      name: name,
      presetId: this.id,
      protocol: protocol,
      baseUrl: baseUrl,
      includeUsage: includeUsage,
      sendTemperature: sendTemperature,
    );
  }
}

/// 预设 id 常量（标签、图标与测试按 id 引用）。
abstract final class AiPresetIds {
  static const String deepseek = 'deepseek';
  static const String dashscope = 'dashscope';
  static const String moonshot = 'moonshot';
  static const String zhipu = 'zhipu';
  static const String volcengine = 'volcengine';
  static const String siliconflow = 'siliconflow';
  static const String hunyuan = 'hunyuan';
  static const String minimax = 'minimax';
  static const String openai = 'openai';
  static const String anthropic = 'anthropic';
  static const String gemini = 'gemini';
  static const String openrouter = 'openrouter';
  static const String groq = 'groq';
  static const String xai = 'xai';
  static const String mistral = 'mistral';
  static const String ollama = 'ollama';
  static const String lmstudio = 'lmstudio';
  static const String customOpenAi = 'custom_openai';
  static const String customOpenAiResponses = 'custom_openai_responses';
  static const String customAnthropic = 'custom_anthropic';
  static const String customGemini = 'custom_gemini';
}

const List<AiProviderPreset> aiProviderPresets = <AiProviderPreset>[
  AiProviderPreset(
    id: AiPresetIds.deepseek,
    brand: 'DeepSeek',
    protocol: AiProtocol.openAi,
    baseUrl: 'https://api.deepseek.com/v1',
    group: AiPresetGroup.china,
    keyUrl: 'https://platform.deepseek.com/api_keys',
  ),
  AiProviderPreset(
    id: AiPresetIds.dashscope,
    brand: 'Qwen',
    protocol: AiProtocol.openAi,
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    group: AiPresetGroup.china,
    keyUrl: 'https://bailian.console.aliyun.com/',
  ),
  AiProviderPreset(
    id: AiPresetIds.moonshot,
    brand: 'Kimi',
    protocol: AiProtocol.openAi,
    baseUrl: 'https://api.moonshot.cn/v1',
    group: AiPresetGroup.china,
    keyUrl: 'https://platform.moonshot.cn/console/api-keys',
    includeUsage: false,
  ),
  AiProviderPreset(
    id: AiPresetIds.zhipu,
    brand: 'GLM',
    protocol: AiProtocol.openAi,
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    group: AiPresetGroup.china,
    keyUrl: 'https://open.bigmodel.cn/usercenter/apikeys',
    includeUsage: false,
  ),
  AiProviderPreset(
    id: AiPresetIds.volcengine,
    brand: 'Doubao',
    protocol: AiProtocol.openAi,
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    group: AiPresetGroup.china,
    keyUrl: 'https://console.volcengine.com/ark',
  ),
  AiProviderPreset(
    id: AiPresetIds.siliconflow,
    brand: 'SiliconFlow',
    protocol: AiProtocol.openAi,
    baseUrl: 'https://api.siliconflow.cn/v1',
    group: AiPresetGroup.china,
    keyUrl: 'https://cloud.siliconflow.cn/account/ak',
  ),
  AiProviderPreset(
    id: AiPresetIds.hunyuan,
    brand: 'Hunyuan',
    protocol: AiProtocol.openAi,
    baseUrl: 'https://api.hunyuan.cloud.tencent.com/v1',
    group: AiPresetGroup.china,
    keyUrl: 'https://console.cloud.tencent.com/hunyuan/api-key',
    includeUsage: false,
  ),
  AiProviderPreset(
    id: AiPresetIds.minimax,
    brand: 'MiniMax',
    protocol: AiProtocol.openAi,
    baseUrl: 'https://api.minimaxi.com/v1',
    group: AiPresetGroup.china,
    keyUrl: 'https://platform.minimaxi.com/',
    includeUsage: false,
  ),
  AiProviderPreset(
    id: AiPresetIds.openai,
    brand: 'OpenAI',
    protocol: AiProtocol.openAiResponses,
    baseUrl: 'https://api.openai.com/v1',
    group: AiPresetGroup.international,
    keyUrl: 'https://platform.openai.com/api-keys',
    sendTemperature: false,
  ),
  AiProviderPreset(
    id: AiPresetIds.anthropic,
    brand: 'Claude',
    protocol: AiProtocol.anthropic,
    baseUrl: 'https://api.anthropic.com',
    group: AiPresetGroup.international,
    keyUrl: 'https://console.anthropic.com/settings/keys',
    sendTemperature: false,
  ),
  AiProviderPreset(
    id: AiPresetIds.gemini,
    brand: 'Gemini',
    protocol: AiProtocol.gemini,
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    group: AiPresetGroup.international,
    keyUrl: 'https://aistudio.google.com/apikey',
  ),
  AiProviderPreset(
    id: AiPresetIds.openrouter,
    brand: 'OpenRouter',
    protocol: AiProtocol.openAi,
    baseUrl: 'https://openrouter.ai/api/v1',
    group: AiPresetGroup.international,
    keyUrl: 'https://openrouter.ai/keys',
  ),
  AiProviderPreset(
    id: AiPresetIds.groq,
    brand: 'Groq',
    protocol: AiProtocol.openAi,
    baseUrl: 'https://api.groq.com/openai/v1',
    group: AiPresetGroup.international,
    keyUrl: 'https://console.groq.com/keys',
    includeUsage: false,
  ),
  AiProviderPreset(
    id: AiPresetIds.xai,
    brand: 'xAI Grok',
    protocol: AiProtocol.openAi,
    baseUrl: 'https://api.x.ai/v1',
    group: AiPresetGroup.international,
    keyUrl: 'https://console.x.ai/',
  ),
  AiProviderPreset(
    id: AiPresetIds.mistral,
    brand: 'Mistral',
    protocol: AiProtocol.openAi,
    baseUrl: 'https://api.mistral.ai/v1',
    group: AiPresetGroup.international,
    keyUrl: 'https://console.mistral.ai/api-keys',
    includeUsage: false,
  ),
  AiProviderPreset(
    id: AiPresetIds.ollama,
    brand: 'Ollama',
    protocol: AiProtocol.openAi,
    baseUrl: 'http://localhost:11434/v1',
    group: AiPresetGroup.local,
    needsKey: false,
  ),
  AiProviderPreset(
    id: AiPresetIds.lmstudio,
    brand: 'LM Studio',
    protocol: AiProtocol.openAi,
    baseUrl: 'http://localhost:1234/v1',
    group: AiPresetGroup.local,
    needsKey: false,
    includeUsage: false,
  ),
  AiProviderPreset(
    id: AiPresetIds.customOpenAi,
    brand: 'OpenAI API',
    protocol: AiProtocol.openAi,
    baseUrl: '',
    group: AiPresetGroup.custom,
    includeUsage: false,
  ),
  AiProviderPreset(
    id: AiPresetIds.customOpenAiResponses,
    brand: 'OpenAI Responses API',
    protocol: AiProtocol.openAiResponses,
    baseUrl: '',
    group: AiPresetGroup.custom,
    sendTemperature: false,
  ),
  AiProviderPreset(
    id: AiPresetIds.customAnthropic,
    brand: 'Anthropic API',
    protocol: AiProtocol.anthropic,
    baseUrl: '',
    group: AiPresetGroup.custom,
    sendTemperature: false,
  ),
  AiProviderPreset(
    id: AiPresetIds.customGemini,
    brand: 'Gemini API',
    protocol: AiProtocol.gemini,
    baseUrl: '',
    group: AiPresetGroup.custom,
  ),
];

AiProviderPreset? aiProviderPresetById(String? id) {
  if (id == null) return null;
  for (final preset in aiProviderPresets) {
    if (preset.id == id) return preset;
  }
  return null;
}
