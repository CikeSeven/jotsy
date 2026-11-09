// AI 助手可调用的工具：接口、运行上下文与结果。
//
// 接入一个新工具（后续功能也照此接入）：
// 1. 在对应领域的 `ai_tools_<领域>.dart` 里继承 [AiTool]，写好名称（snake_case，
//    发布后不改）、英文说明与参数 schema（接口定义，不进 ARB）、卡片标题
//    [AiTool.label]（走 l10n）与 [AiTool.run]；
// 2. 把它加进 `ai_tool_registry.dart` 的清单；
// 3. 数据读写只经现有的 DB ops / 控制器，日记内容只经 `getAiContextDiaries`
//    （多篇）与 `aiDiaryAllowedIn`（单篇），并把正文字数计入
//    [AiToolContext.allowance]；接收日记 id 的参数登记在 [AiTool.diaryIdArgs]
//    （模型传回的编号 `D3` 在执行前换成 id）；
// 4. 补测试：可用性（功能关闭时不出现）、主流程与一个异常路径。
//
// 工具失败时抛 [AiToolFailure]（说明原样回传模型，让它改正或换个做法），
// 不要返回半截结果。工具不持有 BuildContext：要打开页面时返回
// [AiToolNavigation]，由对话页显示“前往”按钮。

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/agent/ai_tool_schema.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/app_features.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/http_cancel_token.dart';
import '../../../l10n/app_localizations.dart';
import '../../notebooks/viewmodels/notebook_tree.dart';
import '../../settings/providers/app_features_provider.dart';
import '../models/ai_guide.dart';
import '../models/ai_preferences.dart';
import '../models/ai_tool_subject.dart';
import '../viewmodels/ai_prompt_builder.dart';
import '../viewmodels/ai_task_prompts.dart';

/// 工具所属的领域：决定卡片图标的分组，也是设置里“可用的工具”的单位。
enum AiToolGroup { app, diaries, organize, calendar, settings, navigation }

/// 工具的效果，决定确认与撤销口径。
enum AiToolEffect {
  /// 只读：直接执行。
  read,

  /// 改动数据：直接执行，必须可撤销。
  write,

  /// 删除类：执行前在对话里确认。
  destructive,

  /// 只给“前往”按钮，不改数据。
  navigate,
}

/// 发送时固定的运行环境，决定哪些工具可用。
@immutable
class AiToolEnv {
  const AiToolEnv({
    required this.features,
    required this.prefs,
    this.vision = false,
  });

  final AppFeatures features;
  final AiPreferences prefs;

  /// 这一轮能把图片发给模型：图片理解开着，且模型现在收图片
  /// （`AiService.acceptsImages`）。轮开始时定下，决定“查看图片”给不给。
  final bool vision;
}

abstract class AiTool {
  const AiTool();

  /// 发给模型的名称：字母、数字、下划线，全局唯一，发布后不改。
  String get name;

  AiToolGroup get group;

  AiToolEffect get effect;

  /// 发给模型的说明（英文，短：作用、参数含义与必要限制）。
  String get description;

  AiObjectSchema get schema;

  /// 值是日记 id 的参数（字符串或字符串数组）。执行前经
  /// [AiCitationBook.resolveDiaryArgs] 把其中的编号（`D3`）换成日记 id：
  /// 查询结果里每篇同时有编号与 id，模型常把编号当 id 传回来，原样查库
  /// 每篇都“找不到”。接收日记 id 的工具都必须在这里登记。
  Set<String> get diaryIdArgs => const <String>{};

  /// 这次运行能不能用（功能开关、平台）。
  bool isAvailable(AiToolEnv env) => true;

  /// 步骤卡片上的一行标题（界面语言）。[args] 为模型给的原始参数。
  String label(AppLocalizations l10n, Map<String, Object?> args);

  /// 执行过后、知道涉及对象时的标题（写出具体名称，如“把 3 篇日记收进
  /// 「旅行手记」”）；默认同 [label]。[subjects] 为调用记下的涉及对象。
  String labelWith(
    AppLocalizations l10n,
    Map<String, Object?> args,
    List<AiToolSubject> subjects,
  ) => label(l10n, args);

