import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../app/theme/expressive_surfaces.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/search_pill_field.dart';
import '../../controllers/diary_find_replace.dart';
import 'diary_find_bar_rows.dart';

/// 查找栏卡片与正文底边（键盘上沿）之间、以及正文要再多让出的距离：页面
/// 给正文末尾留白、把当前匹配停在查找栏上方时都加上它（与悬浮工具栏的
/// 间距相同）。
const double kDiaryFindBarGap = 12;

/// 正文的查找栏：悬浮在正文底部、键盘之上的卡片里（编辑页与悬浮工具栏
/// 同一张卡片，预览页单独一张），只做界面，查找、跳转与替换都经
/// [DiaryFindReplace]。
///
/// 版式（DESIGN.md §5.6）：
/// - 第一行：胶囊查找框（行尾“第几处 / 共几处”，没有结果或正则写错时换成
///   提示）+ 上一个 / 下一个 + 关闭；
/// - 第二行：一排选项胶囊（正则表达式、区分大小写、全词匹配），能替换时
///   右端固定一个“替换”；
/// - 第三行（点“替换”展开，`medium` 补间高度）：替换框 + “替换”与“全部
///   替换”。[onReplacedAll] 为 null（只读的预览页）时没有替换。
///
/// 高度：卡片的外观与出现 / 收起的过渡由页面负责；这里把自己排好的高度
/// （不随补间逐帧变化，见 [_BarHeightReporter]）写进
/// [DiaryFindReplace.barHeight]，页面据此给正文末尾留白，揭示当前匹配时让开
/// 查找栏。
///
/// 焦点：[autofocus] 时打开后查找框取得焦点并全选原有文字（从搜索结果打开
/// 日记时不取焦点，不弹键盘）；键盘的搜索键跳到下一处、焦点不离开。桌面上
/// Shift + Enter 为上一处，F3 / Shift + F3 同下一处 / 上一处，Esc 经页面的
/// 返回链路先关掉查找。页面经 [DiaryFindBarState.focusFind] /
/// [DiaryFindBarState.focusReplace] 把焦点交回来（Ctrl / ⌘ + F、H）。
class DiaryFindBar extends StatefulWidget {
  const DiaryFindBar({
    super.key,
    required this.find,
    required this.onClose,
    this.onReplacedAll,
    this.focusReplaceOnOpen = false,
    this.autofocus = true,
  });

  final DiaryFindReplace find;
  final VoidCallback onClose;

  /// 全部替换之后（换掉的处数），页面弹出带撤销的提示条；null 时没有替换
  /// （只读正文）。
  final ValueChanged<int>? onReplacedAll;

  /// 打开时焦点给替换框而不是查找框（经替换的快捷键打开）。
  final bool focusReplaceOnOpen;

  /// 打开时查找框取得焦点。
  final bool autofocus;

  @override
  State<DiaryFindBar> createState() => DiaryFindBarState();
}

class DiaryFindBarState extends State<DiaryFindBar> {
  late final TextEditingController _findText = TextEditingController(
    text: widget.find.query.text,
  );
  late final TextEditingController _replaceText = TextEditingController(
    text: widget.find.replacement,
  );
  final FocusNode _findFocus = FocusNode(debugLabel: 'diary-find');
  final FocusNode _replaceFocus = FocusNode(debugLabel: 'diary-replace');

  bool get _canReplace => widget.onReplacedAll != null;

