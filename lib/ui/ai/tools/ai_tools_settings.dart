// 设置类的写工具：主题（明暗、主题色）、界面语言、字体大小、功能开关。
//
// 都经 SettingsService / saveAppFeatures 写同一份设置（ValueNotifier 驱动，
// 应用即时生效），撤销为写回原值。AI 助手自己的开关不在可改范围里（关掉
// 就没有这个对话了）；关掉日记本时若有私密本，要用户在功能管理里自己确认，
// 这里只给前往按钮。应用锁、密码、AI 服务商等一律只能前往页面。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_features.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_languages.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/providers/app_features_provider.dart';
import 'ai_tool.dart';

class SetThemeTool extends AiTool {
  const SetThemeTool();

  @override
  String get name => 'set_theme';

  @override
  AiToolGroup get group => AiToolGroup.settings;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Change the app theme: light, dark or system mode, and/or the theme '
      'color (#RRGGBB).';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'mode': AiStringSchema(enumValues: <String>['light', 'dark', 'system']),
      'color': AiStringSchema(description: '#RRGGBB'),
    },
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolSetTheme;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final settings = await context.container.read(
      settingsServiceProvider.future,
    );
    final mode = args['mode'] as String?;
    final rawColor = args['color'] as String?;
    if (mode == null && rawColor == null) {
      throw const AiToolFailure('Give `mode` and/or `color`.');
    }
    Color? color;
    if (rawColor != null) {
      final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(rawColor.trim());
      if (match == null) {
        throw const AiToolFailure('Colors are written as #RRGGBB.');
      }
      color = Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
    }
    final undo = <String, Object?>{
      if (mode != null) 'mode': settings.themeModeNotifier.value.name,
      if (color != null)
        'color': settings.themeSeedColorNotifier.value.toARGB32(),
    };
    if (mode != null) {
      await settings.setThemeMode(ThemeMode.values.byName(mode));
    }
    if (color != null) await settings.setThemeSeedColor(color);
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      undo: undo,
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final settings = await container.read(settingsServiceProvider.future);
    if (data['mode'] case final String mode) {
      await settings.setThemeMode(ThemeMode.values.byName(mode));
    }
    if (data['color'] case final int color) {
      await settings.setThemeSeedColor(Color(color));
    }
  }
}

class SetAppLanguageTool extends AiTool {
  const SetAppLanguageTool();

  @override
  String get name => 'set_app_language';

  @override
  AiToolGroup get group => AiToolGroup.settings;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Change the app interface language. Lunar calendar, solar terms and '
      'Chinese holidays stay as they are.';

  @override
  AiObjectSchema get schema => AiObjectSchema(
    properties: <String, AiSchema>{
      'language': AiStringSchema(
        enumValues: [for (final language in appLanguages) language.code],
      ),
    },
    required: const <String>['language'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final code = args['language'];
    final language = appLanguages.where((l) => l.code == code).firstOrNull;
    return l10n.aiToolSetLanguage(language?.nativeName ?? '$code');
  }

  @override
  String? describeArg(AppLocalizations l10n, String key, Object? value) {
    if (key != 'language') return null;
    final language = appLanguages.where((l) => l.code == value).firstOrNull;
    return language?.nativeName ?? '$value';
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final settings = await context.container.read(
      settingsServiceProvider.future,
    );
    final previous = settings.appLocaleCode;
    await settings.setAppLocaleCode(args['language']! as String);
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      undo: <String, Object?>{'language': previous},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final settings = await container.read(settingsServiceProvider.future);
    await settings.setAppLocaleCode(data['language']! as String);
  }
}

class SetFontScaleTool extends AiTool {
  const SetFontScaleTool();

  @override
  String get name => 'set_font_scale';

