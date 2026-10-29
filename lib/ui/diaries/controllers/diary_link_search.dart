import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/pinyin/name_index.dart';
import '../../../core/services/app_service.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/viewmodels/notebook_tree.dart';
import '../models/diary_link_candidate.dart';
import '../models/time_capsule.dart';
import '../viewmodels/diary_card_view_data.dart';
import '../viewmodels/diary_link_label.dart';

/// 按检索词找能链接的日记与日记本（`@` 菜单与链接对话框共用）。
typedef DiaryLinkSearch =
    Future<List<DiaryLinkCandidate>> Function(
      String query,
      Set<DiaryLinkKind> kinds,
    );

/// 找日记本要用的书架（带层级）；不找日记本时为 null。书架列表已加载
/// （首页一直订阅着）时直接用，否则查一次库——不去读 [notebooksProvider]
/// 的 future：没有监听者的 provider 在 Riverpod 3 里会被暂停，等不到推送。
Future<NotebookTree?> readDiaryLinkNotebookTree(
  WidgetRef ref,
  Set<DiaryLinkKind> kinds,
) async {
  if (!kinds.contains(DiaryLinkKind.notebook)) return null;
  final loaded = ref.read(notebookTreeProvider);
  if (loaded != null) return loaded;
  return NotebookTree(await ref.read(appDatabaseProvider).getNotebooks());
}

/// 空检索词时列出的条数（最近更新的日记、书架前几本）与有检索词时的上限。
const int _recentDiaryCount = 5;
const int _recentNotebookCount = 3;
const int _matchedDiaryCount = 8;
const int _matchedNotebookCount = 5;

/// 候选的口径：
/// - 日记本：书架上的全部本子（按树序），名称包含检索词或拼音匹配
///   （[NameIndexKey]）。隐藏、上锁的本子同样列出——书架上本就看得见它们，
///   打开时照常验证；
/// - 日记：与首页搜索同一查询（[AppDatabase.watchDiaries]，按更新时间），
///   天然排除回收站、归档与私密日记，未解封的胶囊只按标题匹配；正在编辑的
///   那篇（[excludeDiaryId]）不列出。
/// 日记本排在日记前面（数量少、名字短，一眼可选）。
Future<List<DiaryLinkCandidate>> searchDiaryLinkCandidates({
  required AppDatabase db,
  required NotebookTree? tree,
  required AppLocalizations l10n,
  required String query,
  required Set<DiaryLinkKind> kinds,
  String? excludeDiaryId,
  DateTime? now,
}) async {
  final text = query.trim();
  final clock = now ?? DateTime.now();
  final results = <DiaryLinkCandidate>[];
  if (kinds.contains(DiaryLinkKind.notebook) && tree != null) {
    final key = normalizeNameQuery(text);
    results.addAll(
      tree.depthFirst
          .where((notebook) => NameIndexKey.of(notebook.name).matches(key))
          .take(text.isEmpty ? _recentNotebookCount : _matchedNotebookCount)
          .map(DiaryLinkCandidate.notebook),
    );
  }
  if (kinds.contains(DiaryLinkKind.diary)) {
    final limit = text.isEmpty ? _recentDiaryCount : _matchedDiaryCount;
    final rows = await db.watchDiaries(keyword: text, limit: limit + 1).first;
    results.addAll(
      rows
          .where((row) => row.diary.diaryId != excludeDiaryId)
          .take(limit)
          .map((row) => _diaryCandidate(l10n, row.diary, clock)),
    );
  }
  return results;
}

DiaryLinkCandidate _diaryCandidate(
  AppLocalizations l10n,
  Diary diary,
  DateTime now,
) {
  final sealed = TimeCapsuleState.fromFields(
    lockedAt: diary.capsuleLockedAt,
    unlockAt: diary.capsuleUnlockAt,
    now: now,
  ).isLocked;
  return DiaryLinkCandidate.diary(
    target: DiaryLinkTarget.diary(diary.diaryId),
    label: diaryLinkLabel(l10n, diary, now: now),
    createdAt: diary.createdAt,
    cover: sealed ? null : DiaryCardViewData.of(diary).previewCover,
    sealed: sealed,
  );
}

/// 检索词 → 候选的防抖查询（`@` 菜单与链接对话框各持有一个）。
///
/// 时序：[update] 记下检索词，空词立即查、其余停手 [debounce] 后再查；
/// 查询期间检索词又变了，旧结果到达时丢弃（只认最后一次）。[results] 为
/// null 表示首次结果还没回来；之后换词期间保留上一份结果，列表不闪空。
/// [dispose] 取消计时器，晚到的结果不再通知。
class DiaryLinkSearchController extends ChangeNotifier {
  DiaryLinkSearchController(this._search, {required this.kinds});

  final DiaryLinkSearch _search;

  /// 本次查找的种类（卡片模式只找一种）。
  Set<DiaryLinkKind> kinds;

  /// 停手多久再查；非动画计时。
  static const Duration debounce = Duration(milliseconds: 150);

  String _query = '';
  int _generation = 0;
  Timer? _timer;
  List<DiaryLinkCandidate>? _results;
  bool _disposed = false;

  String get query => _query;
  List<DiaryLinkCandidate>? get results => _results;

  void update(String query, {bool force = false}) {
    if (!force && query == _query && _results != null) return;
    _query = query;
    final generation = ++_generation;
    _timer?.cancel();
    _timer = Timer(query.trim().isEmpty ? Duration.zero : debounce, () async {
      final List<DiaryLinkCandidate> found;
      try {
        found = await _search(query, kinds);
      } on Object catch (error, stack) {
        // 查询失败（数据库已关闭等）按没有结果处理，菜单照常可关。
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack),
        );
        if (_disposed || generation != _generation) return;
        _results = const [];
        notifyListeners();
        return;
      }
      if (_disposed || generation != _generation) return;
      _results = found;
      notifyListeners();
    });
  }

  /// 清掉结果与计时器（会话结束时），下次 [update] 从加载中开始。
  void reset() {
    _timer?.cancel();
    _generation++;
    _query = '';
    _results = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
