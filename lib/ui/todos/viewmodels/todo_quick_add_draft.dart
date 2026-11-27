import '../../../core/database/app_database.dart';
import 'todo_quick_parse.dart';

/// 快速新建面板手上的值：视图预填的、手动选的，以及哪些识别种类被点掉 /
/// 被手动值盖住了。生效的值一律“手动选的 > 识别出的 > 视图预填的”。
///
/// - 输入：每次按键的识别结果（由面板按 [ignore] 解析）；
/// - 输出：此刻生效的日期、时刻、清单、标签、优先级、重复与提醒，以及要写库的
///   [TodoInput]；
/// - 无副作用（不写库、不弹面板），面板负责交互，测试可直接驱动。
///
/// 日期手动选过后日期 / 时刻不再识别；提醒、重复手动改过后同样不再识别。
/// 加提醒 / 重复时把此刻生效的日期定下来（[adoptDue]）：之后再改标题里的
/// 日期词不能让它们悄悄换了参照。
class TodoQuickAddDraft {
  TodoQuickAddDraft({
    this.listId,
    this.dueDate,
    TodoPriority? priority,
    List<String> tags = const <String>[],
    this.sectionId,
  }) : priority = priority ?? TodoPriority.none,
       tags = TodoTags.normalizeAll(tags),
       _sectionListId = listId;

  String? listId;
  bool listPicked = false;
  DateTime? dueDate;
  int? dueMinute;
  bool duePicked = false;
  TodoPriority priority;
  bool priorityPicked = false;
  List<TodoReminder> reminders = const <TodoReminder>[];
  TodoRepeatRule? repeat;

  /// 视图预填与手动选的标签（与识别出的合在一起生效，见 [effTags]）。
  List<String> tags;

  /// 预填的分区（点分区标题上的“+”时）：只属于预填的清单，清单换了（手动
  /// 选或识别出别的）就不带。
  final String? sectionId;
  final String? _sectionListId;

  String? effSection(TodoQuickParse p) =>
      sectionId != null && effList(p) == _sectionListId ? sectionId : null;

  /// 点 × 去掉的识别种类（输入清空时复位）。
  final Set<TodoQuickTokenKind> ignored = <TodoQuickTokenKind>{};

  /// 单个点掉的识别标签（[TodoTags.keyOf] 键，输入清空时复位）。
  final Set<String> ignoredTags = <String>{};

  /// 输入清空、或添加了一条之后：点掉的识别种类与标签都复位。
  void resetIgnored() {
    ignored.clear();
    ignoredTags.clear();
  }

  /// 解析时要忽略的种类：点掉的，加上被手动值盖住的。
  Set<TodoQuickTokenKind> get ignore => <TodoQuickTokenKind>{
    ...ignored,
    if (duePicked) ...<TodoQuickTokenKind>{
      TodoQuickTokenKind.date,
      TodoQuickTokenKind.time,
    },
    if (listPicked) TodoQuickTokenKind.list,
    if (priorityPicked) TodoQuickTokenKind.priority,
  };

  DateTime? effDate(TodoQuickParse p) => p.date ?? dueDate;
  int? effMinute(TodoQuickParse p) => p.date != null ? p.minute : dueMinute;
  String? effList(TodoQuickParse p) => p.listId ?? listId;
  TodoPriority effPriority(TodoQuickParse p) => p.priority ?? priority;
  TodoRepeatRule? effRepeat(TodoQuickParse p) => repeat ?? p.repeatRule;

  /// 手上的标签在前，识别出的接在后面（同名只算一个）。
  List<String> effTags(TodoQuickParse p) =>
      TodoTags.normalizeAll(<String>[...tags, ...p.tags]);

  /// 在标签面板里选成了 [next]：识别出、但这次没留下的不再识别，留下的
  /// 成为手上的值（之后删掉标题里的 `@标签` 也还在）。
  void pickTags(List<String> next, TodoQuickParse p) {
    for (final tag in p.tags) {
      if (!TodoTags.contains(next, tag)) ignoredTags.add(TodoTags.keyOf(tag));
    }
    tags = TodoTags.normalizeAll(next);
  }

  /// 清除标签：手上的去掉，这一行也不再识别标签。
  void clearTags() {
    tags = const <String>[];
    ignored.add(TodoQuickTokenKind.tag);
  }