  /// 可读详情里某个参数的读法（`aiToolFacts`）：返回 null 用通用格式，
  /// 返回空串表示不列这一项。
  String? describeArg(AppLocalizations l10n, String key, Object? value) => null;

  /// 可读详情里某个参数的名称：返回 null 用 `aiToolArgName` 的译名。参数
  /// 名本身就是某个界面名称时（如 `change_settings` 的每个参数是一项设置）
  /// 由工具给出，不必为每个参数在 ARB 里另写一份。
  String? argLabel(AppLocalizations l10n, String key) => null;

  /// 执行。[args] 已经过 [schema] 校验与转换（日期为 `DateTime`，时间为
  /// 一天中的分钟数）。
  Future<AiToolOutcome> run(AiToolContext context, Map<String, Object?> args);

  /// 执行前给用户确认时的内容（删除类，或开了“改动前确认”的写操作）。
  /// 返回 null 时只显示 [label]。可以读库（例如列出要删的日记标题），不能
  /// 改动任何数据。
  Future<AiToolPreview?> preview(
    AiToolContext context,
    Map<String, Object?> args,
  ) async => null;

  /// 撤销 [run] 的结果（[data] 为 [AiToolOutcome.undo]）。数据在那之后又被
  /// 别处改过、且 [force] 为 false 时抛 [AiUndoConflict]，由界面问过用户再
  /// 带着 `force: true` 重来。写工具必须实现。
  Future<void> undo(
    ProviderContainer container,
    Map<String, Object?> data, {
    bool force = false,
  }) => throw UnsupportedError('$name cannot be undone');

  AiToolSpec get spec => AiToolSpec(
    name: name,
    description: description,
    parameters: schema.toJson(),
  );
}

/// 工具执行失败：[message]（英文）回传模型；[summary] 为卡片上的简短说明
/// （界面语言，可空）。
class AiToolFailure implements Exception {
  const AiToolFailure(this.message, {this.summary});

  final String message;
  final String? summary;

  @override
  String toString() => message;
}

/// 工具的结果。
@immutable
class AiToolOutcome {
  const AiToolOutcome({
    required this.data,
    this.summary,
    this.navigation,
    this.undo,
    this.subjects = const <AiToolSubject>[],
  });

  /// 回传模型的数据（JSON 可编码）。
  final Object? data;

  /// 卡片上的简短结果（界面语言，可空），如“找到 12 篇”。
  final String? summary;

  /// 要给用户的“前往”按钮。
  final AiToolNavigation? navigation;

  /// 撤销所需的数据（JSON 可编码，存进步骤记录），交回 [AiTool.undo]。写
  /// 工具必须给。
  final Map<String, Object?>? undo;

  /// 涉及的对象（查到的日记、改动的待办、筛选用的日记本……），界面据此写
  /// 出具体名称、列出可点的胶囊。写工具成功时必须给。
  final List<AiToolSubject> subjects;
}

/// 执行前确认面板的内容：一句标题与几行要点（界面语言）。
@immutable
class AiToolPreview {
  const AiToolPreview({required this.title, this.lines = const <String>[]});

  final String title;
  final List<String> lines;
}

/// 撤销时发现数据在那之后又被别处改过：界面先问用户要不要覆盖。
class AiUndoConflict implements Exception {
  const AiUndoConflict();
}

/// 工具需要界面帮忙的事（由对话页提供；后台或测试里可以为 null）。
abstract interface class AiToolUi {
  /// 加了带提醒的待办后确认系统允许发通知（与待办页同一口径：没允许时请求
  /// 一次，仍不允许时提示用户去系统设置，提醒本身照样保留）。
  Future<void> requestReminderPermission();
}

/// 一个“前往”按钮：目标页面（`AiDestination.id`）与参数。
@immutable
class AiToolNavigation {
  const AiToolNavigation({
    required this.destination,
    this.params = const <String, Object?>{},
    this.now = false,
  });

  final String destination;
  final Map<String, Object?> params;

  /// 用户明确要求“打开”：本轮结束后自动打开。
  final bool now;

