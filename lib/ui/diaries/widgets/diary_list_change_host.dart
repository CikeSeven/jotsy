import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/container_transform/morph_landing.dart';
import '../../widgets/list_make_room.dart';
import '../controllers/diary_list_switch_motion.dart';

/// 日记列表的数据变化动效：列表就在眼前换数据时（双栏里边写边存、同步、
/// 批量改标签、撤销……），卡片不再瞬间跳到新位置。
///
/// 输入：宿主给的有序日记 [diaries]、宿主自己在演进出场的日记
/// （[pendingHideDiaryIds] / [appearingDiaryIds]）；输出：交给 [builder] 的
/// [DiaryListChangeFrame]（实际要排版的列表，含正在退场的项、本组件加的
/// 退场 / 入场标记与让位控制器）。副作用：换数据时驱动 [MakeRoomController]。
///
/// 一次变化拆成三件事：
/// - 移动与改高：仍在列表里的项经 [MakeRoomController.animateLayoutChange]
///   从原位置以弹簧滑到新位置；
/// - 移除：数据里没了、此前挂在树上的项先留在原位置退场（由调用方按
///   [DiaryListChangeFrame.exiting] 收起或淡出），[duration] 后再拿掉，其余
///   项随之让位。宿主自己收起过的（pendingHide）与刻意直接拿掉的
///   （[hiddenDiaryIds]）直接拿掉、只让位；
/// - 插入：落在此前已挂载区间里、此前不在树上的项（新日记，或从屏外换位
///   进来的）入场（[DiaryListChangeFrame.entering]）。宿主自己在演出现的
///   （appearing）不重复。
///
/// 直接换成新列表、不做动效的情况：首次有数据、只在末尾追加（翻页）、
/// 列表整体切换途中（[switchMotion] 不在静止态，由它级联入场）、新建日记
/// 正落进列表（[MorphLandingSession]，由让位动画处理）、列表不在屏上（被别
/// 的页面盖住，TickerMode 关闭）以及减少动态效果。
class DiaryListChangeHost extends StatefulWidget {
  const DiaryListChangeHost({
    super.key,
    required this.diaries,
    required this.duration,
    required this.builder,
    this.pendingHideDiaryIds = const <String>{},
    this.appearingDiaryIds = const <String>{},
    this.hiddenDiaryIds = const <String>{},
    this.makeRoom,
    this.switchMotion,
  });

  final List<DiaryWithTags> diaries;

  /// 单项进出场的时长（与调用方的 `ListItemPresence` 一致）：退场项过了
  /// 这么久才拿掉。
  final Duration duration;
  final Set<String> pendingHideDiaryIds;
  final Set<String> appearingDiaryIds;

  /// 宿主刻意直接拿掉的日记：从列表里消失时不留退场项，只让位。
  final Set<String> hiddenDiaryIds;

  /// 宿主的让位控制器（日记页还用它演新建日记落进列表）；null 时本组件
  /// 自己建一个。
  final MakeRoomController? makeRoom;
  final DiaryListSwitchMotion? switchMotion;
  final Widget Function(BuildContext context, DiaryListChangeFrame frame)
  builder;

  @override
  State<DiaryListChangeHost> createState() => _DiaryListChangeHostState();
}

/// 一次构建要排版的列表，见 [DiaryListChangeHost]。
class DiaryListChangeFrame {
  DiaryListChangeFrame({
    required this.items,
    this.exiting = const <String>{},
    this.entering = const <String>{},
    this.makeRoom,
  }) : _sourceIndexes = exiting.isEmpty ? null : _indexesOf(items, exiting);

  /// 要排版的日记：宿主的列表，退场项插在它们原来的位置上。
  final List<DiaryWithTags> items;

  /// 数据里已经没有、正在原位置退场的日记：不可点按，到点拿掉。
  final Set<String> exiting;

  /// 刚出现、正在入场的日记（只读视图，到点清空）。
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

  static List<int> _indexesOf(List<DiaryWithTags> items, Set<String> exiting) {
    var source = 0;
    return <int>[
      for (final item in items)
        exiting.contains(item.diary.diaryId) ? -1 : source++,
    ];
  }
}

