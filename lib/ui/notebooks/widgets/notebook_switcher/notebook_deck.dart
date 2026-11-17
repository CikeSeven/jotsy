import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ViewportOffset;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/services/app_platform.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import '../../controllers/notebook_deck_motion.dart';
import '../../controllers/notebook_switcher_controller.dart';
import '../../sections/notebook_action_flows.dart';
import '../../sections/notebook_action_sheets.dart';
import '../../viewmodels/notebook_deck_entries.dart';
import '../../viewmodels/notebook_deck_layout.dart';
import 'notebook_deck_card.dart';
import 'notebook_deck_viewport.dart';

/// 日记本卡组：竖向层叠的横卡（几何见 [NotebookDeckLayout]）。
///
/// 输入：条目 [entries] 与它们的布局 [layout]（变化时各卡片弹簧到新位置：
/// 子本从上级底下抽出、收起时收回上级底下，被删的原地淡出）、发牌进度
/// [reveal]（卡组长出来时卡片从行首依次落位）；输出：点选 / 拖选经
/// [controller] 切换，子本与“已合上”的展开经 [onToggle]，长按弹出日记本
/// 快捷菜单（编辑、置顶、合上、删除，与管理页同一套流程）。
///
/// 性能：卡片只在条目或宽度变化时排版一次，每张包一层重绘边界；滚动、
/// 抬起、抽出、发牌都只改 Flow 的绘制变换与不透明度（[NotebookDeckMotion]
/// 与滚动偏移逐帧通知 Flow 重绘，不重建、不重排）。
class NotebookDeck extends ConsumerStatefulWidget {
  const NotebookDeck({
    super.key,
    required this.entries,
    required this.layout,
    required this.controller,
    required this.reveal,
    required this.viewportHeight,
    required this.isCurrent,
    required this.onToggle,
  });

  final List<NotebookDeckEntry> entries;
  final NotebookDeckLayout layout;
  final NotebookSwitcherController controller;

  /// 发牌进度（0 → 1）：卡组长出来的那一段。
  final ValueListenable<double> reveal;

  /// 打开时视口的高度（定初始滚动位置，让当前那张露在上部）。
  final double viewportHeight;
  final bool Function(NotebookDeckEntry entry) isCurrent;
  final ValueChanged<NotebookDeckEntry> onToggle;

  /// 前几张错峰发牌，之后的同步。
  static const int dealSlots = 8;

  /// 拖选时离上下边缘多近开始自动滚动、最快多快（逻辑像素 / 秒）。
  static const double autoScrollZone = 48;
  static const double autoScrollSpeed = 900;

  @override
  ConsumerState<NotebookDeck> createState() => _NotebookDeckState();
}

/// 卡组里的一张：在场的条目，或正在离场的残影（[leaving]）。
class _DeckItem {
  _DeckItem(this.entry, {this.leaving = false});

  final NotebookDeckEntry entry;
  final bool leaving;
  String get key => entry.key;
}

