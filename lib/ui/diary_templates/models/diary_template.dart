import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

import '../../../core/database/app_database.dart'
    show builtInDiaryTemplateIdPrefix;
import '../../diaries/models/time_capsule.dart';
import 'diary_template_recommend.dart';

/// 模板分类，决定选择面板的筛选项。
enum DiaryTemplateCategory { daily, review, mood, life, work, other }

/// 模板图标：只能从这组固定图标里选，持久化存枚举名，渲染时映射到
/// FontAwesome（见 `diary_template_icon_badge.dart`）。
enum DiaryTemplateIcon {
  penNib,
  sun,
  moon,
  cloudMoon,
  heart,
  handHoldingHeart,
  circleQuestion,
  calendarWeek,
  calendarDays,
  calendarCheck,
  faceSmile,
  brain,
  plane,
  mountainSun,
  personHiking,
  bookOpen,
  film,
  personRunning,
  dumbbell,
  briefcase,
  envelope,
  lightbulb,
  mugHot,
  seedling,
  feather,
  listCheck,
  clipboardList,
  star,
}

/// 模板预设的一个标签：按名称引用（标签在数据库里是本机自增 id，模板要能
/// 随模板码分享到另一台设备），颜色只在本机还没有这个标签、需要新建时使用。
@immutable
class DiaryTemplateTagRef {
  const DiaryTemplateTagRef({required this.name, required this.color});

  final String name;

  /// 不透明 ARGB。
  final int color;

  @override
  bool operator ==(Object other) =>
      other is DiaryTemplateTagRef &&
      other.name == name &&
      other.color == color;

  @override
  int get hashCode => Object.hash(name, color);
}

/// 一个日记模板（内置或用户自建），不可变、值相等。
///
/// 正文 [bodyJson] 是原生块文档 JSON 字符串，只含文字与分隔线（构造
/// 方保证经过 `sanitizeDiaryTemplateBlocks`），标题 [titlePattern] 与正文都可以
/// 含 `{{变量}}`，套用时才按日记日期替换。
@immutable
class DiaryTemplate {
  const DiaryTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.icon = DiaryTemplateIcon.penNib,
    this.accent,
    this.category = DiaryTemplateCategory.other,
    this.titlePattern = '',
    this.bodyJson = emptyBodyJson,
    this.tags = const <DiaryTemplateTagRef>[],
    this.mood,
    this.energy,
    this.capsule,
    this.recommend = DiaryTemplateRecommendRules.none,
  });

  static const String emptyBodyJson =
      '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[]}}]}}';
  static const int maxNameLength = 24;
  static const int maxDescriptionLength = 60;
  static const int maxTitleLength = 200;
  static const int maxTags = 10;

  final String id;
  final String name;
  final String description;
  final DiaryTemplateIcon icon;

  /// 强调色的种子（不透明 ARGB），null 时跟随主题色；渲染时经
  /// `diaryTemplateAccentColors` 换算成明暗主题各自的容器色，不直接涂这个值。
  final int? accent;
  final DiaryTemplateCategory category;
  final String titlePattern;
  final String bodyJson;
  final List<DiaryTemplateTagRef> tags;

  /// 预设心情（emoji）；只有本机心情选项里有它时才会套用。
  final String? mood;

  /// 预设精力 1–5。
  final int? energy;

  /// 预设的时间胶囊：从套用当天起算的固定时长。
  final TimeCapsulePreset? capsule;
  final DiaryTemplateRecommendRules recommend;

  bool get isBuiltIn => id.startsWith(builtInDiaryTemplateIdPrefix);

  /// 套用后除标题、正文外还会带上的东西。
  bool get hasPresets =>
      tags.isNotEmpty || mood != null || energy != null || capsule != null;

  DiaryTemplate copyWith({
    String? id,
    String? name,
    String? description,
    DiaryTemplateIcon? icon,
    int? Function()? accent,
    DiaryTemplateCategory? category,
    String? titlePattern,
    String? bodyJson,
    List<DiaryTemplateTagRef>? tags,
    String? Function()? mood,
    int? Function()? energy,
    TimeCapsulePreset? Function()? capsule,
    DiaryTemplateRecommendRules? recommend,
  }) {
    return DiaryTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      accent: accent == null ? this.accent : accent(),
      category: category ?? this.category,
      titlePattern: titlePattern ?? this.titlePattern,
      bodyJson: bodyJson ?? this.bodyJson,
      tags: tags ?? this.tags,
      mood: mood == null ? this.mood : mood(),
      energy: energy == null ? this.energy : energy(),
      capsule: capsule == null ? this.capsule : capsule(),
      recommend: recommend ?? this.recommend,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryTemplate &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.icon == icon &&
      other.accent == accent &&
      other.category == category &&
      other.titlePattern == titlePattern &&
      other.bodyJson == bodyJson &&
      listEquals(other.tags, tags) &&
      other.mood == mood &&
      other.energy == energy &&
      other.capsule == capsule &&
      other.recommend == recommend;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    icon,
    accent,
    category,
    titlePattern,
    bodyJson,
    Object.hashAll(tags),
    mood,
    energy,
    capsule,
    recommend,
  );
}

/// 单行文本归一：去首尾空白、把连续空白（含换行）折成一个空格，再按字素
/// 截到 [max] 个字符，不会把 emoji 截成半个。
String normalizeDiaryTemplateLine(String raw, int max) {
  final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  final characters = collapsed.characters;
  if (characters.length <= max) return collapsed;
  return characters.take(max).toString().trimRight();
}