  @override
  void initState() {
    super.initState();
    widget.find.addListener(_syncQueryText);
    if (!widget.autofocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.focusReplaceOnOpen && _canReplace ? focusReplace() : focusFind();
    });
  }

  @override
  void didUpdateWidget(DiaryFindBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.find != widget.find) {
      oldWidget.find.removeListener(_syncQueryText);
      widget.find.addListener(_syncQueryText);
    }
  }

  @override
  void dispose() {
    widget.find.removeListener(_syncQueryText);
    _findText.dispose();
    _replaceText.dispose();
    _findFocus.dispose();
    _replaceFocus.dispose();
    super.dispose();
  }

  /// 查找文字由会话换掉（选中一段正文后再按 Ctrl / ⌘ + F、从搜索打开）而
  /// 查找框没在输入时，把框里的文字同步过来。正在输入时以框里为准：会话
  /// 的文字随输入防抖更新，不能反过来覆盖。
  void _syncQueryText() {
    final text = widget.find.query.text;
    if (_findText.text == text || _findFocus.hasFocus) return;
    _findText.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// 焦点交给查找框并全选：接着打字即换掉原来的查找文字。
  void focusFind() {
    final text = widget.find.query.text;
    if (_findText.text != text) _findText.text = text;
    _findText.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _findText.text.length,
    );
    _findFocus.requestFocus();
  }

  /// 展开替换一行并把焦点交给替换框。
  void focusReplace() {
    if (!_canReplace) return;
    widget.find.setReplaceVisible(true);
    _replaceText.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _replaceText.text.length,
    );
    _replaceFocus.requestFocus();
  }

  void _replaceAll() {
    final count = widget.find.replaceAll();
    if (count > 0) widget.onReplacedAll?.call(count);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter, shift: true):
            widget.find.previous,
        const SingleActivator(LogicalKeyboardKey.f3): widget.find.next,
        const SingleActivator(LogicalKeyboardKey.f3, shift: true):
            widget.find.previous,
      },
      child: ListenableBuilder(
        listenable: widget.find,
        builder: (BuildContext context, Widget? _) => _buildRows(context),
      ),
    );
  }

  Widget _buildRows(BuildContext context) {
    final l10n = context.l10n;
    final find = widget.find;
    final scheme = Theme.of(context).colorScheme;
    // 卡片是 surface 底：框用高一档的容器色与卡片拉开（玻璃时由
    // SearchPillField 换成玻璃填充）。
    final fill = scheme.surfaceContainerHigh;
    final outline = ExpressiveSurfaces.cardBorderColor(scheme);
    final hasMatches = find.matches.isNotEmpty;
    final replaceVisible = _canReplace && find.replaceVisible;
    return AnimatedSize(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.effects,
      alignment: Alignment.topCenter,
      child: _BarHeightReporter(
        find: find,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 4, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: SearchPillField(
                      key: const ValueKey<String>('diary-find-field'),
                      controller: _findText,
                      focusNode: _findFocus,
                      hintText: l10n.diaryFindHint,
                      fill: fill,
                      idleOutline: outline,
                      keepFocusOnSubmit: true,
                      onChanged: find.setText,
                      onSubmitted: (_) => find.next(),
                      onClear: () {
                        _findText.clear();
                        find.setText('');
                        _findFocus.requestFocus();
                      },
                      trailing: DiaryFindCount(find: find),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('diary-find-previous'),
                    tooltip: l10n.diaryFindPrevious,
                    visualDensity: VisualDensity.compact,
                    onPressed: hasMatches ? find.previous : null,
                    icon: const FaIcon(FontAwesomeIcons.angleUp, size: 16),
                  ),
                  IconButton(
                    key: const ValueKey<String>('diary-find-next'),
                    tooltip: l10n.diaryFindNext,
                    visualDensity: VisualDensity.compact,
                    onPressed: hasMatches ? find.next : null,
                    icon: const FaIcon(FontAwesomeIcons.angleDown, size: 16),
                  ),
                  IconButton(
                    key: const ValueKey<String>('diary-find-close'),
                    tooltip: l10n.diaryFindClose,
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onClose,
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            DiaryFindOptionsRow(find: find, canReplace: _canReplace),
            if (replaceVisible)
              DiaryFindReplaceRow(
                find: find,
                controller: _replaceText,
                focusNode: _replaceFocus,
                fill: fill,
                idleOutline: outline,
                onReplaceAll: _replaceAll,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 量出查找栏排好的高度写进 [DiaryFindReplace.barHeight]。放在补间高度的
/// [AnimatedSize] 里面：量到的是目标高度，展开替换一行时只写一次，正文
/// 的留白不随补间逐帧重建。布局之后的下一帧才写（布局期间不能通知别的
/// 部件重建）；查找已关（收起的过渡里）时不写。
class _BarHeightReporter extends SingleChildRenderObjectWidget {
  const _BarHeightReporter({required this.find, super.child});

  final DiaryFindReplace find;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBarHeightReporter(find);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBarHeightReporter renderObject,
  ) {
    renderObject.find = find;
  }
}

class _RenderBarHeightReporter extends RenderProxyBox {
  _RenderBarHeightReporter(this.find);

  DiaryFindReplace find;
  bool _scheduled = false;

  @override
  void performLayout() {
    super.performLayout();
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!attached || !hasSize || !find.isOpen) return;
      find.barHeight.value = size.height;
    });
  }
}