  Map<String, Object?> toJson() => <String, Object?>{
    'destination': destination,
    if (params.isNotEmpty) 'params': params,
    if (now) 'now': true,
  };

  static AiToolNavigation? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final destination = raw['destination'];
    if (destination is! String || destination.isEmpty) return null;
    final params = raw['params'];
    return AiToolNavigation(
      destination: destination,
      params: params is Map
          ? params.cast<String, Object?>()
          : const <String, Object?>{},
      now: raw['now'] == true,
    );
  }
}

/// 日记编号：同一篇日记不论被哪个工具返回，都用同一个 `[Dn]`。
///
/// 智能体的编号在整段对话里连续：以前各轮原样回放，旧结果里的 [D3] 仍指
/// 同一篇，所以这一轮从以前用过的编号（[earlier]，见 `aiAgentCitationsOf`）
/// 接着编，再见到旧的日记沿用旧编号。
class AiCitationBook {
  AiCitationBook([Iterable<AiCitation> earlier = const <AiCitation>[]]) {
    for (final citation in earlier) {
      _byDiary.putIfAbsent(citation.diaryId, () => citation);
      final number = int.tryParse(citation.ref.substring(1)) ?? 0;
      if (number >= _next) _next = number + 1;
    }
    _earlier = _byDiary.length;
  }

  final Map<String, AiCitation> _byDiary = <String, AiCitation>{};

  /// 这一轮工具碰到过的日记（含沿用旧编号的）。
  final Set<String> _touched = <String>{};
  int _next = 1;
  int _earlier = 0;

  /// [diary] 的编号（第一次见到时分配下一个）。
  String refFor(
    String diaryId, {
    required String title,
    required DateTime date,
  }) {
    _touched.add(diaryId);
    final existing = _byDiary[diaryId];
    if (existing != null) return existing.ref;
    final ref = 'D${_next++}';
    _byDiary[diaryId] = AiCitation(
      ref: ref,
      diaryId: diaryId,
      title: title,
      date: date,
    );
    return ref;
  }

  /// 编号对应的日记 id（`D3`，也认 `[D3]`、`d3`）；不像编号或这段对话里
  /// 没分配过时为 null。以前各轮的编号也认：旧结果原样回放，模型会沿用。
  String? diaryIdOf(String ref) {
    final match = _refPattern.firstMatch(ref);
    if (match == null) return null;
    final key = 'D${int.parse(match.group(1)!)}';
    for (final citation in _byDiary.values) {
      if (citation.ref == key) return citation.diaryId;
    }
    return null;
  }

  static final RegExp _refPattern = RegExp(
    r'^\s*\[?\s*[Dd](\d{1,6})\s*\]?\s*$',
  );

  /// [args] 里 [keys] 这些参数的值中，编号换成日记 id，其余原样（认不出的
  /// 编号也原样留下，由工具照常报“找不到”）。
  Map<String, Object?> resolveDiaryArgs(
    Map<String, Object?> args,
    Set<String> keys,
  ) {
    if (keys.isEmpty) return args;
    Object? resolve(Object? value) => switch (value) {
      final String text => diaryIdOf(text) ?? text,
      final List<Object?> items => [for (final item in items) resolve(item)],
      _ => value,
    };
    return <String, Object?>{
      for (final MapEntry(:key, :value) in args.entries)
        key: keys.contains(key) ? resolve(value) : value,
    };
  }

  /// 全部编号（含以前各轮的），回答引用时按它找日记。
  List<AiCitation> get all => List<AiCitation>.unmodifiable(_byDiary.values);

  /// 这一轮新分配的编号（落库到回答的 `meta.refs`，下一轮接着编）。
  List<AiCitation> get fresh =>
      List<AiCitation>.unmodifiable(_byDiary.values.skip(_earlier));

  /// 这一轮工具碰到过的日记篇数（“参考了 N 篇”）。
  int get length => _touched.length;
}

/// 一轮之内还能发给模型多少日记文字（AI 隐私里的“最多发送”，`TextStats`
/// 口径）。工具把正文、摘录发出去之前从这里扣。
class AiWordAllowance {
  AiWordAllowance(this.budget);

