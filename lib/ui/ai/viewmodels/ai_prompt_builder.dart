// 提示词构建（纯函数，不碰数据库与网络）。
//
// 各功能把“要做什么”交给 [AiPromptKit]，由它统一加上：基础身份、关于我、
// 文风、人设、回答语言与长度，以及按隐私设置决定的日记元数据。提示词文本
// 全部来自 ARB：按“回答语言”选中文或英文的 l10n（[AiPromptKit.resolve]），
// 其他语言用英文提示词，再加一句“请用某某语言回答”。

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/text_stats.dart';
import '../models/ai_built_ins.dart';
import '../models/ai_preference_parts.dart';
import '../models/ai_preferences.dart';
import 'ai_context_budget.dart';

/// 一次请求用的提示词工具：确定了提示词语言与偏好。
class AiPromptKit {
  AiPromptKit._(this.l10n, this.prefs, this._languageLine);

  /// [sample] 是这次要处理的文字（用来判断“跟随日记”时的语言）；
  /// [appLocale] 是界面语言。
  factory AiPromptKit.resolve({
    required AiPreferences prefs,
    required Locale appLocale,
    String sample = '',
  }) {
    final zh = lookupAppLocalizations(const Locale('zh'));
    final en = lookupAppLocalizations(const Locale('en'));
    final appIsZh = appLocale.languageCode == 'zh';
    switch (prefs.language) {
      case AiOutputLanguage.followDiary:
        final chinese = sample.trim().isEmpty
            ? appIsZh
            : aiTextLooksChinese(sample);
        final l10n = chinese ? zh : en;
        return AiPromptKit._(l10n, prefs, l10n.aiPromptRespondLikeDiary);
      case AiOutputLanguage.followApp:
        final l10n = appIsZh ? zh : en;
        return AiPromptKit._(
          l10n,
          prefs,
          l10n.aiPromptRespondIn(
            appIsZh
                ? l10n.aiPromptLanguageChinese
                : l10n.aiPromptLanguageEnglish,
          ),
        );
      case AiOutputLanguage.custom:
        final name = prefs.customLanguage.trim();
        if (name.isEmpty) {
          final l10n = appIsZh ? zh : en;
          return AiPromptKit._(l10n, prefs, l10n.aiPromptRespondLikeDiary);
        }
        // 语言名本身是中文写的（如“日语”）就用中文提示词，用户读得懂。
        final l10n = aiTextLooksChinese(name) ? zh : en;
        return AiPromptKit._(l10n, prefs, l10n.aiPromptRespondIn(name));
    }
  }

  /// 提示词所用的语言。
  final AppLocalizations l10n;
  final AiPreferences prefs;
  final String _languageLine;

  /// 系统提示词：基础身份 + [task]（任务自己的系统说明）+ 人设 + 关于我 +
  /// 文风（[withStyle]）+ 回答长度（[withLength]）+ 回答语言。
  String system({
    String? task,
    AiPersonaInfo? persona,
    bool withStyle = false,
    bool withLength = false,
  }) {
    final lines = <String>[l10n.aiPromptSystemBase];
    if (task != null && task.trim().isNotEmpty) lines.add(task.trim());
    if (persona != null && persona.prompt.trim().isNotEmpty) {
      lines.add(l10n.aiPromptPersona(persona.prompt.trim()));
    }
    if (prefs.aboutMe.trim().isNotEmpty) {
      lines.add(l10n.aiPromptAboutUser(prefs.aboutMe.trim()));
    }
    if (withStyle && prefs.writingStyle.trim().isNotEmpty) {
      lines.add(l10n.aiPromptWritingStyle(prefs.writingStyle.trim()));
    }
    if (withLength) {
      lines.add(switch (prefs.length) {
        AiResponseLength.short => l10n.aiPromptLengthShort,
        AiResponseLength.medium => l10n.aiPromptLengthMedium,
        AiResponseLength.long => l10n.aiPromptLengthLong,
      });
    }
    lines.add(_languageLine);
    return lines.join('\n\n');
  }

  /// 日期的写法（提示词语言）。
  String date(DateTime value) =>
      DateFormat.yMMMEd(l10n.localeName).format(value);

  /// 一篇日记的文字块：可选编号 `[Dn]`、标题、按隐私设置的元数据与正文。
  /// [maxWords] 给出时正文截断到这么多字（`TextStats` 口径）。
  String diary(AiContextDiary diary, {String? ref, int? maxWords}) {
    final privacy = prefs.privacy;
    final lines = <String>[];
    final head = <String>[
      ?ref,
      if (diary.title.trim().isNotEmpty)
        '${l10n.aiPromptFieldTitle}: ${diary.title.trim()}',
    ];
    if (head.isNotEmpty) lines.add(head.join(' '));
    if (privacy.sendDate) {
      lines.add('${l10n.aiPromptFieldDate}: ${date(diary.createdAt)}');
    }
    if (privacy.sendMood && diary.mood != null) {
      lines.add('${l10n.aiPromptFieldMood}: ${diary.mood}');
    }
    if (privacy.sendTags && diary.tags.isNotEmpty) {
      lines.add('${l10n.aiPromptFieldTags}: ${diary.tags.join(', ')}');
    }
    if (privacy.sendWeather && diary.weather != null) {
      lines.add('${l10n.aiPromptFieldWeather}: ${diary.weather}');
    }
    if (privacy.sendLocation && diary.location != null) {
      lines.add('${l10n.aiPromptFieldLocation}: ${diary.location}');
    }
    var body = diary.contentText.trim();
    if (maxWords != null) {
      final cut = aiTruncateWords(body, maxWords);
      if (cut.length < body.length) body = '$cut ${l10n.aiPromptTruncated}';
    }
    lines.add('${l10n.aiPromptFieldBody}:\n$body');
    return lines.join('\n');
  }

  /// 任务的温度：以“创造力”为基准按任务微调，夹在 0–1（各家都接受的
  /// 范围）。服务商不发送温度时客户端会忽略它。
  double temperature(AiTaskKind task) {
    final base = prefs.creativity.temperature;
    final value = switch (task) {
      AiTaskKind.suggest || AiTaskKind.utility => 0.2,
      AiTaskKind.vision => 0.3,
      AiTaskKind.recap => base - 0.1,
      AiTaskKind.reply => base + 0.1,
      AiTaskKind.prompts => base + 0.2,
      AiTaskKind.writing || AiTaskKind.chat => base,
    };
    return value.clamp(0.0, 1.0);
  }
}

/// 粗判一段文字是不是以中文为主（中文字数不少于非中文单词数）。
bool aiTextLooksChinese(String text) {
  final sample = text.length > 2000 ? text.substring(0, 2000) : text;
  final stats = TextStats.of(sample);
  return stats.cjk > 0 && stats.cjk >= stats.latinWords;
}
