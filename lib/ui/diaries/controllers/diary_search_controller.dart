import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/database/app_database.dart';
import '../models/diary_search_filters.dart';
import '../providers/diary_filters.dart';

/// 关键词输入的防抖（非动画计时）：搜索页与日记本“添加日记”页共用。
const Duration diarySearchDebounce = Duration(milliseconds: 200);

/// 搜索页的一次搜索会话：关键词、标签、日记本范围、筛选与结果分页窗口。
///
/// 职责边界：
/// - 输入：输入框文字（[onInputChanged] / [applyKeyword] / [clearKeyword]）、
///   条件增删（标签、范围、筛选）、滚动触底（[requestLoadMore]）；
/// - 输出：[pageQuery] 给出当前要订阅的查询，[acceptPage] 记下结果；
/// - 副作用：只有自身状态与 [notifyListeners]，不读写数据库、不碰路由。
///
/// 与首页 `diaryFilterProvider` 完全解耦：在搜索页里增删条件不影响首页。
///
/// 计时器：
/// - 防抖 [diarySearchDebounce]：每次输入重新计时，到期才把输入变成生效的
///   关键词（查询 key）；清空、点最近搜索时直接生效并取消计时；
/// - 分页冷却 140ms：连续触底时不重复加页，只是节流标志，到期不重建；
/// - 两者都在 [dispose] 时取消，回调里先判断是否已释放。
class DiarySearchController extends ChangeNotifier {
  DiarySearchController({
    String initialKeyword = '',
    Set<int> initialTagIds = const <int>{},
    this._scope = DiaryListScope.all,
  }) : _tagIds = <int>{...initialTagIds},
       _keyword = initialKeyword.trim(),
       _input = initialKeyword.trim() {
    text.text = _input;
  }

  static const int pageSize = 20;
  static const Duration _pagingCooldown = Duration(milliseconds: 140);

  /// 输入框的文字；由页面挂到输入框上，随会话一起释放。
  final TextEditingController text = TextEditingController();

  Timer? _debounce;
  Timer? _cooldownTimer;
  bool _disposed = false;

  String _input;
  String _keyword;
  final Set<int> _tagIds;
  DiaryListScope _scope;
  DiarySearchFilters _filters = DiarySearchFilters.none;

  int _visibleLimit = pageSize;
  bool _hasMore = false;
  bool _cooldown = false;
  DiaryPageQuery? _pagingKey;
  List<DiaryWithTags> _cachedItems = const <DiaryWithTags>[];
  DiaryPageQuery? _cachedQuery;
  int? _cachedCount;

  /// 输入框里当前的文字（未经防抖）。
  String get input => _input;

  /// 生效的关键词（防抖之后，已去掉首尾空白）。
  String get keyword => _keyword;

  /// 生效关键词拆出的词，查询与高亮共用（[splitSearchTerms]）。
  List<String> get terms => splitSearchTerms(_keyword);

  Set<int> get tagIds => Set<int>.unmodifiable(_tagIds);
  DiaryListScope get scope => _scope;
  DiarySearchFilters get filters => _filters;

  /// 有没有可搜的条件：关键词、标签或筛选规则。“含归档”与日记本范围只是
  /// 限定，单独存在时仍显示空状态（不把整本 / 全部日记列出来）。
  bool get hasAnyCondition =>
      _keyword.isNotEmpty || _tagIds.isNotEmpty || _filters.rules.isNotEmpty;

  bool get hasMore => _hasMore;

  /// 最近一次拿到的结果；新查询加载中时列表继续显示它，避免闪白。
  List<DiaryWithTags> get cachedItems => _cachedItems;

  /// [cachedItems] 对应的查询：预览页接续加载必须用结果自己的条件。
  DiaryPageQuery? get cachedQuery => _cachedQuery;

  /// 最近一次拿到的结果数；新计数到来前继续显示它。
  int? get cachedCount => _cachedCount;

  void onInputChanged(String value) {
    if (_input != value) {
      _input = value;
      notifyListeners();
    }
    _debounce?.cancel();
    _debounce = Timer(diarySearchDebounce, () {
      if (_disposed) return;
      _setKeyword(value);
    });
  }

  /// 立即以 [value] 搜索（点最近搜索）：同步输入框并把光标放到末尾。
  void applyKeyword(String value) {
    _debounce?.cancel();
    text.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _input = value;
    if (!_setKeyword(value)) {
      notifyListeners();
    }
  }

