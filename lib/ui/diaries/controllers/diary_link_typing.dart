import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';

/// 链接输入会话：折叠光标处没有可加链接的文字时，在链接对话框里填好网址
/// 确认后，接着输入的文字都写成这条链接，打出空白字符（空格、回车等）即
/// 结束，空白本身不带链接。
///
/// 为什么要单独做会话：上游只经“下次输入”样式（toggledStyle）带一次
/// `href`，第一个字写入后选区一变就被清空；之后的新字按上游切片规则——
/// 前一个字带 `href`、后一个字不带时丢掉 `href`（链接后接着打字不延长
/// 链接，见 `insertDiaryInlineLink`）——于是只有第一个字成了链接。组字
/// （拼音、英文联想）的替换走上游的 `replaceText`，根本不看 toggledStyle。
///
/// 为什么不拦截输入、自己写字：上游把被拦截的输入当作“没有应用”，会把
/// 输入法的编辑状态退回输入前；组字中途这样做，输入法以为拼音不存在，确认
/// 候选时汉字接在拼音后面（“ni你好”）。所以文字一律由上游照常写入，这里
/// 只在每次改动后补格式：
/// - 会话文字是 [_node] 里 [_start, _end) 这一段。上游写入输入后紧接着
///   把光标设到输入的文字末尾，终点就取这个光标（见 [_onSelection]）——
///   不从改动本身推算：上游把文字改动合成整块 delta 的替换，从新旧文字
///   反推插入位置遇到重复的字会有歧义；
/// - 用户改动（[af.TransactionSource.userEdit]）之后，在微任务里给这段补上
///   `href`：第一个空白之前的字带链接，空白及之后去掉本会话的链接并结束
///   会话。补格式只改属性、不改文字也不动选区，输入法状态不受影响；按上游
///   打字的撤销合并并进同一步。放进微任务是因为事务通知在上游 `apply`
///   中途发出，在里面再套一次事务会让补格式先于这次输入进撤销栈。
///
/// 会话边界：光标必须折叠在 [_node] 里、落在会话文字的范围内（还没打字时
/// 就在起点）；选区移到别处（点按、方向键移出、回车换到下一段、退格删到
/// 起点之前）即结束。选区暂时为 null（焦点在对话框与正文间交接）不结束。
class DiaryLinkTyping {
  DiaryLinkTyping(this.state);

  final af.EditorState state;

  af.Node? _node;
  String? _href;
  int _start = 0;
  int _end = 0;
  StreamSubscription<af.EditorTransactionValue>? _transactions;

  /// 刚收到事务通知、还没收到随后的选区通知。不更新选区的事务（如自动
  /// 展开折叠块）没有随后的选区通知，事务后的微任务里清掉，不留给之后的
  /// 点按。
  bool _afterTransaction = false;
  bool _afterApplyScheduled = false;

  /// 期间有用户改动，事务后的微任务里要补格式。
  bool _needsNormalize = false;

  static final RegExp _whitespace = RegExp(r'\s');

  /// 光标仍在会话里时为链接地址，否则为 null。按当前选区实时判断：选区
  /// 刚移走、会话还没收到通知时也不会误报（工具栏「链接」据此高亮）。
  String? get href => _caretInside() ? _href : null;

  /// 在当前折叠光标处开启会话（之前的会话先结束）。光标不在文字块里、
  /// 选区不是折叠的或正文只读时什么也不做。
  void begin(String href) {
    end();
    final selection = state.selection;
    if (state.isDisposed || !state.editable || selection == null) return;
    if (!selection.isCollapsed) return;
    final node = state.getNodeAtPath(selection.end.path);
    if (node?.delta == null) return;
    _node = node;
    _href = href;
    _start = _end = selection.end.offset;
    state.selectionNotifier.addListener(_onSelection);
    _transactions = state.transactionStream.listen(_onTransaction);
  }

  void end() {
    if (_node == null) return;
    _node = null;
    _href = null;
    _afterTransaction = false;
    _needsNormalize = false;
    unawaited(_transactions?.cancel());
    _transactions = null;
    if (!state.isDisposed) {
      state.selectionNotifier.removeListener(_onSelection);
    }
  }

  bool _caretInside() {
    final node = _node;
    final selection = state.selection;
    if (node == null ||
        state.isDisposed ||
        !state.editable ||
        node.parent == null ||
        selection == null ||
        !selection.isCollapsed ||
        !selection.end.path.equals(node.path)) {
      return false;
    }
    final caret = selection.end.offset;
    return caret >= _start && caret <= _end;
  }

  /// 选区通知：紧跟在事务之后的（上游 `apply` 最后一步设选区），光标
  /// 只要还在本块、不在起点之前，就把会话终点移到光标处——打字、组字、
  /// 退格都由此更新范围；其余（点按、方向键、程序设的选区）须落在已有
  /// 范围内，否则结束。
  void _onSelection() {
    final node = _node;
    final selection = state.selection;
    if (node == null || selection == null) return;
    final afterTransaction = _afterTransaction;
    _afterTransaction = false;
    if (!selection.isCollapsed ||
        node.parent == null ||
        !selection.end.path.equals(node.path) ||
        selection.end.offset < _start) {
      end();
      return;
    }
    if (afterTransaction) {
      _end = selection.end.offset;
    } else if (selection.end.offset > _end) {
      end();
    }
  }

  /// 事务通知是同步的，先于上游更新选区。微任务在这次 `apply`（连同随后
  /// 的选区通知）结束后才执行。
  void _onTransaction(af.EditorTransactionValue event) {
    final node = _node;
    if (node == null || event.$1 != af.TransactionTime.after) return;
    if (node.parent == null) {
      end();
      return;
    }
    _afterTransaction = true;
    if (event.$3.resolvedSource == af.TransactionSource.userEdit) {
      _needsNormalize = true;
    }
    if (!_afterApplyScheduled) {
      _afterApplyScheduled = true;
      scheduleMicrotask(_afterApply);
    }
  }

  void _afterApply() {
    _afterApplyScheduled = false;
    _afterTransaction = false;
    if (_needsNormalize) {
      _needsNormalize = false;
      _normalize();
    }
  }

  /// 给会话文字补格式（见类注释）；没有要改的就不发事务，补格式自己的
  /// 事务通知回来时到这里即止。
  void _normalize() {
    final node = _node;
    final href = _href;
    final delta = node?.delta;
    if (node == null || href == null || state.isDisposed) return;
    if (delta == null || node.parent == null) {
      end();
      return;
    }
    final start = math.min(_start, delta.length);
    final stop = _end.clamp(start, delta.length);
    final cut = delta.toPlainText().substring(start, stop).indexOf(_whitespace);
    final linkEnd = cut < 0 ? stop : start + cut;
    final transaction = state.transaction;
    var offset = start;
    for (final op in delta.slice(start, stop)) {
      final length = op.length;
      final linked = op.attributes?[kDiaryInlineHref] == href;
      // 一段字可能跨过链接与空白的分界，按分界拆开。
      final linkPart = (linkEnd - offset).clamp(0, length);
      if (linkPart > 0 && !linked) {
        transaction.formatText(node, offset, linkPart, {
          kDiaryInlineHref: href,
        });
      }
      if (length - linkPart > 0 && linked) {
        transaction.formatText(node, offset + linkPart, length - linkPart, {
          kDiaryInlineHref: null,
        });
      }
      offset += length;
    }
    if (cut >= 0) end();
    if (transaction.operations.isEmpty) return;
    unawaited(state.apply(transaction, withUpdateSelection: false));
  }
}
