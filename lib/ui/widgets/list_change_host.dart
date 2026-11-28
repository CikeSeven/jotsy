import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../../app/theme/expressive_motion.dart';
import 'list_make_room.dart';

/// 列表的数据变化动效：列表就在眼前换数据时（边写边存、同步、批量修改、
/// 撤销……），各项不再瞬间跳到新位置。日记列表（`DiaryListChangeHost`）与
/// 待办列表共用。
///
/// 输入：宿主给的有序列表 [ListChangeHost.items] 与每项的稳定键
/// （[ListChangeHost.keyOf]），宿主自己在演进出场的项（`pendingHideKeys` /
/// `appearingKeys`）；输出：交给 [ListChangeHost.builder] 的 [ListChangeFrame]
/// （实际要排版的列表，含正在退场的项、本组件加的退场 / 入场标记与让位
/// 控制器）。副作用：换数据时驱动 [MakeRoomController]。
///
/// 一次变化拆成三件事：
/// - 移动与改高：仍在列表里的项经 [MakeRoomController.animateLayoutChange]
///   从原位置以弹簧滑到新位置；
/// - 移除：数据里没了、此前挂在树上的项先留在原位置退场（由调用方按
///   [ListChangeFrame.exiting] 收起或淡出），`duration` 后再拿掉，其余项随之
///   让位。宿主正在演收起、数据流抢先移走时继续留在原位，等宿主移出
///   `pendingHideKeys` 后立刻拿掉并让位；宿主已播完收起（移出
///   `pendingHideKeys`）或刻意直接拿掉（`hiddenKeys`）的直接拿掉、只让位；
/// - 插入：落在此前已挂载区间里、此前不在树上的项（新项，或从屏外换位进来
///   的）入场（[ListChangeFrame.entering]）。宿主自己在演出现的（appearing）
///   不重复。
///
/// 直接换成新列表、不做动效的情况：首次有数据、只在末尾追加（翻页）、列表
/// 不在屏上（被别的页面盖住，TickerMode 关闭）、减少动态效果，以及宿主的
/// [ListChangeHost.canAnimate] 说不行的时候（如列表整体切换途中）。
///
/// 键只用来对应同一项：宿主给 [MakeRoomItem] 的标签须与键相同，“此前挂在
/// 树上”按 [MakeRoomController.animateLayoutChange] 记下的标签判断。
class ListChangeHost<T> extends StatefulWidget {
  const ListChangeHost({
    super.key,
    required this.items,
    required this.keyOf,
    required this.duration,
    required this.builder,
    this.pendingHideKeys = const <String>{},
    this.appearingKeys = const <String>{},
    this.hiddenKeys = const <String>{},
    this.makeRoom,
    this.canAnimate,
  });

  final List<T> items;

  /// 每一项的稳定键（日记 id、待办行的键…）。
  final String Function(T item) keyOf;

  /// 单项进出场的时长（与调用方的 `ListItemPresence` 一致）：退场项过了
  /// 这么久才拿掉。
  final Duration duration;
  final Set<String> pendingHideKeys;
  final Set<String> appearingKeys;

  /// 宿主刻意直接拿掉的项：从列表里消失时不留退场项，只让位。
  final Set<String> hiddenKeys;

  /// 宿主的让位控制器；null 时本组件自己建一个。
  final MakeRoomController? makeRoom;

  /// 宿主额外的“此刻能不能演”（如列表整体切换途中不演）；null 时只看
  /// 减少动态效果与是否在屏上。
  final bool Function()? canAnimate;
  final Widget Function(BuildContext context, ListChangeFrame<T> frame) builder;

  @override
  State<ListChangeHost<T>> createState() => _ListChangeHostState<T>();
}

/// 一次构建要排版的列表，见 [ListChangeHost]。
class ListChangeFrame<T> {
  ListChangeFrame({
    required this.items,
    this.exiting = const <String>{},
    this.entering = const <String>{},
    this.makeRoom,
    this._sourceIndexes,
  });

  /// 要排版的项：宿主的列表，退场项插在它们原来的位置上。
  final List<T> items;

  /// 数据里已经没有、正在原位置退场的项的键：不可点按，到点拿掉。
  final Set<String> exiting;

  /// 刚出现、正在入场的项的键（只读视图，到点清空）。
  final Set<String> entering;

  /// 列表各项要包 [MakeRoomItem] 的让位控制器；null 时不包。
  final MakeRoomController? makeRoom;

  final List<int>? _sourceIndexes;

  /// [items] 第 [index] 项在宿主列表里的下标；退场项为 null。
  int? sourceIndexOf(int index) {
    final indexes = _sourceIndexes;
    if (indexes == null) return index;
    final source = indexes[index];
    return source < 0 ? null : source;
  }
}

