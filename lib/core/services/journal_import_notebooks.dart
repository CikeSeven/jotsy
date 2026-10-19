import '../database/app_database.dart';
import 'journal_import_models.dart';
import 'journal_import_payload.dart';

/// 日记本名称的长度上限（与 `notebooks.name` 的表约束一致）。
const int journalImportNotebookNameMaxLength = 60;

/// 导入载荷里的日记本一步：把条目上记下的来源日记本 / 文件夹名
/// （[JournalImportEntry.notebooks]）变成载荷中的日记本行与成员关系行。
///
/// 输入：本机现有日记本（由服务层读库后传入，本类不碰数据库）、来源。
/// 输出：[notebooks] 与 [memberships]，交给 BackupPayload；合并时由
/// BackupNotebookMerge 按 notebookId 并入本机。
///
/// 同一个名字落到哪一本，按顺序取：
/// 1. 本机已有确定性 id（[journalImportNotebookId]）的手动日记本——上次导入
///    建的那一本，用户改了名也认得出；
/// 2. 本机同名的手动日记本——用户先自建了同名本子，不该再多出一本重名的；
/// 3. 否则新建一本，id 用确定性 id，再次导入同一来源时回到第 1 条。
///
/// 复用本机日记本时，载荷里放的是本机那一行的原样拷贝（只换成载荷内的本地
/// id）：合并并覆盖会用载荷定义整行替换本机定义，若这里放一份新拼的默认
/// 定义，用户后来改的图标、颜色、封面与章节都会被重置；放原样拷贝则替换前后
/// 内容相同。智能日记本不接收成员关系，任何一步都不会选中它。
class JournalImportNotebookBuilder {
  JournalImportNotebookBuilder({
    required this.source,
    required List<NotebookRow> existing,
    required this.colors,
    required this.fallbackColor,
    required this.now,
  }) : _local = existing,
       _localIds = {for (final row in existing) row.notebookId: row};

  final JournalImportSource source;

  /// 新建日记本轮流使用的颜色；为空时一律用 [fallbackColor]。
  final List<int> colors;
  final int fallbackColor;

  /// 新建日记本的创建时间与成员关系的加入时间。
  final DateTime now;

  final List<NotebookRow> _local;
  final Map<String, NotebookRow> _localIds;

  /// 规整后的名称 → 载荷中的日记本行。
  final Map<String, NotebookRow> _byName = <String, NotebookRow>{};

  /// notebookId → 载荷中的日记本行：不同名称可能落到同一本本机日记本
  /// （例如上次导入建的本子被用户改成了另一个来源文件夹的名字），载荷里
  /// 同一 notebookId 只能出现一次。
  final Map<String, NotebookRow> _byNotebookId = <String, NotebookRow>{};

  final List<DiaryNotebookRow> _memberships = <DiaryNotebookRow>[];

  /// 每本已分到的成员数，即下一篇的成书位置（按解析顺序）。
  final Map<int, int> _counts = <int, int>{};
  var _newCount = 0;

  List<NotebookRow> get notebooks =>
      _byNotebookId.values.toList(growable: false);

  List<DiaryNotebookRow> get memberships =>
      List<DiaryNotebookRow>.unmodifiable(_memberships);

  /// 把载荷内本地 id 为 [diaryId] 的日记放进 [names] 对应的日记本；
  /// 规整后为空的名称跳过，同一篇在同一本里只记一次。
  void add(int diaryId, Iterable<String> names) {
    final seen = <int>{};
    for (final raw in names) {
      final name = normalizeJournalImportNotebookName(raw);
      if (name.isEmpty) continue;
      final notebook = _resolve(name);
      if (!seen.add(notebook.id)) continue;
      final position = _counts[notebook.id] ?? 0;
      _counts[notebook.id] = position + 1;
      _memberships.add(
        DiaryNotebookRow(
          diaryId: diaryId,
          notebookId: notebook.id,
          position: position,
          addedAt: now,
        ),
      );
    }
  }

  NotebookRow _resolve(String name) {
    final cached = _byName[name];
    if (cached != null) return cached;
    final local = _localMatch(name);
    final row =
        (local == null ? null : _byNotebookId[local.notebookId]) ??
        _register(local ?? _create(name));
    _byName[name] = row;
    return row;
  }

  /// 规则 1、2：本机可复用的手动日记本。
  NotebookRow? _localMatch(String name) {
    final byId = _localIds[journalImportNotebookId(source, name)];
    if (byId != null && byId.acceptsManualEntries) return byId;
    for (final row in _local) {
      if (row.acceptsManualEntries &&
          normalizeJournalImportNotebookName(row.name) == name) {
        return row;
      }
    }
    return null;
  }

  /// 以载荷内的本地 id（1..n）登记一行；本机行原样拷贝，只换 id。
  NotebookRow _register(NotebookRow row) {
    final registered = row.copyWith(id: _byNotebookId.length + 1);
    _byNotebookId[registered.notebookId] = registered;
    return registered;
  }

  /// 规则 3：新建。确定性 id 若已被本机一本非手动日记本占用（上次导入建的
  /// 本子被转成了智能日记本），沿用它会让合并并覆盖把那本智能日记本改回
  /// 手动，因此依次加序号另取，序号也是确定的，再次导入仍落在同一本。
  NotebookRow _create(String name) {
    var notebookId = journalImportNotebookId(source, name);
    for (var n = 2; _localIds.containsKey(notebookId); n++) {
      notebookId = journalImportNotebookId(source, '$name\u0000$n');
    }
    final color = colors.isEmpty
        ? fallbackColor
        : colors[_newCount % colors.length];
    _newCount++;
    return NotebookRow(
      id: 0,
      notebookId: notebookId,
      name: name,
      kind: NotebookKind.manual.name,
      visibility: NotebookVisibility.normal.name,
      payload: NotebookPayload(icon: 'book', color: color).encode(),
      sortOrder: 0,
      isPinned: false,
      isClosed: false,
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// 日记本名称规整：连续空白合成一个空格、去首尾空白、截到
/// [journalImportNotebookNameMaxLength]（按 UTF-16 长度，不拆代理对）。
String normalizeJournalImportNotebookName(String raw) {
  final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= journalImportNotebookNameMaxLength) return text;
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (buffer.length + char.length > journalImportNotebookNameMaxLength) {
      break;
    }
    buffer.write(char);
  }
  // 截断处可能正好留下空格。
  return buffer.toString().trimRight();
}

/// 条目里出现的来源日记本 / 文件夹个数，按 [normalizeJournalImportNotebookName]
/// 规整后去重，空名不计。
int journalImportFolderCount(Iterable<JournalImportEntry> entries) => {
  for (final entry in entries)
    for (final raw in entry.notebooks)
      if (normalizeJournalImportNotebookName(raw) case final name
          when name.isNotEmpty)
        name,
}.length;