  List<TodoReminder> effReminders(TodoQuickParse p, int allDayMinute) {
    if (reminders.isNotEmpty) return reminders;
    if (effDate(p) == null) return const <TodoReminder>[];
    final parsed = p.reminder?.resolve(
      dueMinute: effMinute(p),
      allDayMinute: allDayMinute,
    );
    return parsed == null ? const <TodoReminder>[] : <TodoReminder>[parsed];
  }

  /// 一行输入 [raw]（识别结果 [p]）要写的待办；标题全被识别走时用原文，
  /// 原文也空时为 null。
  TodoInput? inputFor(
    String raw,
    TodoQuickParse p, {
    required int allDayMinute,
    String? linkedDiaryId,
  }) {
    final title = p.title.isNotEmpty ? p.title : raw.trim();
    if (title.isEmpty) return null;
    final date = effDate(p);
    return TodoInput(
      title: title,
      listId: effList(p),
      priority: effPriority(p),
      dueDate: date,
      dueMinute: date == null ? null : effMinute(p),
      reminders: date == null
          ? const <TodoReminder>[]
          : effReminders(p, allDayMinute),
      repeat: date == null ? null : effRepeat(p),
      linkedDiaryId: linkedDiaryId,
      tags: effTags(p),
      sectionId: effSection(p),
    );
  }

  /// 手动选了截止日 [date] / 时刻 [minute]（[date] 为 null 即去掉日期）。识别
  /// 出的提醒与重复先定下来成为手动值；去掉日期时它们一起失效；改成全天时
  /// 只对有时刻的待办有效的提醒随之去掉；有重复时起点挪到新日子。
  void pickDue(
    DateTime? date,
    int? minute,
    TodoQuickParse p, {
    required int allDayMinute,
  }) {
    reminders = effReminders(p, allDayMinute);
    repeat = effRepeat(p);
    ignored.addAll(<TodoQuickTokenKind>{
      TodoQuickTokenKind.repeat,
      TodoQuickTokenKind.reminder,
    });
    dueDate = date;
    dueMinute = minute;
    duePicked = true;
    if (date == null) {
      clearDue();
      return;
    }
    if (minute == null) {
      reminders = <TodoReminder>[
        for (final r in reminders)
          if (r.kind == TodoReminderKind.onDay) r,
      ];
    }
    final rule = repeat;
    if (rule != null) repeat = rule.copyWith(anchor: date);
  }

  /// 去掉日期：提醒与重复一起失效，识别出的日期、时刻、重复、提醒都不再要。
  void clearDue() {
    dueDate = null;
    dueMinute = null;
    duePicked = true;
    reminders = const <TodoReminder>[];
    repeat = null;
    ignored.addAll(<TodoQuickTokenKind>{
      TodoQuickTokenKind.date,
      TodoQuickTokenKind.time,
      TodoQuickTokenKind.repeat,
      TodoQuickTokenKind.reminder,
    });
  }

  /// 把此刻生效的日期定下来（没有时取 [fallback]），成为手动的值。
  void adoptDue(TodoQuickParse p, DateTime fallback) {
    final date = effDate(p);
    dueMinute = date == null ? null : effMinute(p);
    dueDate = date ?? fallback;
    duePicked = true;
  }

  /// 手动改了提醒（[fallbackDue] 为没有日期时定下的日子）。
  void setReminders(
    List<TodoReminder> next,
    TodoQuickParse p,
    DateTime fallbackDue,
  ) {
    reminders = next;
    ignored.add(TodoQuickTokenKind.reminder);
    if (next.isNotEmpty && !duePicked) adoptDue(p, fallbackDue);
  }

  /// 手动改了重复（[anchor] 为没有日期时定下的日子）。
  void setRepeat(TodoRepeatRule? rule, TodoQuickParse p, DateTime anchor) {
    repeat = rule;
    ignored.add(TodoQuickTokenKind.repeat);
    if (rule != null && !duePicked) adoptDue(p, anchor);
  }

  /// 自定义提醒选在截止时间之后：截止时间顺延过去，成为手动选的值。
  void moveDue(DateTime date, int? minute) {
    dueDate = date;
    dueMinute = minute;
    duePicked = true;
    final rule = repeat;
    if (rule != null) repeat = rule.copyWith(anchor: date);
  }
}
