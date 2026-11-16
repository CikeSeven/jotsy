import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/foundation.dart';

import '../models/diary_find_query.dart';
import 'diary_editor_controller.dart';
import 'diary_find_replace_writes.dart';
import 'diary_toggle_state.dart';

/// 正文的查找与替换会话（编辑页与预览页悬浮在底部的查找栏驱动它，
/// `DiaryEditor` 据它标出高亮、滚到当前匹配）。挂在
/// [DiaryEditorController.find]，随编辑会话释放；只读正文（预览页）同样
/// 能查找，只是不能替换。
///
/// 输入：查找条件（[setText] / [setOptions]）与替换文字（[replacement]）。
/// 输出：匹配列表、当前第几处（[matches] / [currentIndex]）、查找的模式
/// （[pattern]，高亮用）与“滚到当前匹配”的请求（[revealRequests]）。副作用：替换写正文（每次一步
/// 撤销），跳到收起的折叠块里的匹配时展开它（编辑态不进撤销栈，只读时只
/// 改本地显示状态）。
///
/// 时序：
/// - 输入查找文字经 [kDiaryFindDebounce] 防抖再查找（长日记里每敲一个字都
///   扫一遍全文太浪费），清空与改开关立即生效；
/// - 打开期间订阅正文事务：用户在正文里改了字（打字、撤销、粘贴）同样防抖
///   后重新查找，当前匹配停在原来那一处附近，不滚动——不把用户正在写的
///   地方拉走；本会话自己的替换与展开同步重新查找，不走防抖；
/// - 下一个 / 上一个 / 替换前先把还在防抖中的查找做完，按最新的文档操作。
///
/// 当前匹配的定位：记一个锚点（阅读顺序里的位置），每次查找取锚点处或之后
/// 的第一处，之后没有了就回到第一处。打开时锚点是正文的插入点（从光标处
/// 往下找），跳转后是当前匹配的开头，替换后是替换文字的末尾（不会再匹配
/// 刚换进去的字）。
class DiaryFindReplace extends ChangeNotifier {
  DiaryFindReplace(this._editor);

  final DiaryEditorController _editor;
  af.EditorState get _state => _editor.state;

  bool _open = false;
  DiaryFindQuery _query = const DiaryFindQuery();
  RegExp? _pattern;

  /// [_pattern] 是按哪个查找条件编译的（写错的正则同样记下，不反复编译）。
  DiaryFindQuery? _patternQuery;
  bool _invalid = false;
  List<DiaryFindMatch> _matches = const [];
  bool _truncated = false;
  int _current = -1;
  af.Position? _anchor;
  Timer? _debounce;
  StreamSubscription<af.EditorTransactionValue>? _transactions;

  /// 正在应用本会话自己的事务（替换、展开折叠块）：事务监听跳过，由调用
  /// 方同步重新查找。
  bool _applying = false;
  bool _disposed = false;

  /// 替换为的文字（查找栏关掉再打开时还在）；改它不通知。
  String replacement = '';

  /// 查找栏的替换一行是否展开（同样跨开关保留）。
  bool _replaceVisible = false;

  /// 每次需要把当前匹配滚进视野时加一（`DiaryFindRevealer` 监听）。
  final ValueNotifier<int> revealRequests = ValueNotifier<int>(0);

  /// 查找栏此刻盖住正文底部的高度（查找栏自己量好写入，关着时为 0）：
  /// 页面据此给正文末尾留白，`DiaryFindRevealer` 据此把当前匹配停在查找栏
  /// 上方。
  final ValueNotifier<double> barHeight = ValueNotifier<double>(0);

  bool get isOpen => _open;
  DiaryFindQuery get query => _query;

  /// 正在查找的模式（高亮按它就地匹配，见 `DiaryFindHighlightScope`）；查找
  /// 文字为空、正则写错或查找关着时为 null。查找条件不变时一直是同一个
  /// 对象：正文改字后的重新查找不让整篇的高亮跟着重建。
  RegExp? get pattern => _open ? _pattern : null;

  /// 正则写错（查找文字非空、开着正则、编译不过）。
  bool get invalid => _invalid;
  List<DiaryFindMatch> get matches => _matches;

  /// 匹配超过 [kDiaryFindMaxMatches] 处，只列出了前这么多。
  bool get truncated => _truncated;

