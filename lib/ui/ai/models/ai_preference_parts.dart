import 'package:meta/meta.dart';

/// AI 助手可单独开关的模块。
enum AiModule {
  /// 编辑器里的写作指令。
  writing,

  /// 智能填写：标题、标签、心情。
  suggest,

  /// 预览页的读后回应。
  reply,

  /// 新建空白日记时的写作灵感。
  prompts,

  /// 回顾总结与探索页 AI 卡片。
  recap,

  /// 与日记对话。
  chat,

  /// 图片理解：把日记里的图片一起发给模型（模型不认图片时自动只发文字）。
  vision;

  /// 总开关打开后默认开启的模块。现在全部默认开启；“默认关、需要单独打开”
  /// 的机制（偏好里的 `on` 列表）保留给以后可能新增的模块。
  bool get enabledByDefault => true;

  static AiModule? fromName(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

/// 回应 / 对话 / 回顾各自默认用哪个人设。
enum AiPersonaUse { reply, chat, recap }

/// 一个用户自建的人设。内置人设由 `AiBuiltInPersona` 从 ARB 生成，不存这里。
@immutable
class AiPersona {
  const AiPersona({
    required this.id,
    required this.name,
    required this.prompt,
    this.emoji = '🙂',
  });

  static const int maxNameLength = 24;
  static const int maxPromptLength = 2000;

  final String id;
  final String name;
  final String emoji;

  /// 系统提示词：描述这个人设的身份、语气与回应方式。
  final String prompt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'emoji': emoji,
    'prompt': prompt,
  };

  static AiPersona? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final prompt = raw['prompt'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;
    if (prompt is! String) return null;
    final emoji = raw['emoji'];
    return AiPersona(
      id: id,
      name: _clip(name.trim(), maxNameLength),
      prompt: _clip(prompt, maxPromptLength),
      emoji: emoji is String && emoji.isNotEmpty ? _clip(emoji, 8) : '🙂',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiPersona &&
      other.id == id &&
      other.name == name &&
      other.emoji == emoji &&
      other.prompt == prompt;

  @override
  int get hashCode => Object.hash(id, name, emoji, prompt);
}

/// 写作指令的结果怎么用。
enum AiActionOutput {
  /// 替换作用的文字。
  replace,

  /// 插在作用的文字下方。
  insertBelow,

  /// 只显示结果，由用户复制或再决定。
  preview;

  static AiActionOutput fromName(Object? raw, AiActionOutput fallback) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }
}

/// 一个用户自建的写作指令。提示词里可以写变量（见 `AiPromptVariables`）。
@immutable
class AiCustomAction {
  const AiCustomAction({
    required this.id,
    required this.name,
    required this.prompt,
    this.emoji = '✨',
    this.output = AiActionOutput.replace,
  });

  static const int maxNameLength = 16;
  static const int maxPromptLength = 2000;

  final String id;
  final String name;
  final String emoji;
  final String prompt;
  final AiActionOutput output;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'emoji': emoji,
    'prompt': prompt,
    'output': output.name,
  };

  static AiCustomAction? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final prompt = raw['prompt'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;
    if (prompt is! String || prompt.trim().isEmpty) return null;
    final emoji = raw['emoji'];
    return AiCustomAction(
      id: id,
      name: _clip(name.trim(), maxNameLength),
      prompt: _clip(prompt, maxPromptLength),
      emoji: emoji is String && emoji.isNotEmpty ? _clip(emoji, 8) : '✨',
      output: AiActionOutput.fromName(raw['output'], AiActionOutput.replace),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiCustomAction &&
      other.id == id &&
      other.name == name &&
      other.emoji == emoji &&
      other.prompt == prompt &&
      other.output == output;

  @override
  int get hashCode => Object.hash(id, name, emoji, prompt, output);
}

/// 回答用什么语言。
enum AiOutputLanguage {
  /// 跟随日记内容（中文日记用中文回应）。
  followDiary,

  /// 跟随应用界面语言。
  followApp,

  /// 用户指定（见 `AiOutputOptions.customLanguage`）。
  custom,
}

enum AiResponseLength { short, medium, long }

/// 创造力，映射成温度（只在服务商允许发送温度时生效）。
enum AiCreativity {
  precise,
  balanced,
  creative;

  /// 基准温度；各任务再按需要微调（智能填写更低、写作灵感更高）。
  double get temperature => switch (this) {
    precise => 0.3,
    balanced => 0.7,
    creative => 1.0,
  };
}

/// 发送前确认的时机。
enum AiConfirmMode {
  /// 每个服务商（主机）第一次发送时确认，勾“不再提示”后不再问。
  firstTime,

  /// 首次 + 每次要发送多篇日记（对话、回顾）时都显示篇数与字数。
  multiDiary,

  /// 每次发送都确认。
  always,
}

/// 灵感问题插进正文的样式。
enum AiPromptInsertStyle { callout, quote, heading }

/// 回顾可以包含的章节。
enum AiRecapSection {
  mood,
  events,
  people,
  gratitude,
  growth,
  quotes,
  suggestions;

  static const Set<AiRecapSection> defaults = <AiRecapSection>{
    mood,
    events,
    gratitude,
    growth,
    suggestions,
  };
}

/// 对话里怎么找相关的日记。
enum AiRetrievalMode {
  /// 先让快速模型理解问题、生成检索计划（关键词与时间范围），再查日记。
  smart,

  /// 只按问题里的关键词在本机查找。
  keyword,

  /// 只取最近 N 天的日记。
  recent,
}

T enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

String _clip(String value, int max) =>
    value.length <= max ? value : value.substring(0, max);
