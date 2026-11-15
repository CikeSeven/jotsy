// 快照构建读取的数据，全部经已有的查询（私密日记的排除口径与日历、首页
// 一致，见 docs/rules/notebooks.md）。抽成接口是为了让快照构建可以脱离
// 数据库单测（`test/ui/home_widgets/` 里的假数据源）。

import '../../../core/database/app_database.dart';
import '../../notebooks/viewmodels/notebook_tree.dart';

abstract class HomeWidgetDataSource {
  /// [day] 当天写下的字数（按 `TextStats` 口径，不含私密日记）。
  Future<int> wordsOn(DateTime day);

  /// 未完成待办的截止日（`YYYY-MM-DD`；没有截止日为 null）。
  Future<List<String?>> openTodoDueDates();

  /// 能写进去的日记本：普通（非智能）、非私密（含继承）、未合上的本子，
  /// id → 名字。快速记录的“写进日记本”只认这里面的。
  Future<Map<String, String>> writableNotebooks();
}

class DatabaseHomeWidgetDataSource implements HomeWidgetDataSource {
  DatabaseHomeWidgetDataSource(this._db);

  final AppDatabase _db;

  @override
  Future<int> wordsOn(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final markers = await _db
        .watchDiaryMarkersInRange(start, start.add(const Duration(days: 1)))
        .first;
    var words = 0;
    for (final marker in markers) {
      words += marker.wordCount;
    }
    return words;
  }

  @override
  Future<List<String?>> openTodoDueDates() async {
    final rows = await _db.getOpenTodos();
    return <String?>[for (final row in rows) row.dueDate];
  }

  @override
  Future<Map<String, String>> writableNotebooks() async {
    final rows = await _db.watchNotebooks().first;
    return <String, String>{
      for (final notebook in NotebookTree(rows).notebooks)
        if (notebook.isManual && !notebook.isPrivate && !notebook.isClosed)
          notebook.id: notebook.name,
    };
  }
}
