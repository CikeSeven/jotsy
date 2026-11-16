import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../core/database/rich_text/inline_rich_text.dart';
import '../../widgets/rich_text/inline_rich_text_controller.dart';
import '../models/diary_link_candidate.dart';
import '../widgets/diary_link/diary_link_candidate_list.dart';
import 'diary_link_editing.dart';
import 'diary_link_search.dart';

/// 写留言面板里的 `@` / `[[` 日记链接会话（输入框版，规则同正文的
/// `DiaryMentionMenuController`）。
///
/// 触发：在输入框里打出（不是粘贴；组字中同样算，见 [_detect]）——
/// - `@`：前一个字是空白或在开头；
/// - 第二个 `[`（或中文输入法的 `【`）：前一个字正是同一个括号，不要求前面是
///   空白。
/// 触发字留在文字里，之后到光标为止的文字就是检索词；候选经
/// [DiaryLinkSearchController] 防抖查询（与正文、链接对话框同一口径
/// [searchDiaryLinkCandidates]）。
///
/// 会话边界：光标退到触发字之前或有了选区、触发字被删掉、检索词超过
/// [maxQueryLength] 字或含换行、`[[` 会话里打出右括号、检索词以空格结尾而
/// 结果为空时结束；返回键（面板经 [close]）同样结束，已输入的文字原样保留。
/// 软键盘打出的回车在有候选时写入高亮项（见 [_sync]）。选中
/// 候选时把“触发字 + 检索词”换成带日记链接的候选名称（[InlineRichTextController.replaceRange]），
/// 光标停在它后面，之后打的字不会延长链接。
///
/// 生命周期：监听 [text]，[dispose] 时移除监听并释放查询控制器（晚到的结果
/// 不再通知）。
class DiaryCommentMentionController extends ChangeNotifier
    implements DiaryLinkCandidateSource {
  DiaryCommentMentionController({
    required this.text,
    required DiaryLinkSearch search,
    required this.kinds,
  }) : _search = DiaryLinkSearchController(search, kinds: const {}),
       _last = text.value {
    text.addListener(_onText);
    _search.addListener(_onResults);
  }

  final InlineRichTextController text;

  /// 触发时可选的种类（随日记本功能开关，触发时读取）。
  final Set<DiaryLinkKind> Function() kinds;

  final DiaryLinkSearchController _search;
  TextEditingValue _last;
  int? _trigger;
  String _triggerText = '';
  String _query = '';
  int _highlighted = 0;

  /// 检索词的长度上限（同正文的 `@` 菜单），超过即视为在写留言。
  static const int maxQueryLength = 32;

  bool get isOpen => _trigger != null;

  /// 这次会话的触发字（`@`、`[[` 或 `【【`）。
  String get trigger => _triggerText;

  @override
  String get query => _query;

  @override
  List<DiaryLinkCandidate>? get results => _search.results;

  @override
  int get highlighted => _highlighted;

  void _onText() {
    final value = text.value;
    final previous = _last;
    _last = value;
    if (isOpen) {
      _sync(value);
    } else if (value.text != previous.text) {
      _detect(previous, value);
    }
  }

  /// 刚打出的一个字是不是触发字：新文字正好是旧文字在光标前多了一个字。
  void _detect(TextEditingValue previous, TextEditingValue value) {
    final selection = value.selection;
    // 组字中也照常判断：Gboard 等会把 `@` 算进正在组的词（邮箱写法），
    // 要求不在组字中就永远触发不了。
    if (!selection.isValid || !selection.isCollapsed) return;
    final caret = selection.end;
    final current = value.text;
    if (caret < 1 || current.length != previous.text.length + 1) return;
    if (current.substring(0, caret - 1) + current.substring(caret) !=
        previous.text) {
      return;
    }
    final typed = current[caret - 1];
    if (typed == '@') {
      if (caret == 1 || current[caret - 2].trim().isEmpty) {
        _open(caret - 1, '@');
      }
    } else if ((typed == '[' || typed == '【') &&
        caret >= 2 &&
        current[caret - 2] == typed) {
      _open(caret - 2, typed * 2);
    }
  }

  void _open(int offset, String trigger) {
    _trigger = offset;
    _triggerText = trigger;
    _query = '';
    _highlighted = 0;
    _search.kinds = kinds();
    _search.update('', force: true);
    notifyListeners();
  }

  void _sync(TextEditingValue value) {
    final trigger = _trigger!;
    final selection = value.selection;
    final end = trigger + _triggerText.length;
    if (!selection.isValid ||
        !selection.isCollapsed ||
        selection.end < end ||
        end > value.text.length ||
        !value.text.startsWith(_triggerText, trigger)) {
      close();
      return;
    }
    final query = value.text.substring(end, selection.end);
    // 软键盘的回车（实体键盘的回车在输入框之前就被拦下）：有候选时写入
    // 高亮项，换行连同检索词一起被换掉；没有候选时照常换行、会话结束。
    if (query == '$_query\n') {
      if (!confirm()) close();
      return;
    }
    if (query.contains('\n') ||
        query.length > maxQueryLength ||
        (_triggerText != '@' && query.contains(RegExp(r'[\]】]'))) ||
        (query.endsWith(' ') && (_search.results?.isEmpty ?? false))) {
      close();
      return;
    }
    if (query != _query) {
      _query = query;
      _highlighted = 0;
      _search.update(query, force: true);
      notifyListeners();
    }
  }

  void _onResults() {
    final count = results?.length ?? 0;
    _highlighted = count == 0 ? 0 : _highlighted.clamp(0, count - 1);
    if (isOpen) notifyListeners();
  }

  /// 结束会话，文字原样保留。
  void close() {
    if (_trigger == null) return;
    _trigger = null;
    _query = '';
    _search.reset();
    notifyListeners();
  }

  /// 键盘移动高亮（首尾循环）；没有候选时返回 false，按键交还输入框。
  bool moveHighlight(int delta) {
    final count = results?.length ?? 0;
    if (!isOpen || count == 0) return false;
    _highlighted = (_highlighted + delta) % count;
    if (_highlighted < 0) _highlighted += count;
    notifyListeners();
    return true;
  }

  /// 确认高亮项；没有候选时返回 false（回车照常换行）。
  bool confirm() {
    final list = results;
    if (!isOpen || list == null || list.isEmpty) return false;
    pick(list[_highlighted.clamp(0, list.length - 1)]);
    return true;
  }

  /// 把“触发字 + 检索词”换成带日记链接的 [candidate] 名称。
  @override
  void pick(DiaryLinkCandidate candidate) {
    final trigger = _trigger;
    final selection = text.selection;
    close();
    final label = diaryLinkSingleLine(candidate.label);
    if (trigger == null || !selection.isValid || label.isEmpty) return;
    text.replaceRange(
      trigger,
      selection.end,
      label,
      marks: InlineTextMarks(href: candidate.target.toHref()),
    );
  }

  @override
  void dispose() {
    text.removeListener(_onText);
    _search.removeListener(_onResults);
    _search.dispose();
    super.dispose();
  }
}