  final int budget;
  int _used = 0;

  int get remaining => budget - _used > 0 ? budget - _used : 0;

  /// 想发 [words] 字，返回实际允许的字数（并记账）。
  int take(int words) {
    final granted = words < remaining ? words : remaining;
    _used += granted;
    return granted;
  }
}

/// 工具运行时能用的东西（一轮之内共用）。
class AiToolContext {
  AiToolContext({
    required this.container,
    required this.l10n,
    required this.kit,
    required this._env,
    required this.citations,
    required this.allowance,
    required this.token,
    this.ui,
    AiGuideCatalog? guide,
    DateTime? now,
  }) : _featuresAtStart = container.read(appFeaturesProvider),
       guide = guide ?? AiGuideCatalog.empty,
       now = now ?? DateTime.now();

  /// 使用指南（提示词语言的那一份）；没加载到时为空目录。
  final AiGuideCatalog guide;

  /// 界面能力（申请提醒权限等）；没有界面时为 null。
  final AiToolUi? ui;

  /// 应用的 provider 容器（读数据库、设置与各功能的 provider）。
  final ProviderContainer container;

  /// 界面语言（卡片上的说明）。
  final AppLocalizations l10n;

  /// 提示词语言与偏好（给模型的日记格式、隐私字段）。
  final AiPromptKit kit;

  final AiToolEnv _env;
  final AppFeatures _featuresAtStart;

  /// 这次运行的环境。功能开关在这一轮里被改过（`set_feature_enabled`）时
  /// 取最新值：同一轮里先打开功能再用它（打开它的页面、查询）要能用上，
  /// 否则模型会看到“已打开”却仍然报“功能已关闭”。
  AiToolEnv get env {
    final live = container.read(appFeaturesProvider);
    if (live == _featuresAtStart) return _env;
    return AiToolEnv(features: live, prefs: _env.prefs, vision: _env.vision);
  }

  final AiCitationBook citations;
  final AiWordAllowance allowance;
  final HttpCancelToken token;
  final DateTime now;

  AppDatabase get database => container.read(appDatabaseProvider);

  /// 现在的日记本树（直接读库：`notebookTreeProvider` 的流可能还没跟上
  /// 刚刚的改动，例如同一轮里先建本子再往里收日记）。
  Future<NotebookTree> notebookTree() async =>
      NotebookTree(await database.getNotebooks());

  AiPreferences get prefs => env.prefs;

  DateTime get today => DateTime(now.year, now.month, now.day);
}

/// 一篇日记作为涉及对象（标题为空时界面改用日期）。
AiToolSubject aiDiarySubject(Diary diary, {bool input = false}) =>
    AiToolSubject.diary(
      diary.diaryId,
      title: diary.title.trim(),
      date: diary.createdAt,
      input: input,
    );

/// 发给 AI 的日记（查询工具的结果）作为涉及对象。
AiToolSubject aiContextDiarySubject(AiContextDiary diary) =>
    AiToolSubject.diary(
      diary.diaryId,
      title: diary.title.trim(),
      date: diary.createdAt,
    );

/// 参数里的日记本（筛选条件）作为涉及对象；不存在时为 null。
Future<AiToolSubject?> aiNotebookParamSubject(
  AiToolContext context,
  Object? notebookId,
) async {
  if (notebookId is! String || notebookId.isEmpty) return null;
  final notebook = (await context.notebookTree())[notebookId];
  if (notebook == null) return null;
  return AiToolSubject.notebook(notebook.id, notebook.name, input: true);
}

/// 参数里的标签名（筛选条件）作为涉及对象。
List<AiToolSubject> aiTagParamSubjects(Object? names) => [
  if (names is List)
    for (final name in names)
      if (name is String && name.trim().isNotEmpty)
        AiToolSubject.tag(name.trim(), input: true),
];

/// 工具结果里的日期写法：`2026-11-08`。
String aiToolDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

/// 工具结果里的时间写法：`2026-11-08 21:05`。
String aiToolDateTime(DateTime value) =>
    '${aiToolDate(value)} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
