// 应用层面的工具：今天与应用状态、使用指南、前往某个页面。

import 'package:intl/intl.dart';

import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_features.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/viewmodels/calendar_holiday_day.dart';
import '../../calendar/viewmodels/calendar_lunar_day.dart';
import 'ai_destinations.dart';
import 'ai_tool.dart';

/// 今天的日期（含农历、节气、法定节假日）、平台、界面语言、开启的功能与
/// 用户的心情选项。模型安排日期、判断某功能能不能用之前调用。
class GetAppContextTool extends AiTool {
  const GetAppContextTool();

  @override
  String get name => 'get_app_context';

  @override
  AiToolGroup get group => AiToolGroup.app;

  @override
  AiToolEffect get effect => AiToolEffect.read;

  @override
  String get description =>
      "Today's date and time (with Chinese lunar date, solar term and "
      'public holiday), the platform, app language, which features are '
      "turned on, and the user's mood options. Call it before working "
      'with relative dates or when unsure whether a feature is available.';

  @override
  AiObjectSchema get schema =>
      const AiObjectSchema(properties: <String, AiSchema>{});

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolGetAppContext;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final settings = await context.container.read(
      settingsServiceProvider.future,
    );
    final today = context.today;
    final lunar = CalendarLunarDay.of(today);
    final holiday = CalendarHolidayDay.of(today);
    final features = context.env.features;
    return AiToolOutcome(
      data: <String, Object?>{
        'now': aiToolDateTime(context.now),
        'weekday': DateFormat.EEEE('en').format(today),
        'lunar_date': lunar.date,
        'solar_term_period': lunar.termPeriod,
        'solar_term_today': ?lunar.term,
        if (lunar.festivals.isNotEmpty) 'festivals': lunar.festivals,
        if (holiday != null)
          'public_holiday': <String, Object?>{
            'name': holiday.name,
            'is_make_up_workday': holiday.isWork,
          },
        'platform': aiPlatformName(),
        'app_language': context.l10n.localeName,
        'features': <String, bool>{
          'calendar': features.calendar,
          'todos': features.todos,
          'explore': features.explore,
          'notebooks': features.notebooks,
          'anniversaries': features.anniversariesEnabled,
          'templates': features.templates,
          'time_capsules': features.timeCapsules,
          'comments': features.comments,
        },
        'mood_options': settings.moodOptions,
        'diary_words_left_this_turn': context.allowance.remaining,
      },
    );
  }
}

/// 当前平台在工具结果与指南头信息里的写法。
String aiPlatformName() {
  if (AppPlatform.isAndroid) return 'android';
  if (AppPlatform.isIOS) return 'ios';
  if (AppPlatform.isWindows) return 'windows';
  if (AppPlatform.isMacOS) return 'macos';
  if (AppPlatform.isLinux) return 'linux';
  return 'other';
}

/// 给用户一个“前往”按钮，打开应用里的某个页面。
class OpenPageTool extends AiTool {
  const OpenPageTool();

  @override
  String get name => 'open_page';

  @override
  AiToolGroup get group => AiToolGroup.navigation;

  @override
  AiToolEffect get effect => AiToolEffect.navigate;

  @override
  String get description =>
      'Show the user a button that opens a page of the app. Use it whenever '
      'the user should finish something themselves (backup, restore, '
      'import, export, sharing, app lock, passwords, AI providers) or asks '
      'where a setting is. Set `now` only when the user explicitly asked to '
      'open the page: it then opens after your reply. Destinations: '
      'tab_* = main tabs; diary (needs diary_id); notebook (needs '
      'notebook_id); todo (needs todo_id); search (optional query); '
      'settings_* = settings pages; the rest are named after their page.';

