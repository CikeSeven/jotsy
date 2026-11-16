import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../core/database/rich_text/inline_rich_text.dart';
import '../../widgets/rich_text/inline_rich_text_controller.dart';
import '../widgets/diary_link_dialog.dart';
import 'diary_comment_mention.dart';
import 'diary_link_editing.dart';
import 'diary_link_search.dart';

/// 写留言面板里输入框的编辑状态：带格式的文字 [text]、它的焦点 [focus] 与
/// `@` / `[[` 会话 [mention]。
///
/// 输入：初始文字与格式、候选查询 [DiaryLinkSearch]、可链接的种类与要排除
/// 的日记（这条留言所属的那篇）；输出：输入框里的文字与格式；副作用只在
/// 自己持有的控制器上。
///
/// 键盘（桌面的实体键盘；输入法组字时一律不拦）：
/// - 会话开着且有候选：↑ / ↓ 移动高亮，Enter / Tab 写入，Esc 结束会话；
/// - Ctrl / ⌘ + B / I / U、Ctrl / ⌘ + Shift + S 设格式（[inlineFormatShortcut]），
///   Ctrl / ⌘ + K 打开链接对话框（与正文一致）。
/// 软键盘没有方向键：会话开着时打出的回车写入高亮的候选（换行连同检索词
/// 一起被换掉），没有候选时照常换行、会话结束。
class DiaryCommentTextEditing {
  DiaryCommentTextEditing({
    required List<InlineTextRun> runs,
    required DiaryLinkSearch search,
    required Set<DiaryLinkKind> Function() kinds,
    required this.excludeDiaryId,
    required this.onOpenLinkDialog,
  }) : text = InlineRichTextController(runs: runs, onChanged: _ignore) {
    mention = DiaryCommentMentionController(
      text: text,
      search: search,
      kinds: kinds,
    );
    focus = FocusNode(debugLabel: 'diary-comment', onKeyEvent: _onKey);
  }

  static void _ignore(
    String text,
    List<InlineTextRun> runs, {
    bool format = false,
  }) {}

  final InlineRichTextController text;
  late final DiaryCommentMentionController mention;
  late final FocusNode focus;

  /// 不出现在候选里的日记（这条留言所属的那篇）。
  final String? excludeDiaryId;

  /// Ctrl / ⌘ + K：由面板打开链接对话框（需要它的 BuildContext）。
  final VoidCallback onOpenLinkDialog;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (text.value.isComposingRangeValid) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (mention.isOpen) {
      final handled = switch (key) {
        LogicalKeyboardKey.arrowUp => mention.moveHighlight(-1),
        LogicalKeyboardKey.arrowDown => mention.moveHighlight(1),
        LogicalKeyboardKey.enter ||
        LogicalKeyboardKey.numpadEnter ||
        LogicalKeyboardKey.tab => mention.confirm(),
        LogicalKeyboardKey.escape => () {
          mention.close();
          return true;
        }(),
        _ => false,
      };
      if (handled) return KeyEventResult.handled;
    }
    if (inlineFormatShortcut(event) case final mark?) {
      text.toggle(mark);
      return KeyEventResult.handled;
    }
    final keys = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.keyK &&
        (keys.isControlPressed || keys.isMetaPressed) &&
        !keys.isAltPressed &&
        !keys.isShiftPressed &&
        event is KeyDownEvent) {
      onOpenLinkDialog();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 链接对话框（格式条的链接按钮与 Ctrl / ⌘ + K）：作用于选区，选区或光标
  /// 在一段链接里（或紧挨着它）时作用于整段链接。选中了文字时给它设 / 改 /
  /// 去掉链接；没选文字时在光标处写入链接文字（网址写网址本身，日记 /
  /// 日记本写名称）。关掉对话框后焦点还给输入框。
  Future<void> editLink(BuildContext context) async {
    final selection = text.selection;
    if (!selection.isValid) return;
    mention.close();
    final link = text.linkRange;
    final start = link?.start ?? selection.start;
    final end = link?.end ?? selection.end;
    final choice = await showDiaryLinkDialog(
      context,
      initialHref: link?.href,
      linkTargets: true,
      excludeDiaryId: excludeDiaryId,
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case DiaryWebLinkChoice(:final url) when url.isEmpty:
        text.setLink(start, end, null);
      case DiaryWebLinkChoice(:final url) when start == end:
        text.replaceRange(start, end, url, marks: InlineTextMarks(href: url));
      case DiaryWebLinkChoice(:final url):
        text.setLink(start, end, url);
      case DiaryRemoveLinkChoice():
        text.setLink(start, end, null);
      case DiaryTargetLinkChoice(:final candidate) when start == end:
        final label = diaryLinkSingleLine(candidate.label);
        if (label.isNotEmpty) {
          text.replaceRange(
            start,
            end,
            label,
            marks: InlineTextMarks(href: candidate.target.toHref()),
          );
        }
      case DiaryTargetLinkChoice(:final candidate):
        text.setLink(start, end, candidate.target.toHref());
    }
    focus.requestFocus();
  }

  void dispose() {
    mention.dispose();
    focus.dispose();
    text.dispose();
  }
}