class _NotebookDeckState extends ConsumerState<NotebookDeck>
    with TickerProviderStateMixin
    implements NotebookDeckHandle {
  late final NotebookDeckMotion _motion = NotebookDeckMotion(
    vsync: this,
    reduceMotion: () => ExpressiveMotion.reduceMotion(context),
  );
  late final ScrollController _scroll;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.standard,
  );
  late final Ticker _autoScrollTicker = createTicker(_autoScrollTick);
  final FocusNode _focus = FocusNode(debugLabel: 'notebook_deck');
  final GlobalKey _viewportKey = GlobalKey();

  List<_DeckItem> _items = <_DeckItem>[];
  final Map<String, NotebookDeckEntry> _leaving = <String, NotebookDeckEntry>{};

  /// 离场项里正滑回上级底下的子本（不淡出，滑到位即被上级盖住）。
  final Set<String> _tucked = <String>{};
  String? _shakeKey;
  int _dealAnchor = 0;
  double _autoScrollVelocity = 0;
  Duration _autoScrollLast = Duration.zero;
  int _keyboardIndex = -1;

  /// 绘制回调里不读 inherited widget：方向在 build 时记下。
  bool _rtl = false;
  bool _ghostSweepScheduled = false;

  /// 上一帧各卡片在视口里的矩形与绘制顺序（命中测试用）。
  List<Rect> _rects = const <Rect>[];
  List<int> _paintOrder = const <int>[];

  @override
  void initState() {
    super.initState();
    final current = widget.entries.indexWhere(widget.isCurrent);
    final initial = current < 0
        ? 0.0
        : widget.layout.revealOffset(current, widget.viewportHeight);
    _scroll = ScrollController(initialScrollOffset: initial);
    _dealAnchor = math.max(
      0,
      widget.layout.tops.indexWhere(
        (top) => top + NotebookDeckLayout.cardHeight > initial,
      ),
    );
    _items = <_DeckItem>[for (final e in widget.entries) _DeckItem(e)];
    _motion.syncTops(_targets());
    _motion.addListener(_sweepGhosts);
    widget.controller.attachDeck(this);
    if (AppPlatform.isDesktop) {
      // 桌面从切换胶囊打开时方向键直接可用。
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant NotebookDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.detachDeck(this);
      widget.controller.attachDeck(this);
    }
    if (!listEquals(oldWidget.entries, widget.entries)) {
      _syncEntries(oldWidget.entries, oldWidget.layout);
    }
  }

  @override
  void dispose() {
    widget.controller.detachDeck(this);
    _autoScrollTicker.dispose();
    _motion.removeListener(_sweepGhosts);
    _motion.dispose();
    _shake.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Map<String, double> _targets() => <String, double>{
    for (var i = 0; i < widget.entries.length; i++)
      widget.entries[i].key: widget.layout.tops[i],
  };

  /// 条目变了：离场的子本留作残影滑回上级底下（被上级整张盖住后移出），
  /// 别的离场项原地淡出；新出现的子本从上级此刻的位置往下抽出来（一直画在
  /// 上级之下，不用淡入），别的新项原地淡入；其余的滑到新位置。
  void _syncEntries(
    List<NotebookDeckEntry> oldEntries,
    NotebookDeckLayout oldLayout,
  ) {
    final newIndex = <String, int>{
      for (var i = 0; i < widget.entries.length; i++) widget.entries[i].key: i,
    };
    final oldKeys = <String>{for (final e in oldEntries) e.key};
    for (final old in oldEntries) {
      if (newIndex.containsKey(old.key)) continue;
      final parentIndex = old.parentKey == null
          ? null
          : newIndex[old.parentKey];
      _leaving[old.key] = old;
      if (parentIndex != null) {
        _tucked.add(old.key);
        _motion.moveTop(old.key, widget.layout.tops[parentIndex]);
      } else {
        _motion.setAppear(old.key, 0);
      }
    }
    final startFrom = <String, double>{};
    for (final entry in widget.entries) {
      if (_leaving.remove(entry.key) != null) {
        // 收回途中又展开：从此刻的位置接着走。
        _tucked.remove(entry.key);
        _motion.setAppear(entry.key, 1);
        continue;
      }
      if (oldKeys.contains(entry.key)) continue;
      final parent = entry.parentKey;
      final parentTop = parent == null ? null : _motion.top(parent);
      if (parentTop != null) {
        startFrom[entry.key] = parentTop;
      } else {
        _motion.setAppear(entry.key, 0, instant: true);
        _motion.setAppear(entry.key, 1);
      }
    }
    _motion.syncTops(_targets(), startFrom: startFrom);
    _rebuildItems();
  }

  /// 在场的条目按顺序，残影插在它的上级（没有上级时在原来的前一项）后面。
  void _rebuildItems() {
    final items = <_DeckItem>[for (final e in widget.entries) _DeckItem(e)];
    for (final ghost in _leaving.values) {
      final anchor = ghost.parentKey;
      final at = anchor == null
          ? items.length
          : items.indexWhere((item) => item.key == anchor) + 1;
      items.insert(
        at <= 0 ? items.length : at,
        _DeckItem(ghost, leaving: true),
      );
    }
    _items = items;
  }

  bool _ghostDone(String key) =>
      _motion.settled(key) &&
      (_tucked.contains(key) || _motion.appearOf(key) < 0.02);

  /// 残影走完就移出卡组（放到帧后：监听回调里不 setState）。
  void _sweepGhosts() {
    if (_leaving.isEmpty || _ghostSweepScheduled) return;
    if (!_leaving.keys.any(_ghostDone)) return;
    _ghostSweepScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _ghostSweepScheduled = false;
      if (!mounted) return;
      final finished = _leaving.keys.where(_ghostDone).toList();
      if (finished.isEmpty) return;
      setState(() {
        for (final key in finished) {
          _leaving.remove(key);
          _tucked.remove(key);
          _motion.forget(key);
        }
        _rebuildItems();
      });
    });
  }

  // ==================== NotebookDeckHandle ====================

  @override
  NotebookDeckEntry? entryAt(Offset position) {
    final box = _viewportKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final local = box.globalToLocal(position);
    if (local.dy < 0 || local.dy > box.size.height) return null;
    final index = notebookDeckHitTest(local, _rects, _paintOrder);
    if (index < 0 || index >= _items.length) return null;
    final item = _items[index];
    if (item.leaving || !item.entry.selectable) return null;
    return item.entry;
  }

  @override
  void autoScroll(Offset? position) {
    final box = _viewportKey.currentContext?.findRenderObject();
    if (position == null || box is! RenderBox || !box.hasSize) {
      _autoScrollVelocity = 0;
      if (_autoScrollTicker.isActive) _autoScrollTicker.stop();
      return;
    }
    final y = box.globalToLocal(position).dy;
    final height = box.size.height;
    const zone = NotebookDeck.autoScrollZone;
    final depth = y < zone
        ? -(zone - y) / zone
        : (y > height - zone ? (y - (height - zone)) / zone : 0.0);
    _autoScrollVelocity = depth.clamp(-1.0, 1.0) * NotebookDeck.autoScrollSpeed;
    if (_autoScrollVelocity == 0) {
      if (_autoScrollTicker.isActive) _autoScrollTicker.stop();
    } else if (!_autoScrollTicker.isActive) {
      _autoScrollLast = Duration.zero;
      _autoScrollTicker.start();
    }
  }

  void _autoScrollTick(Duration elapsed) {
    final dt = (elapsed - _autoScrollLast).inMicroseconds / 1e6;
    _autoScrollLast = elapsed;
    if (!_scroll.hasClients || dt <= 0) return;
    final position = _scroll.position;
    final next = (position.pixels + _autoScrollVelocity * dt).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next != position.pixels) {
      position.jumpTo(next);
      widget.controller.refreshHover();
    }
  }

  @override
  void lift(String? key) => _motion.lift(key);

  @override
  void pullOut(String? key) => _motion.pullOut(key);

  @override
  void shake(String key) {
    if (ExpressiveMotion.reduceMotion(context)) return;
    _shakeKey = key;
    unawaited(_shake.forward(from: 0));
  }

  // ==================== 键盘（桌面） ====================

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.controller.close();
      return KeyEventResult.handled;
    }
    final selectable = <int>[
      for (var i = 0; i < widget.entries.length; i++)
        if (widget.entries[i].selectable) i,
    ];
    if (selectable.isEmpty) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final at = selectable.indexOf(_keyboardIndex);
      final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      final next = at < 0
          ? (step > 0 ? 0 : selectable.length - 1)
          : (at + step).clamp(0, selectable.length - 1);
      _keyboardIndex = selectable[next];
      _motion.lift(widget.entries[_keyboardIndex].key);
      _revealIndex(_keyboardIndex);
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space) &&
        _keyboardIndex >= 0 &&
        _keyboardIndex < widget.entries.length) {
      unawaited(widget.controller.select(widget.entries[_keyboardIndex]));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _revealIndex(int index) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final top = widget.layout.tops[index];
    final viewport = position.viewportDimension;
    double? target;
    if (top - NotebookDeckLayout.topPadding < position.pixels) {
      target = top - NotebookDeckLayout.topPadding;
    } else if (top + NotebookDeckLayout.cardHeight >
        position.pixels + viewport) {
      target = top + NotebookDeckLayout.cardHeight - viewport;
    }
    if (target == null) return;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (ExpressiveMotion.reduceMotion(context)) {
      position.jumpTo(clamped);
    } else {
      unawaited(
        position.animateTo(
          clamped,
          duration: ExpressiveMotion.medium,
          curve: ExpressiveMotion.effects,
        ),
      );
    }
  }

  // ==================== 构建与绘制 ====================

  Widget _buildCard(_DeckItem item, double width) {
    final entry = item.entry;
    final indent = entry.depth * NotebookDeckLayout.indentStep;
    final cardWidth = math.max(
      120.0,
      width - indent - NotebookDeckCard.paperRoom,
    );
    final current = !item.leaving && widget.isCurrent(entry);
    final desktop = AppPlatform.isDesktop;
    Widget card(VoidCallback? onLongPress) => NotebookDeckCard(
      entry: entry,
      width: entry.kind == NotebookDeckEntryKind.closedHeader
          ? width
          : cardWidth,
      current: current,
      onTap: () {
        if (entry.kind == NotebookDeckEntryKind.closedHeader) {
          widget.onToggle(entry);
          return;
        }
        unawaited(widget.controller.select(entry));
      },
      onPressChanged: (bool down) {
        if (down) {
          _motion.lift(entry.key);
        } else if (_motion.lifted == entry.key) {
          _motion.lift(null);
        }
      },
      onLongPress: onLongPress,
      onToggle:
          entry.childCount > 0 ||
              entry.kind == NotebookDeckEntryKind.closedHeader
          ? () => widget.onToggle(entry)
          : null,
    );
    final notebook = entry.notebook;
    Widget child;
    if (notebook == null || item.leaving) {
      child = card(null);
    } else {
      final l10n = context.l10n;
      child = ExpressiveMenuAnchor(
        placement: ExpressiveMenuPlacement.start,
        menuChildren: <Widget>[
          for (final action in notebookQuickActions(notebook))
            ExpressiveMenuItem(
              leadingIcon: FaIcon(notebookActionIcon(action)),
              destructive: action == NotebookAction.delete,
              onPressed: () => unawaited(
                runNotebookAction(
                  context,
                  ref,
                  notebook: notebook,
                  action: action,
                ),
              ),
              child: Text(notebookActionLabel(l10n, action)),
            ),
        ],
        builder: (BuildContext context, ExpressiveMenuAnchorState menu, _) =>
            card(menu.open),
      );
    }
    if (desktop && !item.leaving) {
      child = MouseRegion(
        onEnter: (_) => _motion.lift(entry.key),
        onExit: (_) {
          if (_motion.lifted == entry.key) _motion.lift(null);
        },
        child: child,
      );
    }
    return KeyedSubtree(
      key: ValueKey<String>(entry.key),
      child: RepaintBoundary(
        child: item.leaving ? IgnorePointer(child: child) : child,
      ),
    );
  }

  /// 逐帧摆放所有卡片（Flow 的绘制回调）。
  void _paintCards(FlowPaintingContext context, double width) {
    final items = _items;
    final count = items.length;
    final pixels = _scroll.hasClients ? _scroll.position.pixels : 0.0;
    final viewport = context.size.height;
    final maxScroll = math.max(0.0, widget.layout.extent - viewport);
    final reveal = widget.reveal.value;
    final rtl = _rtl;
    final sign = rtl ? -1.0 : 1.0;
    final shakeT = _shake.value;

    // 绘制顺序：按条目顺序，子本一律画在上级之前——展开时从上级底下抽出、
    // 收起时滑回它底下；展开的上级整张露出、子本排在它下面（见
    // [NotebookDeckLayout]），静止时两者不重叠，抽出途中也不用换层。
    final z = List<double>.filled(count, 0);
    final keyIndex = <String, int>{};
    for (var i = 0; i < count; i++) {
      final item = items[i];
      keyIndex[item.key] = i;
      final parent = item.entry.parentKey;
      final parentIndex = parent == null ? null : keyIndex[parent];
      z[i] = parentIndex != null
          ? z[parentIndex] - 0.5 + i * 1e-4
          : i.toDouble();
    }
    final order = List<int>.generate(count, (i) => i)
      ..sort((a, b) => z[a].compareTo(z[b]));

    final rects = List<Rect>.filled(count, Rect.zero);
    var shift = 0.0;
    final shifts = List<double>.filled(count, 0);
    for (var i = 0; i < count; i++) {
      shifts[i] = shift;
      final key = items[i].key;
      final raised = math.max(_motion.liftOf(key), _motion.pullOf(key));
      shift += NotebookDeckLayout.revealLift * raised * _motion.appearOf(key);
    }
    for (final i in order) {
      final item = items[i];
      final entry = item.entry;
      final key = item.key;
      final height = NotebookDeckLayout.heightOf(entry);
      final top = _motion.top(key) ?? 0;
      final placement = NotebookDeckLayout.place(
        index: i,
        count: count,
        top: top,
        scroll: pixels,
        maxScroll: maxScroll,
        liftShift: shifts[i],
      );
      final lift = _motion.liftOf(key);
      final pull = _motion.pullOf(key);
      final appear = _motion.appearOf(key);
      final current = !item.leaving && widget.isCurrent(entry);
      // 发牌：第 slot 张在 [0.2 + 0.05·slot, 0.7 + 0.05·slot] 里落位；前 40%
      // 的行程里就变成不透明，叠着的卡片不互相透出。
      final slot = (i - _dealAnchor).clamp(0, NotebookDeck.dealSlots);
      final dealStart = 0.2 + 0.05 * slot;
      final dealRaw = ((reveal - dealStart) / 0.5).clamp(0.0, 1.0);
      final deal = Curves.easeOutCubic.transform(dealRaw);
      final childWidth = context.getChildSize(i)?.width ?? width;
      final indent = entry.depth * NotebookDeckLayout.indentStep;
      var dx =
          indent + (current ? 12 : 0) + 6 * lift + 16 * pull - 40 * (1 - deal);
      if (key == _shakeKey && shakeT > 0 && shakeT < 1) {
        dx += math.sin(shakeT * math.pi * 6) * 8 * (1 - shakeT);
      }
      final x = rtl ? width - childWidth - dx : dx;
      final y = placement.y;
      final scale = placement.scale * (1 + 0.02 * lift + 0.03 * pull);
      final angle = -4 * math.pi / 180 * (1 - deal) * sign;
      final opacity =
          (placement.opacity * appear * (dealRaw / 0.4).clamp(0.0, 1.0)).clamp(
            0.0,
            1.0,
          );
      final pivotX = rtl ? childWidth : 0.0;
      final transform = Matrix4.translationValues(x, y, 0)
        ..translateByDouble(pivotX, height / 2, 0, 1)
        ..rotateZ(angle)
        ..translateByDouble(-pivotX, -height / 2, 0, 1)
        ..translateByDouble(childWidth / 2, 0, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1)
        ..translateByDouble(-childWidth / 2, 0, 0, 1);
      rects[i] = Rect.fromLTWH(
        x + childWidth / 2 * (1 - scale),
        y,
        childWidth * scale,
        height * scale,
      );
      if (opacity <= 0.001) continue;
      context.paintChild(i, transform: transform, opacity: opacity);
    }
    _rects = rects;
    _paintOrder = order;
  }

  @override
  Widget build(BuildContext context) {
    _rtl = Directionality.of(context) == TextDirection.rtl;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _handleKey,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final width = constraints.maxWidth;
          return Scrollable(
            controller: _scroll,
            axisDirection: AxisDirection.down,
            // 卡组内固定用 Bouncing：拉过头时卡片间距要像弹簧一样被拉开
            // （见 [NotebookDeckLayout.place]），夹住的物理拿不到越界量。
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            scrollBehavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false, overscroll: false),
            viewportBuilder: (BuildContext context, ViewportOffset offset) =>
                NotebookDeckViewport(
                  key: _viewportKey,
                  offset: offset,
                  extent: widget.layout.extent,
                  child: Flow(
                    clipBehavior: Clip.none,
                    delegate: _DeckFlowDelegate(
                      state: this,
                      width: width,
                      repaint: Listenable.merge(<Listenable>[
                        offset,
                        _motion,
                        widget.reveal,
                        _shake,
                      ]),
                    ),
                    children: <Widget>[
                      for (final item in _items) _buildCard(item, width),
                    ],
                  ),
                ),
          );
        },
      ),
    );
  }
}

class _DeckFlowDelegate extends FlowDelegate {
  _DeckFlowDelegate({
    required this.state,
    required this.width,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final _NotebookDeckState state;
  final double width;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    // 子项自己定尺寸（卡片宽度含缩进计算，标题条高度不同）；给松约束。
    return BoxConstraints.loose(Size(width, double.infinity));
  }

  @override
  void paintChildren(FlowPaintingContext context) =>
      state._paintCards(context, width);

  @override
  bool shouldRelayout(covariant _DeckFlowDelegate oldDelegate) =>
      oldDelegate.width != width;

  @override
  bool shouldRepaint(covariant _DeckFlowDelegate oldDelegate) => true;
}