  void clearKeyword() {
    _debounce?.cancel();
    text.clear();
    _input = '';
    if (!_setKeyword('')) {
      notifyListeners();
    }
  }

  /// 防抖还没到期时立即生效（键盘“搜索”键）。
  void commitInput() {
    _debounce?.cancel();
    _setKeyword(_input);
  }

  bool _setKeyword(String value) {
    final normalized = value.trim();
    if (normalized == _keyword) return false;
    _keyword = normalized;
    notifyListeners();
    return true;
  }

  void addTag(int tagId) {
    if (_tagIds.add(tagId)) notifyListeners();
  }

  void removeTag(int tagId) {
    if (_tagIds.remove(tagId)) notifyListeners();
  }

  /// 标签面板里勾选的整组标签；空集即清除全部标签条件。
  void setTags(Set<int> tagIds) {
    if (tagIds.length == _tagIds.length && _tagIds.containsAll(tagIds)) {
      return;
    }
    _tagIds
      ..clear()
      ..addAll(tagIds);
    notifyListeners();
  }

  /// 移除日记本条件：改为在全部日记中搜索（不影响首页所在的范围）。
  void removeScope() {
    if (_scope == DiaryListScope.all) return;
    _scope = DiaryListScope.all;
    notifyListeners();
  }

  void setFilter(DiarySearchFilterSlot slot, NotebookRule? rule) {
    _setFilters(_filters.withSlot(slot, rule));
  }

  void setIncludeArchived(bool value) {
    _setFilters(_filters.withIncludeArchived(value));
  }

  /// 清除全部筛选（含“含归档”）；关键词、标签与范围保留。
  void clearFilters() => _setFilters(DiarySearchFilters.none);

  void _setFilters(DiarySearchFilters next) {
    if (next == _filters) return;
    _filters = next;
    notifyListeners();
  }

  /// 当前条件下要订阅的分页查询。条件（含排序）一变，分页窗口回到第一页；
  /// 在 build 里调用，只改内部状态、不通知（与改版前的同步方式一致）。
  ///
  /// 筛选谓词按当天编译：同一天里重复调用得到相等的谓词，查询 key 不变。
  DiaryPageQuery pageQuery({
    required DiarySortMode sortMode,
    required bool matchComments,
  }) {
    // 先按窗口 0 得到不随翻页变化的 key，比较后再定窗口大小。
    final key = DiaryPageQuery(
      keyword: _keyword,
      requiredTagIds: _tagIds.toList(growable: false)..sort(),
      limit: 0,
      sortMode: sortMode,
      scope: _scope,
      matchComments: matchComments,
      includeArchived: _filters.includeArchived,
      filter: _filters.predicate(),
    );
    if (_pagingKey != key) {
      _pagingKey = key;
      _visibleLimit = pageSize;
      _hasMore = false;
      _cooldown = false;
      _cooldownTimer?.cancel();
      _cooldownTimer = null;
    }
    if (!hasAnyCondition) {
      _hasMore = false;
      _cachedItems = const <DiaryWithTags>[];
      _cachedQuery = null;
      _cachedCount = null;
    }
    return DiaryPageQuery(
      keyword: key.keyword,
      requiredTagIds: key.requiredTagIds,
      limit: _visibleLimit,
      sortMode: key.sortMode,
      scope: key.scope,
      matchComments: key.matchComments,
      includeArchived: key.includeArchived,
      filter: key.filter,
    );
  }

  /// 记下一页结果（在 build 里调用，不通知）。
  void acceptPage(PagedDiariesResult page, DiaryPageQuery query) {
    _cachedItems = page.items;
    _cachedQuery = query;
    _hasMore = page.hasMore;
  }

  /// 记下结果数（在 build 里调用，不通知）。
  void acceptCount(int count) {
    _cachedCount = count;
  }

  /// 滚动接近底部时追加一页（+[pageSize]），短冷却避免高频滚动连跳多页。
  void requestLoadMore() {
    if (_cooldown || !_hasMore) return;
    _visibleLimit += pageSize;
    _cooldown = true;
    notifyListeners();
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(_pagingCooldown, () {
      _cooldown = false;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _cooldownTimer?.cancel();
    text.dispose();
    super.dispose();
  }
}