  @override
  AiObjectSchema get schema => AiObjectSchema(
    properties: <String, AiSchema>{
      'destination': AiStringSchema(
        enumValues: [for (final d in aiDestinations) d.id],
      ),
      'diary_id': const AiStringSchema(),
      'notebook_id': const AiStringSchema(),
      'todo_id': const AiStringSchema(),
      'query': const AiStringSchema(description: 'Keywords for `search`.'),
      'now': const AiBooleanSchema(),
    },
    required: const <String>['destination'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final id = args['destination'];
    final destination = id is String ? aiDestinationById(id) : null;
    return l10n.aiToolOpenPage(destination?.title(l10n) ?? '$id');
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final destination = aiDestinationById(args['destination']! as String)!;
    if (!destination.isAvailable(context.env)) {
      throw AiToolFailure(
        'This page is not available: its feature is turned off or this '
        'platform does not have it.',
        summary: context.l10n.aiToolPageUnavailable,
      );
    }
    final params = <String, Object?>{
      for (final key in const ['diary_id', 'notebook_id', 'todo_id', 'query'])
        if (args[key] case final String value) key: value,
    };
    final missing = destination.requires.difference(params.keys.toSet());
    if (missing.isNotEmpty) {
      throw AiToolFailure('`${missing.first}` is required for this page.');
    }
    final now = args['now'] == true;
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        'note': now
            ? 'The page opens right after your reply.'
            : 'A button that opens the page is shown under your reply.',
      },
      navigation: AiToolNavigation(
        destination: destination.id,
        params: params,
        now: now,
      ),
    );
  }
}

/// 读使用指南的文章（目录在系统提示词里）。结果按当前功能开关与平台注明
/// “这个功能现在关着 / 本平台没有”，并列出现在能打开的相关页面。
class ReadGuideTool extends AiTool {
  const ReadGuideTool();

  /// 一次读取最多返回的正文字数（长文章用 offset 接着读）。
  static const int pageChars = 8000;

  @override
  String get name => 'read_guide';

  @override
  AiToolGroup get group => AiToolGroup.app;

  @override
  AiToolEffect get effect => AiToolEffect.read;

  @override
  String get description =>
      'Read articles of the built-in user guide by id (the index is in the '
      'system prompt). Read the relevant article before explaining how to '
      'use the app or where a setting is, and answer from it. Long articles '
      'continue with `offset`.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'ids': AiArraySchema(items: AiStringSchema(), maxItems: 3),
      'offset': AiIntegerSchema(minimum: 0),
    },
    required: <String>['ids'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolReadGuide;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final offset = args['offset'] as int? ?? 0;
    final results = <Map<String, Object?>>[];
    final titles = <String>[];
    for (final id in (args['ids']! as List).cast<String>()) {
      final article = context.guide.byId(id);
      if (article == null) {
        results.add(<String, Object?>{
          'id': id,
          'error': 'No guide article with this id; see the index.',
        });
        continue;
      }
      titles.add(article.title);
      final body = article.body;
      final start = offset < body.length ? offset : body.length;
      final end = start + pageChars < body.length
          ? start + pageChars
          : body.length;
      final off = [
        for (final feature in article.features)
          if (!_featureOn(context.env.features, feature)) feature,
      ];
      final platform = aiPlatformName();
      results.add(<String, Object?>{
        'id': article.id,
        'title': article.title,
        'text': body.substring(start, end),
        if (end < body.length) 'next_offset': end,
        if (off.isNotEmpty)
          'note_features_off':
              'These features are turned off now: ${off.join(', ')}. The user '
              'can turn them on in Settings → Features (open_page '
              'settings_features).',
        if (article.platforms.isNotEmpty &&
            !article.platforms.contains(platform))
          'note_platform':
              'Not available on this device ($platform); only on '
              '${article.platforms.join(', ')}.',
        'open_pages': [
          for (final id in article.destinations)
            if (aiDestinationById(id)?.isAvailable(context.env) ?? false) id,
        ],
      });
    }
    return AiToolOutcome(
      data: <String, Object?>{'articles': results},
      summary: titles.isEmpty ? null : titles.join('、'),
    );
  }

  /// 指南头信息里的功能名对应的开关；认不出的当作开着。
  static bool _featureOn(AppFeatures features, String name) => switch (name) {
    'calendar' => features.calendar,
    'todos' => features.todos,
    'explore' => features.explore,
    'notebooks' => features.notebooks,
    'anniversaries' => features.anniversariesEnabled,
    'templates' => features.templates,
    'timeCapsules' => features.timeCapsules,
    'swipeArchive' => features.swipeArchive,
    'comments' => features.comments,
    'ai' => features.ai,
    _ => true,
  };
}