class _DiaryListChangeHostState extends State<DiaryListChangeHost>
    with SingleTickerProviderStateMixin {
  /// 同时最多留几张退场项：全选后删除几千篇时不逐张演，直接拿掉、只让位。
  static const int _maxExiting = 40;

  MakeRoomController? _ownMakeRoom;
  MakeRoomController get _makeRoom =>
      widget.makeRoom ?? (_ownMakeRoom ??= MakeRoomController(vsync: this));

  late List<DiaryWithTags> _items = widget.diaries;
  final Set<String> _exiting = <String>{};

  /// 入场标记不经 setState 清除：它只在条目首次构建时起作用，清除后新建
  /// 的条目（滚出再滚回来）不再重演；[DiaryListChangeFrame.entering] 是它
  /// 的只读视图。
  final Set<String> _entering = <String>{};
  final Set<Timer> _timers = <Timer>{};

  @override
  void didUpdateWidget(covariant DiaryListChangeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.diaries, widget.diaries)) {
      _sync(oldWidget);
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
      (widget.switchMotion?.isIdle ?? true) &&
      MorphLandingSession.current.value == null &&
      TickerMode.getValuesNotifier(context).value.enabled;

  void _sync(DiaryListChangeHost oldWidget) {
    final previous = _items;
    final next = widget.diaries;
    if (_exiting.isEmpty && _isAppend(previous, next)) {
      // 翻页：后面接上的项在屏外，已有的项不动。
      _items = next;
      return;
    }
    if (previous.isEmpty || !_canAnimate) {
      _items = next;
      _exiting.clear();
      _entering.clear();
      return;
    }

    // 换数据之前记下各项的位置（此刻还是上一帧的布局）。
    final captured = _makeRoom.animateLayoutChange();
    final nextIds = <String>{for (final item in next) item.diary.diaryId};

    // 退场途中又回来的：照常排在新位置，撤掉退场标记后自己展开回来。
    _exiting.removeWhere(nextIds.contains);
    final removed = <String>{};
    var allCaptured = true;
    for (final item in previous) {
      final id = item.diary.diaryId;
      if (!captured.contains(id)) allCaptured = false;
      if (nextIds.contains(id) || _exiting.contains(id)) continue;
      // 宿主收起过的已经看不见了；没挂在树上的本来就看不见。
      if (oldWidget.pendingHideDiaryIds.contains(id) ||
          widget.pendingHideDiaryIds.contains(id) ||
          widget.hiddenDiaryIds.contains(id) ||
          !captured.contains(id)) {
        continue;
      }
      removed.add(id);
    }
    if (_exiting.length + removed.length <= _maxExiting) {
      _exiting.addAll(removed);
      if (removed.isNotEmpty) _later(() => _dropExiting(removed));
    }
    _items = _exiting.isEmpty ? next : _withExiting(previous, next, nextIds);

    final entering = _enteringIds(next, captured, allCaptured: allCaptured);
    if (entering.isNotEmpty) {
      _entering.addAll(entering);
      _later(() => _entering.removeAll(entering));
    }
  }

  /// [next] 是否只是在 [previous] 末尾接上了更多项。
  static bool _isAppend(
    List<DiaryWithTags> previous,
    List<DiaryWithTags> next,
  ) {
    if (next.length <= previous.length) return false;
    for (var index = 0; index < previous.length; index++) {
      if (previous[index].diary.diaryId != next[index].diary.diaryId) {
        return false;
      }
    }
    return true;
  }

  /// 要入场的项：此前不在树上、落在此前已挂载的区间里（最后一个挂载过的
  /// 项之前；此前整张列表都挂载着时不限位置）。此后的项本来就在屏外。
  Set<String> _enteringIds(
    List<DiaryWithTags> next,
    Set<Object> captured, {
    required bool allCaptured,
  }) {
    var end = next.length;
    if (!allCaptured) {
      end = 0;
      for (var index = 0; index < next.length; index++) {
        if (captured.contains(next[index].diary.diaryId)) end = index;
      }
    }
    return <String>{
      for (final item in next.take(end))
        if (!captured.contains(item.diary.diaryId) &&
            !widget.appearingDiaryIds.contains(item.diary.diaryId))
          item.diary.diaryId,
    };
  }

  /// 把退场项按原来的先后插回新列表：排在它原来前面、仍在列表里的那一项
  /// 之后（前面没有时排在最前）。
  List<DiaryWithTags> _withExiting(
    List<DiaryWithTags> previous,
    List<DiaryWithTags> next,
    Set<String> nextIds,
  ) {
    final merged = List<DiaryWithTags>.of(next);
    final mergedIds = <String>[for (final item in next) item.diary.diaryId];
    String? anchor;
    for (final item in previous) {
      final id = item.diary.diaryId;
      if (_exiting.contains(id)) {
        final at = anchor == null ? 0 : mergedIds.indexOf(anchor) + 1;
        merged.insert(at, item);
        mergedIds.insert(at, id);
        anchor = id;
      } else if (nextIds.contains(id)) {
        anchor = id;
      }
    }
    return merged;
  }

  /// 退场演完：拿掉这一批里仍在退场的项，其余项让位补上。
  void _dropExiting(Set<String> ids) {
    if (!mounted) return;
    final gone = ids.where(_exiting.contains).toSet();
    if (gone.isEmpty) return;
    if (_canAnimate) _makeRoom.animateLayoutChange();
    setState(() {
      _exiting.removeAll(gone);
      _items = <DiaryWithTags>[
        for (final item in _items)
          if (!gone.contains(item.diary.diaryId)) item,
      ];
    });
  }

  /// [duration] 之后执行 [action]（页面销毁时取消）。
  void _later(VoidCallback action) {
    late final Timer timer;
    timer = Timer(widget.duration, () {
      _timers.remove(timer);
      action();
    });
    _timers.add(timer);
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    DiaryListChangeFrame(
      items: _items,
      exiting: UnmodifiableSetView<String>(_exiting),
      entering: UnmodifiableSetView<String>(_entering),
      makeRoom: _makeRoom,
    ),
  );
}
