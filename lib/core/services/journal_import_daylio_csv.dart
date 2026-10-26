part of 'journal_import_daylio.dart';

/// Daylio CSV 导出（「导出条目」→ CSV）的解析，见 [parseDaylioExport]。

const Map<String, int> _defaultMoodLevels = {
  'rad': 5,
  'good': 4,
  'meh': 3,
  'bad': 2,
  'awful': 1,
};

/// 解析 CSV 导出；表头不像 Daylio 时返回 null。
JournalImportParseResult? _parseCsv(String text) {
  List<List<String>>? rows;
  Map<String, int>? header;
  // 系统区域设置会让 CSV 使用分号或 Tab；按实际表头识别，不能只根据
  // 正文中逗号的多少猜分隔符。未闭合引号会吞掉后续条目，必须整次拒绝。
  for (final delimiter in [',', ';', '\t']) {
    final candidate = parseCsvRows(text, delimiter: delimiter);
    if (candidate.isEmpty) continue;
    final columns = {
      for (final (index, name) in candidate.first.indexed)
        name.trim().toLowerCase(): index,
    };
    if (!columns.containsKey('note') ||
        !columns.containsKey('time') ||
        !columns.containsKey('mood')) {
      continue;
    }
    try {
      rows = parseCsvRows(text, delimiter: delimiter, strict: true);
    } on FormatException {
      throw const JournalImportFormatException(JournalImportSource.daylio);
    }
    header = columns;
    break;
  }
  if (rows == null || header == null) return null;
  if (rows.isEmpty) return null;
  final columns = header;
  final issues = JournalImportIssues();
  final hasDate =
      columns.containsKey('full_date') ||
      (columns.containsKey('year') && columns.containsKey('date'));
  if (!hasDate ||
      !columns.containsKey('time') ||
      !columns.containsKey('mood') ||
      !columns.containsKey('note')) {
    return null;
  }

  final parsed =
      <
        ({
          DateTime createdAt,
          String note,
          String title,
          String activities,
          String mood,
        })
      >[];
  for (final row in rows.skip(1)) {
    if (row.every((cell) => cell.trim().isEmpty)) continue;
    String cell(String name) {
      final index = columns[name];
      return index == null || index >= row.length ? '' : row[index].trim();
    }

    final date =
        parseJournalDateTime(cell('full_date')) ??
        _yearAndDay(cell('year'), cell('date'));
    final clock = _clock(cell('time'));
    if (date == null || clock == null) {
      issues.skip(JournalSkipReason.unreadable);
      continue;
    }
    final (hour, minute) = clock;
    parsed.add((
      createdAt: DateTime(date.year, date.month, date.day, hour, minute),
      note: cell('note'),
      title: cell('note_title'),
      activities: cell('activities'),
      mood: cell('mood').toLowerCase(),
    ));
  }
  parsed.sort(
    (a, b) => a.createdAt.compareTo(b.createdAt) != 0
        ? a.createdAt.compareTo(b.createdAt)
        : a.note.compareTo(b.note),
  );

  final keys = JournalKeyRegistry();
  final entries = <JournalImportEntry>[];
  for (final item in parsed) {
    final writer = JournalBlockWriter();
    _appendNote(writer, item.note);
    final content = writer.build();
    entries.add(
      JournalImportEntry(
        sourceKey: keys.unique(journalWallClockKey(item.createdAt)),
        title: item.title,
        contentJson: content.contentJson,
        contentText: content.contentText,
        createdAt: item.createdAt,
        tags: item.activities
            .split('|')
            .map((activity) => activity.trim())
            .where((activity) => activity.isNotEmpty)
            .toList(growable: false),
        moodLevel: _defaultMoodLevels[item.mood],
      ),
    );
  }
  return JournalImportParseResult(
    entries: entries,
    skippedNotes: issues.skipped,
  );
}

/// 旧版 CSV 的 `year` + `date`（如 `January 23` 或 `23 January`）。
DateTime? _yearAndDay(String year, String date) {
  final y = int.tryParse(year);
  if (y == null) return null;
  final day = RegExp(r'\d{1,2}').firstMatch(date);
  final month = journalEnglishMonth(date);
  if (day == null || month == null) return null;
  final d = int.parse(day.group(0)!);
  return isJournalCalendarDate(y, month, d) ? DateTime(y, month, d) : null;
}

/// `10:00 pm`、`22:00`、`下午10:00` → (时, 分)。空值视为无指定时间；
/// 非空的非法时间返回 null，不能用 0 点或 clamp 掩盖解析错误。
(int, int)? _clock(String raw) {
  if (raw.trim().isEmpty) return (0, 0);
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final lower = raw.toLowerCase();
  final pm =
      lower.contains('pm') ||
      lower.contains('p.m') ||
      raw.contains('下午') ||
      raw.contains('晚上');
  final am =
      lower.contains('am') ||
      lower.contains('a.m') ||
      raw.contains('上午') ||
      raw.contains('凌晨') ||
      raw.contains('早上');
  if (minute > 59 || hour > 23 || ((am || pm) && (hour < 1 || hour > 12))) {
    return null;
  }
  if (pm && hour < 12) hour += 12;
  if (am && hour == 12) hour = 0;
  return (hour, minute);
}