  @override
  AiToolGroup get group => AiToolGroup.settings;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Change the interface text size (1.0 = default; 0.85 to 1.3).';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'scale': AiNumberSchema(minimum: 0.85, maximum: 1.3),
    },
    required: <String>['scale'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolSetFontScale;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final settings = await context.container.read(
      settingsServiceProvider.future,
    );
    final previous = settings.fontScaleValue;
    await settings.setFontScale(args['scale']! as double);
    return AiToolOutcome(
      data: <String, Object?>{'ok': true, 'scale': settings.fontScaleValue},
      summary: context.l10n.aiToolDone,
      undo: <String, Object?>{'scale': previous},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final settings = await container.read(settingsServiceProvider.future);
    await settings.setFontScale((data['scale']! as num).toDouble());
  }
}

class SetFeatureEnabledTool extends AiTool {
  const SetFeatureEnabledTool();

  static const List<String> features = <String>[
    'calendar',
    'todos',
    'explore',
    'notebooks',
    'anniversaries',
    'templates',
    'time_capsules',
    'swipe_archive',
    'comments',
  ];

  @override
  String get name => 'set_feature_enabled';

  @override
  AiToolGroup get group => AiToolGroup.settings;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Turn an app feature on or off (Settings → Features). Turning a '
      'feature off only hides it; its data is kept. Anniversaries also need '
      'the calendar.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'feature': AiStringSchema(enumValues: features),
      'enabled': AiBooleanSchema(),
    },
    required: <String>['feature', 'enabled'],
  );

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final feature = _featureName(l10n, args['feature']);
    return args['enabled'] == false
        ? l10n.aiToolFeatureOff(feature)
        : l10n.aiToolFeatureOn(feature);
  }

  @override
  String? describeArg(AppLocalizations l10n, String key, Object? value) =>
      key == 'feature' ? _featureName(l10n, value) : null;

  /// 卡片上用功能管理页里的名称。
  static String _featureName(AppLocalizations l10n, Object? raw) =>
      switch (raw) {
        'calendar' => l10n.navCalendar,
        'todos' => l10n.navTodos,
        'explore' => l10n.navExplore,
        'notebooks' => l10n.notebookTitle,
        'anniversaries' => l10n.settingsFeaturesAnniversaries,
        'templates' => l10n.settingsFeaturesTemplates,
        'time_capsules' => l10n.settingsFeaturesTimeCapsules,
        'swipe_archive' => l10n.settingsFeaturesSwipeArchive,
        'comments' => l10n.settingsFeaturesComments,
        final other => '${other ?? ''}',
      };

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final container = context.container;
    final settings = await container.read(settingsServiceProvider.future);
    final current = container.read(appFeaturesProvider);
    final on = args['enabled']! as bool;
    final feature = args['feature']! as String;
    if (feature == 'notebooks' && !on) {
      final tree = await context.notebookTree();
      if (tree.notebooks.any((notebook) => notebook.isPrivate)) {
        throw const AiToolFailure(
          'There are private notebooks; the user must turn notebooks off '
          'themselves in Settings → Features (offer open_page '
          'settings_features).',
        );
      }
    }
    final next = switch (feature) {
      'calendar' => current.copyWith(calendar: on),
      'todos' => current.copyWith(todos: on),
      'explore' => current.copyWith(explore: on),
      'notebooks' => current.copyWith(notebooks: on),
      'anniversaries' => current.copyWith(anniversaries: on),
      'templates' => current.copyWith(templates: on),
      'time_capsules' => current.copyWith(timeCapsules: on),
      'swipe_archive' => current.copyWith(swipeArchive: on),
      _ => current.copyWith(comments: on),
    };
    await saveAppFeatures(settings, next);
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        if (feature == 'anniversaries' && on && !next.calendar)
          'note': 'Anniversaries only show when the calendar is on too.',
      },
      summary: context.l10n.aiToolDone,
      undo: <String, Object?>{'features': current.encode()},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final settings = await container.read(settingsServiceProvider.future);
    await saveAppFeatures(
      settings,
      AppFeatures.decode(data['features'] as String?),
    );
  }
}
