import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/widgets/alphabet_index_bar.dart';
import 'package:node_diary/ui/widgets/value_listenable_selector.dart';

import '../../viewmodels/tag_picker_view.dart';
import 'publish_tag_row.dart';

/// 标签子页的可滚动列表：[header]（新建行与提示）在最前，随列表滚动；
/// 其后是 [view] 的各组标签。
///
/// [indexed] 为 true（按字母排序）时：每组前有字母标题，右侧留出索引条的
/// 位置，有两组以上时显示 [AlphabetIndexBar]。
///
/// 跳转与高亮：标签数通常在百个以内，整份列表一次建好（与改版前一致），
/// 各组标题挂 [GlobalKey]，任何一组都能经视口算出“滚到顶”的偏移直接
/// 跳过去。滚动时取最后一个已滚到顶部（含）以上的标题作为当前字母，只在
/// 变化时通知索引条；布局变化（检索、标签增删）后在下一帧重新计算。
/// 检索词变化时回到顶部，结果总是从第一条看起。
class PublishTagList extends StatefulWidget {
  const PublishTagList({
    super.key,
    required this.view,
    required this.selection,
    required this.onToggle,
    required this.header,
    required this.indexed,
  });

  final TagPickerView view;
  final ValueListenable<DiaryMetaDraft> selection;
  final void Function(int tagId, bool selected) onToggle;
  final Widget header;
  final bool indexed;

  @override
  State<PublishTagList> createState() => _PublishTagListState();
}

class _PublishTagListState extends State<PublishTagList> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<String?> _activeLetter = ValueNotifier<String?>(null);
  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncActiveLetter);
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant PublishTagList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view.query != widget.view.query && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    _scheduleSync();
  }

  @override
  void dispose() {
    _scroll.removeListener(_syncActiveLetter);
    _scroll.dispose();
    _activeLetter.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String letter) =>
      _sectionKeys.putIfAbsent(letter, () => GlobalKey(debugLabel: letter));

  void _scheduleSync() {
    if (!widget.indexed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncActiveLetter();
    });
  }

  /// 把 [letter] 那组的标题滚到顶部所需的偏移；标题还没布局时为 null。
  double? _revealOffsetOf(String letter) {
    final box = _sectionKeys[letter]?.currentContext?.findRenderObject();
    if (box == null || !box.attached) return null;
    return RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset;
  }

  void _syncActiveLetter() {
    if (!widget.indexed || !_scroll.hasClients) return;
    final letters = widget.view.letters;
    if (letters.isEmpty) {
      _activeLetter.value = null;
      return;
    }
    // 第一组标题之前（新建行还在顶部）也算第一组。
    var active = letters.first;
    final offset = _scroll.offset;
    for (final letter in letters) {
      final reveal = _revealOffsetOf(letter);
      if (reveal == null || reveal > offset + 0.5) break;
      active = letter;
    }
    _activeLetter.value = active;
  }

  void _jumpTo(String letter) {
    final reveal = _revealOffsetOf(letter);
    if (reveal == null || !_scroll.hasClients) return;
    final position = _scroll.position;
    _scroll.jumpTo(
      reveal.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    // 靠近末尾的组滚不到顶，按滚动位置会算成前一组；以按下的字母为准。
    _activeLetter.value = letter;
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final letters = widget.indexed ? view.letters : const <String>[];
    const sidePadding = 16.0;
    // 按字母时始终给索引条留位置，检索使组数变化时列表宽度不跳。
    final endPadding = widget.indexed
        ? AlphabetIndexBar.width + 8 + 4
        : sidePadding;
    final list = SingleChildScrollView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(sidePadding, 4, endPadding, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          widget.header,
          ValueListenableSelector<DiaryMetaDraft, Set<int>>(
            valueListenable: widget.selection,
            selector: (value) => value.tagIds,
            builder: (context, selectedIds, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final section in view.sections) ...<Widget>[
                  if (section.letter case final letter?)
                    PublishTagSectionHeader(
                      key: _keyFor(letter),
                      letter: letter,
                    ),
                  for (final tag in section.tags)
                    PublishTagRow(
                      tag: tag,
                      selected: selectedIds.contains(tag.id),
                      onToggle: (selected) => widget.onToggle(tag.id, selected),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (!widget.indexed) return list;
    return Stack(
      children: <Widget>[
        Positioned.fill(child: list),
        Positioned(
          top: 4,
          bottom: 8,
          right: 4,
          width: AlphabetIndexBar.width,
          // 检索使分组少于两组时索引条淡出（只剩一组，跳转没有意义）。
          child: AnimatedSwitcher(
            duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
            switchInCurve: ExpressiveMotion.effects,
            switchOutCurve: ExpressiveMotion.exit,
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: <Widget>[...previous, ?current],
            ),
            child: letters.length < 2
                ? const SizedBox.shrink()
                : AlphabetIndexBar(
                    letters: letters,
                    activeLetter: _activeLetter,
                    onLetterSelected: _jumpTo,
                  ),
          ),
        ),
      ],
    );
  }
}
