import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/alphabet_index_bar.dart';

import '../../viewmodels/tag_picker_view.dart';
import 'publish_panel_tile.dart';
import 'publish_tag_row.dart';

/// 标签子页的可滚动列表：[header]（新建行与提示，见 [PublishTagListHeader]）
/// 在最前，随列表滚动；其后是 [view] 的各组标签，每行由 [rowBuilder] 建出
/// （发布面板的勾选行、多选日记标签面板的三态行都是 [PublishTagRow]）。
/// 行的选中状态由调用方持有：调用方重建本组件即刷新各行；也可经
/// [rowsScope] 把各行包进自己的监听（发布面板只在草稿的标签变化时重建
/// 各行），不动列表本身与滚动位置。
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
    required this.rowBuilder,
    required this.header,
    required this.indexed,
    this.rowsScope,
  });

  final TagPickerView view;

  /// 建一个标签的一行。
  final Widget Function(BuildContext context, Tag tag) rowBuilder;

  /// 包住全部标签行：参数 `buildRows` 按当前状态铺出各组标签，调用方把它
  /// 放进自己的监听里调用；null 时直接铺出。
  final Widget Function(BuildContext context, WidgetBuilder buildRows)?
  rowsScope;
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

  Widget _buildRows(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (final section in widget.view.sections) ...<Widget>[
        if (section.letter case final letter?)
          PublishTagSectionHeader(key: _keyFor(letter), letter: letter),
        for (final tag in section.tags) widget.rowBuilder(context, tag),
      ],
    ],
  );

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
          widget.rowsScope?.call(context, _buildRows) ?? _buildRows(context),
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

/// 标签列表最前的“新建”行与空态提示（发布面板标签子页与多选日记的标签
/// 面板共用）。检索词还没有同名标签时，新建行变成“新建「检索词」”，
/// [onCreate] 收到预填的名称（不在检索或已有同名标签时为 null）。
class PublishTagListHeader extends StatelessWidget {
  const PublishTagListHeader({
    super.key,
    required this.view,
    required this.hasTags,
    required this.onCreate,
  });

  final TagPickerView view;
  final bool hasTags;
  final ValueChanged<String?> onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final createName = view.createName;
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final String? hint;
    if (view.isSearching && view.isEmpty) {
      hint = l10n.tagPickerSearchEmpty(view.query);
    } else if (!hasTags) {
      hint = l10n.autoT0166;
    } else {
      hint = null;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 与面板其他行同一表面；检索时带上检索词。
          PublishPanelTile(
            onTap: () => onCreate(createName),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const FaIcon(FontAwesomeIcons.plus, size: 12),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    createName == null
                        ? l10n.autoT0157
                        : l10n.tagPickerCreateNamed(createName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text(hint, textAlign: TextAlign.center, style: hintStyle),
            ),
        ],
      ),
    );
  }
}
