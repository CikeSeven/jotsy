// 日历类的写工具：纪念日、这天的心情，以及留言（待办见
// `ai_tools_todo_writes.dart`）。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../anniversaries/controllers/anniversary_edit_controller.dart';
import '../../anniversaries/models/anniversary_draft.dart';
import 'ai_tool.dart';
import 'ai_tool_writes.dart';
import '../models/ai_tool_subject.dart';

class CreateAnniversaryTool extends AiTool {
  const CreateAnniversaryTool();

  @override
  String get name => 'create_anniversary';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Add an anniversary or countdown day. `repeat`: once (count down to / '
      'up from the date), yearly, or lunar_yearly (Chinese lunar calendar; '
      'give the solar date of one occurrence and the lunar day is derived '
      'from it).';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'title': AiStringSchema(maxLength: 100),
      'date': AiDateSchema(),
      'repeat': AiStringSchema(
        enumValues: <String>['once', 'yearly', 'lunar_yearly'],
      ),
      'note': AiStringSchema(),
    },
    required: <String>['title', 'date', 'repeat'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.anniversariesEnabled;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolCreateAnniversary('${args['title'] ?? ''}');

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final result = await AnniversaryEditController(context.database).save(
      AnniversaryDraft(
        title: (args['title']! as String).trim(),
        date: args['date']! as DateTime,
        recurrence: switch (args['repeat']) {
          'yearly' => AnniversaryRecurrence.solarYearly,
          'lunar_yearly' => AnniversaryRecurrence.lunarYearly,
          _ => AnniversaryRecurrence.once,
        },
        note: (args['note'] as String?)?.trim() ?? '',
      ),
    );
    final id = (result as AnniversaryCreated).anniversaryId;
    return AiToolOutcome(
      data: <String, Object?>{'ok': true, 'id': id},
      summary: context.l10n.aiToolDone,
      subjects: [
        AiToolSubject.anniversary(
          id,
          (args['title']! as String).trim(),
          date: args['date']! as DateTime,
        ),
      ],
      undo: <String, Object?>{'id': id},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    await container
        .read(appDatabaseProvider)
        .deleteAnniversary(data['id']! as String);
  }
}

class DeleteAnniversaryTool extends AiTool {
  const DeleteAnniversaryTool();

  @override
  String get name => 'delete_anniversary';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.destructive;

  @override
  String get description =>
      'Delete an anniversary (by id). The user confirms first.';

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{'id': AiStringSchema()},
    required: <String>['id'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.anniversariesEnabled;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolDeleteAnniversary;

  Future<Anniversary> _find(AiToolContext context, String id) async {
    final rows = await context.database.watchAnniversaries().first;
    for (final row in rows) {
      if (row.anniversaryId == id) return row;
    }
    throw AiToolFailure('No anniversary with id $id.');
  }

  @override
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final row = await _find(context, args['id']! as String);
    return AiToolPreview(
      title: label(context.l10n, args),
      lines: ['${row.title}  ${row.baseDate}'],
    );
  }

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final row = await _find(context, args['id']! as String);
    await context.database.deleteAnniversary(row.anniversaryId);
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      subjects: [
        AiToolSubject.anniversary(
          row.anniversaryId,
          row.title,
          date: parseAnniversaryDate(row.baseDate),
        ),
      ],
      undo: <String, Object?>{'row': row.toJson()},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) => container
      .read(appDatabaseProvider)
      .restoreAnniversary(
        Anniversary.fromJson((data['row']! as Map).cast<String, dynamic>()),
      );
}

class SetDayMoodTool extends AiTool {
  const SetDayMoodTool();

  @override
  String get name => 'set_day_mood';

  @override
  AiToolGroup get group => AiToolGroup.calendar;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      "Set (or clear) the calendar's mood for a whole day: awful, bad, meh, "
      "good or great. This is separate from an entry's mood emoji.";

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'date': AiDateSchema(),
      'mood': AiStringSchema(
        enumValues: <String>['awful', 'bad', 'meh', 'good', 'great', 'clear'],
      ),
    },
    required: <String>['date', 'mood'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.calendar;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolSetDayMood('${args['date'] ?? ''}');

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final database = context.database;
    final day = args['date']! as DateTime;
    final key = formatAnniversaryDate(day);
    final previous = (await database.watchDayMoods().first)
        .where((row) => row.day == key)
        .firstOrNull;
    final mood = args['mood']! as String;
    if (mood == 'clear') {
      await database.clearDayMood(day);
    } else {
      await database.setDayMood(day, DayMood.values.byName(mood));
    }
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      subjects: [AiToolSubject.day(day)],
      undo: <String, Object?>{
        'day': key,
        if (previous != null) 'previous': previous.toJson(),
      },
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    final database = container.read(appDatabaseProvider);
    final previous = data['previous'];
    if (previous is Map) {
      await database.restoreDayMood(
        DayMoodRow.fromJson(previous.cast<String, dynamic>()),
      );
    } else {
      await database.clearDayMood(
        parseAnniversaryDate(data['day']! as String)!,
      );
    }
  }
}

class AddCommentTool extends AiTool {
  const AddCommentTool();

  @override
  String get name => 'add_comment';

  @override
  AiToolGroup get group => AiToolGroup.diaries;

  @override
  AiToolEffect get effect => AiToolEffect.write;

  @override
  String get description =>
      'Add a comment (a short note shown under the entry, written as the '
      'user) to an entry by id. Only when the user asks for it.';

  @override
  Set<String> get diaryIdArgs => const <String>{'id'};

  @override
  AiObjectSchema get schema => const AiObjectSchema(
    properties: <String, AiSchema>{
      'id': AiStringSchema(),
      'text': AiStringSchema(maxLength: 1000),
    },
    required: <String>['id', 'text'],
  );

  @override
  bool isAvailable(AiToolEnv env) => env.features.comments;

  @override
  String label(AppLocalizations l10n, Map<String, Object?> args) =>
      l10n.aiToolAddComment;

  @override
  Future<AiToolOutcome> run(
    AiToolContext context,
    Map<String, Object?> args,
  ) async {
    final found = await aiWritableDiary(context, args['id']! as String);
    final id = await context.database.addDiaryComment(
      diaryId: found.diary.diaryId,
      content: (args['text']! as String).trim(),
    );
    return AiToolOutcome(
      data: const <String, Object?>{'ok': true},
      summary: context.l10n.aiToolDone,
      subjects: [aiDiarySubject(found.diary)],
      undo: <String, Object?>{'id': id},
    );
  }

  @override
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) async {
    await container
        .read(appDatabaseProvider)
        .deleteDiaryComment(data['id']! as String);
  }
}
