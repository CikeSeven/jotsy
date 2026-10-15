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
List<JournalImportEntry>? _parseCsv(String text) {
  final rows = parseCsvRows(text);
  if (rows.isEmpty) return null;
  final header = {
    for (final (index, name) in rows.first.indexed)
      name.trim().toLowerCase(): index,
  };
  final hasDate =
      header.containsKey('full_date') ||
      (header.containsKey('year') && header.containsKey('date'));
  if (!hasDate ||
      !header.containsKey('time') ||
      !header.containsKey('mood') ||
      !header.containsKey('note')) {
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
      final index = header[name];
      return index == null || index >= row.length ? '' : row[index].trim();
    }

    final date =
        DateTime.tryParse(cell('full_date')) ??
        _yearAndDay(cell('year'), cell('date'));
    if (date == null) continue;
    final (hour, minute) = _clock(cell('time'));
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
    final writer = JournalDeltaWriter();
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
  return entries;
}

/// 旧版 CSV 的 `year` + `date`（如 `January 23` 或 `23 January`）。
DateTime? _yearAndDay(String year, String date) {
  final y = int.tryParse(year);
  if (y == null) return null;
  final day = RegExp(r'\d{1,2}').firstMatch(date);
  final month = journalEnglishMonth(date);
  if (day == null || month == null) return null;
  return DateTime(y, month, int.parse(day.group(0)!));
}

/// `10:00 pm`、`22:00`、`下午10:00` → (时, 分)；无法识别时为 0 点。
(int, int) _clock(String raw) {
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
  if (match == null) return (0, 0);
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
  if (pm && hour < 12) hour += 12;
  if (am && hour == 12) hour = 0;
  return (hour.clamp(0, 23), minute.clamp(0, 59));
}