  /// 当前匹配的下标；没有匹配时为 -1。
  int get currentIndex => _current;
  DiaryFindMatch? get current =>
      _current >= 0 && _current < _matches.length ? _matches[_current] : null;
  bool get replaceVisible => _replaceVisible;

  /// 打开查找；已开着时只更新传入的部分。[text] 非空时换成它（选中一段
  /// 文字后打开时带进来），[query] 整个换掉查找条件（从搜索结果打开日记
  /// 时带进搜索词），[replace] 为 true 时展开替换一行。
  ///
  /// 从插入点（只读正文为选区的开头）往下找；没有插入点或 [fromStart] 时
  /// 从开头找。
  void open({
    String? text,
    DiaryFindQuery? query,
    bool replace = false,
    bool fromStart = false,
  }) {
    if (!_open) {
      _open = true;
      _anchor = fromStart ? null : _editor.selection?.normalized.start;
      _transactions = _state.transactionStream.listen(_onTransaction);
    }
    if (replace) _replaceVisible = true;
    if (query != null) {
      _query = query;
    } else if (text != null && text.isNotEmpty) {
      _query = _query.copyWith(text: text);
    }
    _search(reveal: true);
    notifyListeners();
  }

  /// 关闭查找：清掉高亮与匹配，查找条件与替换文字留着下次用。
  void close() {
    if (!_open) return;
    _open = false;
    _debounce?.cancel();
    unawaited(_transactions?.cancel());
    _transactions = null;
    _matches = const [];
    _current = -1;
    _invalid = false;
    _truncated = false;
    _pattern = null;
    _patternQuery = null;
    barHeight.value = 0;
    notifyListeners();
  }

  void setReplaceVisible(bool visible) {
    if (visible == _replaceVisible) return;
    _replaceVisible = visible;
    notifyListeners();
  }

  /// 查找文字变了：清空时立即生效，否则防抖后查找并滚到第一处。
  void setText(String text) {
    if (text == _query.text) return;
    _query = _query.copyWith(text: text);
    _debounce?.cancel();
    if (text.isEmpty || !_open) {
      _search(reveal: false);
      notifyListeners();
      return;
    }
    _debounce = Timer(kDiaryFindDebounce, () {
      if (_disposed || !_open) return;
      _search(reveal: true);
      notifyListeners();
    });
  }

  /// 切换正则 / 区分大小写 / 整词，立即重新查找。
  void setOptions({bool? regex, bool? caseSensitive, bool? wholeWord}) {
    final next = _query.copyWith(
      regex: regex,
      caseSensitive: caseSensitive,
      wholeWord: wholeWord,
    );
    if (next == _query) return;
    _query = next;
    _search(reveal: true);
    notifyListeners();
  }

  void next() => _step(1);
  void previous() => _step(-1);

  void _step(int delta) {
    _flushPending();
    if (_matches.isEmpty) return;
    final length = _matches.length;
    _current = _current < 0
        ? (delta > 0 ? 0 : length - 1)
        : (_current + delta + length) % length;
    final match = _matches[_current];
    _anchor = af.Position(path: match.path, offset: match.start);
    _revealCurrent();
    notifyListeners();
  }

  /// 把当前匹配换成 [replacement]（正则时展开分组引用），一步撤销；之后
  /// 停在下一处。没有当前匹配或正文只读时返回 false。
  bool replaceCurrent() {
    if (!_open || _editor.readOnly) return false;
    _flushPending();
    final match = current;
    if (match == null) return false;
    final value = _valueFor(match);
    final transaction = _state.transaction;
    addDiaryFindReplacement(transaction, match, value);
    _applyOwn(transaction);
    _anchor = af.Position(path: match.path, offset: match.start + value.length);
    // 零宽匹配换成空串什么也没改：往后挪一处，不然一直停在原地。
    _search(reveal: true, strictlyAfter: match.isEmpty && value.isEmpty);
    notifyListeners();
    return true;
  }

