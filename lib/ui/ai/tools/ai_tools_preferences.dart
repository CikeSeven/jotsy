// 应用设置的查看与修改：`get_settings` 列出现在的值，`change_settings` 一次
// 改一项或几项。能改哪些只看 `ai_setting_specs.dart` 的清单（参数 schema 由
// 清单生成，本平台没有的项不进 schema）。
//
// 修改：先校验全部参数（所属功能是否开启、取值是否合规、清单名称是否存在），
// 都通过才依次写入，不留半截改动；值本来就相同的项不写。撤销按每项改动前的
// 值逐项写回（只动这几项，期间用户在同一页改的别的设置不受影响）。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../models/ai_tool_subject.dart';
import 'ai_setting_specs.dart';
import 'ai_tool.dart';
import 'ai_tool_todo_parts.dart';

String _hhmm(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';

/// 存储口径的值 → 发给模型的写法（时刻写 `HH:MM`，默认清单写名称）。
Future<Object?> _present(
  AiToolContext context,
  AiSettingSpec spec,
  Object? value,
) async {
  if (spec.key == aiDefaultTodoListKey) {
    final list = value is String
        ? await context.database.getTodoList(value)
        : null;
    return list?.name ?? aiTodoInboxName;
  }
  if (spec.schema is AiTimeSchema && value is int) return _hhmm(value);
  return value;
}

class GetSettingsTool extends AiTool {
  const GetSettingsTool();

  @override
  String get name => 'get_settings';

  @override
  AiToolGroup get group => AiToolGroup.settings;

  @override
  AiToolEffect get effect => AiToolEffect.read;

  @override
  String get description =>
      'Current values of the settings change_settings can change, plus the '
      'theme, theme color, text size and app language. Settings of features '
      'that are off are left out.';

  @override
  AiObjectSchema get schema =>
      const AiObjectSchema(properties: <String, AiSchema>{});

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolGetSettings;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final settings = await context.container.read(
      settingsServiceProvider.future,
    );
    final features = context.env.features;
    final values = <String, Object?>{};
    for (final spec in aiSettingSpecs) {
      if (!spec.onThisPlatform || !spec.enabledBy(features)) continue;
      values[spec.key] = await _present(context, spec, spec.read(settings));
    }
    final color = settings.themeSeedColorNotifier.value.toARGB32() & 0xFFFFFF;
    return AiToolOutcome(
      data: <String, Object?>{
        'settings': values,
        'appearance': <String, Object?>{
          'theme_mode': settings.themeModeNotifier.value.name,
          'theme_color':
              '#${color.toRadixString(16).padLeft(6, '0').toUpperCase()}',
          'text_size': settings.fontScaleValue,
          'app_language': settings.appLocaleCode,
        },
      },
    );
  }
}

class ChangeSettingsTool extends AiTool {
  const ChangeSettingsTool();

  @override
  String get name => 'change_settings';

  @override
  AiToolGroup get group => AiToolGroup.settings;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Change app settings: each parameter is one setting, give only those '
      'to change (current values: get_settings). Settings of a feature that '
      'is off cannot be changed. Theme, language, text size and features '
      'have their own tools.';

  @override
  AiObjectSchema get schema => AiObjectSchema(
    properties: <String, AiSchema>{
      for (final spec in aiSettingSpecs)
        if (spec.onThisPlatform) spec.key: spec.schema,
    },
  );

  List<AiSettingSpec> _specsIn(Map<String, Object?> args) => [
    for (final key in args.keys)
      if (aiSettingSpec(key) case final spec?) spec,
  ];

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) {
    final specs = _specsIn(args);
    return switch (specs.length) {
      0 => l10n.aiToolChangeSettingsAny,
      1 => l10n.aiToolChangeSetting(specs.single.label(l10n)),
      final count => l10n.aiToolChangeSettings(count),
    };
  }

  @override
  String? argLabel(AppLocalizations l10n, String key) =>
      aiSettingSpec(key)?.label(l10n);

  @override
  String? describeArg(AppLocalizations l10n, String key, Object? value) {
    final spec = aiSettingSpec(key);
    if (spec == null) return null;
    if (value is bool) return value ? l10n.aiToolArgOn : l10n.aiToolArgOff;
    return spec.valueText?.call(l10n, value);
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final settings = await context.container.read(
      settingsServiceProvider.future,
    );
    final features = context.env.features;
    if (args.isEmpty) {
      throw const AiToolFailure(
        'Give at least one setting to change (see get_settings).',
      );
    }
    // 1. 全部校验并换算成存储口径，再写。
    final planned = <AiSettingSpec, Object?>{};
    final subjects = <AiToolSubject>[];
    for (final MapEntry(:key, :value) in args.entries) {
      final spec = aiSettingSpec(key)!;
      if (!spec.enabledBy(features)) {
        throw AiToolFailure(
          '`$key` belongs to a feature that is off; turn it on with '
          'set_feature_enabled first if the user wants it.',
        );
      }
      if (spec.check?.call(value) case final String problem) {
        throw AiToolFailure(problem);
      }
      if (key == aiDefaultTodoListKey) {
        final listId = await aiTodoListId(context.database, value! as String);
        planned[spec] = listId;
        if (listId != null) {
          subjects.add(
            AiToolSubject.todoList(
              listId,
              (value as String).trim(),
              input: true,
            ),
          );
        }
      } else {
        planned[spec] = value;
      }
    }
    // 2. 依次写入；本来就是这个值的不写。
    final previous = <String, Object?>{};
    final unchanged = <String>[];
    for (final MapEntry(key: spec, :value) in planned.entries) {
      final before = spec.read(settings);
      if (before == value) {
        unchanged.add(spec.key);
        continue;
      }
      await spec.write(settings, value);
      previous[spec.key] = before;
    }
    return AiToolOutcome(
      data: <String, Object?>{
        'ok': true,
        if (previous.isNotEmpty) 'changed': previous.keys.toList(),
        if (unchanged.isNotEmpty) 'already_set': unchanged,
      },
      summary: context.l10n.aiToolDone,
      subjects: subjects,
      undo: <String, Object?>{'previous': previous},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final settings = await container.read(settingsServiceProvider.future);
    final previous = (data['previous']! as Map).cast<String, Object?>();
    for (final MapEntry(:key, :value) in previous.entries.toList().reversed) {
      await aiSettingSpec(key)?.write(settings, value);
    }
  }
}