class _ListChangeHostState<T> extends State<ListChangeHost<T>>
    with SingleTickerProviderStateMixin {
  /// 同时最多留几项退场：全选后删除几千条时不逐项演，直接拿掉、只让位。
  static const int _maxExiting = 40;

  MakeRoomController? _ownMakeRoom;
  MakeRoomController get _makeRoom =>
      widget.makeRoom ?? (_ownMakeRoom ??= MakeRoomController(vsync: this));

  late List<T> _items = widget.items;
  final Set<String> _exiting = <String>{};

  /// 宿主正在演收起（仍在 `pendingHideKeys` 里）时数据流抢先删掉的项：
  /// 留在此处继续完成收起，不另起计时器，等宿主移出 `pendingHideKeys` 时
  /// 拿掉并触发其余项让位。
  final Set<String> _hostHiding = <String>{};

  /// 入场标记不经 setState 清除：它只在条目首次构建时起作用，清除后新建
  /// 的条目（滚出再滚回来）不再重演；[ListChangeFrame.entering] 是它的只读
  /// 视图。
  final Set<String> _entering = <String>{};
  final Set<Timer> _timers = <Timer>{};

  String _keyOf(T item) => widget.keyOf(item);
  bool _isExiting(String key) =>
      _exiting.contains(key) || _hostHiding.contains(key);

  @override
  void didUpdateWidget(covariant ListChangeHost<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemsChanged = !identical(oldWidget.items, widget.items);
    if (itemsChanged) {
      _sync(oldWidget);
      return;
    }
    if (_hostHiding.isNotEmpty) {
      final released = <String>{
        for (final key in _hostHiding)
          if (!widget.pendingHideKeys.contains(key)) key,
      };
      if (released.isNotEmpty) {
        _releaseHostHiding(released);
      }
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _ownMakeRoom?.dispose();
    super.dispose();
  }

  bool get _canAnimate =>
      !ExpressiveMotion.reduceMotion(context) &&
      (widget.canAnimate?.call() ?? true) &&
      TickerMode.getValuesNotifier(context).value.enabled;

  void _sync(ListChangeHost<T> oldWidget) {
    final previous = _items;
    final next = widget.items;
    if (_exiting.isEmpty && _hostHiding.isEmpty && _isAppend(previous, next)) {
      // 翻页：后面接上的项在屏外，已有的项不动。
      _items = next;
      return;
    }
    if (previous.isEmpty || !_canAnimate) {
      _items = next;
      _exiting.clear();
      _hostHiding.clear();
      _entering.clear();
      return;
    }

    // 换数据之前记下各项的位置（此刻还是上一帧的布局）。
    final captured = _makeRoom.animateLayoutChange();
    final nextKeys = <String>{for (final item in next) _keyOf(item)};

    // 退场途中又回来的：照常排在新位置，撤掉退场标记后自己展开回来；
    // 宿主已结束收起（移出 pendingHideKeys）的同步释放。
    _exiting.removeWhere(nextKeys.contains);
    _hostHiding.removeWhere(
      (String key) =>
          nextKeys.contains(key) || !widget.pendingHideKeys.contains(key),
    );
    final removed = <String>{};
    final startedHostHiding = <String>{};
    var allCaptured = true;
    for (final item in previous) {
      final key = _keyOf(item);
      if (!captured.contains(key)) allCaptured = false;
      if (nextKeys.contains(key) || _isExiting(key)) continue;
      // 刻意直接拿掉的或没挂在树上的直接跳过。
      if (widget.hiddenKeys.contains(key) || !captured.contains(key)) {
        continue;
      }
      if (widget.pendingHideKeys.contains(key)) {
        // 宿主正在收起、数据流抢先移走：保留原位直到宿主移出 pendingHideKeys，
        // 避免收起动画播到一半被直接截断。
        startedHostHiding.add(key);
        continue;
      }
      if (oldWidget.pendingHideKeys.contains(key)) {
        // 宿主已播完收起并移出 pendingHideKeys：直接拿掉、只让位。
        continue;
      }
      removed.add(key);
    }
    if (_exiting.length + _hostHiding.length + startedHostHiding.length <=
        _maxExiting) {
      _hostHiding.addAll(startedHostHiding);
    }
    if (_exiting.length + _hostHiding.length + removed.length <= _maxExiting) {
      _exiting.addAll(removed);
      if (removed.isNotEmpty) _later(() => _dropExiting(removed));
    }
    _items = _exiting.isEmpty && _hostHiding.isEmpty
        ? next
        : _withExiting(previous, next, nextKeys);

    final leadingCaptured = captured.contains(_keyOf(previous.first));
    final entering = _enteringKeys(
      next,
      captured,
      allCaptured: allCaptured,
      leadingCaptured: leadingCaptured,
    );
    if (entering.isNotEmpty) {
      _entering.addAll(entering);
      _later(() => _entering.removeAll(entering));
    }
  }

  /// 宿主收起计时结束并移出 `pendingHideKeys`：拿掉这些项，其余项让位补上。
  void _releaseHostHiding(Set<String> released) {
    if (_canAnimate) _makeRoom.animateLayoutChange();
    _hostHiding.removeAll(released);
    _items = <T>[
      for (final item in _items)
        if (!released.contains(_keyOf(item))) item,
    ];
  }

  /// [next] 是否只是在 [previous] 末尾接上了更多项。
  bool _isAppend(List<T> previous, List<T> next) {
    if (next.length <= previous.length) return false;
    for (var index = 0; index < previous.length; index++) {
      if (_keyOf(previous[index]) != _keyOf(next[index])) return false;
    }
    return true;
  }

  /// 要入场的项：此前不在树上、落在此前已挂载的区间里（[start, end)）。
  ///
  /// - 此前整张列表都挂载着（[allCaptured]）时不限区间；
  /// - 列表已向下滚动（首项不在树上，[leadingCaptured] 为 false）时，区间起点
  ///   从第一个仍挂载在树上的项算起，视口上方的屏外项不标入场——否则上滑或
  ///   锚点校正刚拉出的前导项会从高度 0 展开、把列表拉跳。
  Set<String> _enteringKeys(
    List<T> next,
    Set<Object> captured, {
    required bool allCaptured,
    required bool leadingCaptured,
  }) {
    var start = 0;
    var end = next.length;
    if (!allCaptured) {
      var first = -1;
      var last = 0;
      for (var index = 0; index < next.length; index++) {
        if (captured.contains(_keyOf(next[index]))) {
          if (first < 0) first = index;
          last = index;
        }
      }
      start = leadingCaptured || first < 0 ? 0 : first;
      end = last;
    }
    return <String>{
      for (var index = start; index < end; index++)
        if (!captured.contains(_keyOf(next[index])) &&
            !widget.appearingKeys.contains(_keyOf(next[index])))
          _keyOf(next[index]),
    };
  }

  /// 把退场项按原来的先后插回新列表：排在它原来前面、仍在列表里的那一项
  /// 之后（前面没有时排在最前）。
  List<T> _withExiting(List<T> previous, List<T> next, Set<String> nextKeys) {
    final merged = List<T>.of(next);
    final mergedKeys = <String>[for (final item in next) _keyOf(item)];
    String? anchor;
    for (final item in previous) {
      final key = _keyOf(item);
      if (_isExiting(key)) {
        final at = anchor == null ? 0 : mergedKeys.indexOf(anchor) + 1;
        merged.insert(at, item);
        mergedKeys.insert(at, key);
        anchor = key;
      } else if (nextKeys.contains(key)) {
        anchor = key;
      }
    }
    return merged;
  }

  /// 退场演完：拿掉这一批里仍在退场的项，其余项让位补上。
  void _dropExiting(Set<String> keys) {
    if (!mounted) return;
    final gone = keys.where(_exiting.contains).toSet();
    if (gone.isEmpty) return;
    if (_canAnimate) _makeRoom.animateLayoutChange();
    setState(() {
      _exiting.removeAll(gone);
      _items = <T>[
        for (final item in _items)
          if (!gone.contains(_keyOf(item))) item,
      ];
    });
  }

  /// `duration` 之后执行 [action]（页面销毁时取消）。
  void _later(VoidCallback action) {
    late final Timer timer;
    timer = Timer(widget.duration, () {
      _timers.remove(timer);
      action();
    });
    _timers.add(timer);
  }

  /// [_items] 里每一项在宿主列表里的下标，退场项为 -1；没有退场项时为
  /// null（下标不变）。
  List<int>? _sourceIndexes() {
    if (_exiting.isEmpty && _hostHiding.isEmpty) return null;
    var source = 0;
    return <int>[
      for (final item in _items) _isExiting(_keyOf(item)) ? -1 : source++,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final exiting = _hostHiding.isEmpty
        ? UnmodifiableSetView<String>(_exiting)
        : UnmodifiableSetView<String>(<String>{..._exiting, ..._hostHiding});
    return widget.builder(
      context,
      ListChangeFrame<T>(
        items: _items,
        exiting: exiting,
        entering: UnmodifiableSetView<String>(_entering),
        makeRoom: _makeRoom,
        sourceIndexes: _sourceIndexes(),
      ),
    );
  }
}