  /// 把全部匹配一次换掉（不受 [kDiaryFindMaxMatches] 限制），整次一步
  /// 撤销；返回换掉了几处。
  int replaceAll() {
    if (!_open || _editor.readOnly) return 0;
    _flushPending();
    final pattern = _pattern;
    if (pattern == null) return 0;
    final all = findDiaryMatches(_state.document.root, pattern, limit: null);
    if (all.matches.isEmpty) return 0;
    final transaction = _state.transaction;
    addDiaryFindReplacements(transaction, all.matches, _valueFor);
    _applyOwn(transaction);
    _search(reveal: false);
    notifyListeners();
    return all.matches.length;
  }

  String _valueFor(DiaryFindMatch match) => _query.regex
      ? expandDiaryReplacement(replacement, match.match)
      : replacement;

  /// 应用本会话的改写：不动正文选区（查找框有焦点时正文没有选区，正文
  /// 有焦点时也不把光标拽到替换处），改短的文字里留着的旧选区随后夹回
  /// 文字长度之内。
  void _applyOwn(af.Transaction transaction) {
    _applying = true;
    try {
      _editor.apply(transaction, updateSelection: false);
    } finally {
      _applying = false;
    }
    _editor.clampSelectionToDocument();
  }

  void _onTransaction(af.EditorTransactionValue event) {
    if (event.$1 != af.TransactionTime.after ||
        event.$2.operations.isEmpty ||
        _applying ||
        _query.isEmpty) {
      return;
    }
    // 用户在正文里改了字：当前匹配停在原来那一处附近，不滚动。
    final match = current;
    if (match != null) {
      _anchor = af.Position(path: match.path, offset: match.start);
    }
    _debounce?.cancel();
    _debounce = Timer(kDiaryFindDebounce, () {
      if (_disposed || !_open) return;
      _search(reveal: false);
      notifyListeners();
    });
  }

  /// 还在防抖中的查找（输入查找文字或正文改动之后）立即做完。
  void _flushPending() {
    if (_debounce?.isActive != true) return;
    _debounce!.cancel();
    _search(reveal: false);
  }

  void _search({required bool reveal, bool strictlyAfter = false}) {
    _debounce?.cancel();
    RegExp? pattern;
    if (_open && _query == _patternQuery) {
      // 查找条件没变（正文改字后的重新查找）：沿用同一个正则对象，高亮
      // 按对象判断模式变没变（见 DiaryFindHighlightScope）。
      pattern = _pattern;
    } else {
      try {
        pattern = _open ? compileDiaryFindPattern(_query) : null;
        _invalid = false;
      } on FormatException {
        pattern = null;
        _invalid = true;
      }
      _patternQuery = _open ? _query : null;
    }
    _pattern = pattern;
    if (pattern == null) {
      _matches = const [];
      _truncated = false;
      _current = -1;
      return;
    }
    final found = findDiaryMatches(_state.document.root, pattern);
    _matches = found.matches;
    _truncated = found.truncated;
    _current = _indexFromAnchor(strictlyAfter: strictlyAfter);
    if (reveal) _revealCurrent();
  }

  /// 锚点处（[strictlyAfter] 时为锚点之后）的第一处匹配；之后没有了回到
  /// 第一处；没有匹配为 -1。
  int _indexFromAnchor({required bool strictlyAfter}) {
    if (_matches.isEmpty) return -1;
    final anchor = _anchor;
    if (anchor == null) return 0;
    for (var i = 0; i < _matches.length; i++) {
      final match = _matches[i];
      final order = compareDiaryFindPositions(
        match.path,
        match.start,
        anchor.path,
        anchor.offset,
      );
      if (order > 0 || (order == 0 && !strictlyAfter)) return i;
    }
    return 0;
  }

  /// 当前匹配在收起的折叠块里时先展开（展开后路径不变，匹配仍有效），再
  /// 请正文滚过去。只读正文（预览页）只展开本地的显示状态，不写文档。
  void _revealCurrent() {
    final match = current;
    if (match == null) return;
    if (_editor.readOnly) {
      expandDiaryToggleViewsAbove(match.node);
    } else {
      _applying = true;
      try {
        expandDiaryTogglesAbove(_state, match.node);
      } finally {
        _applying = false;
      }
    }
    revealRequests.value++;
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    unawaited(_transactions?.cancel());
    revealRequests.dispose();
    barHeight.dispose();
    super.dispose();
  }
}

/// 输入查找文字、正文改动之后重新查找的防抖间隔（不是动画时长）。
const Duration kDiaryFindDebounce = Duration(milliseconds: 160);
