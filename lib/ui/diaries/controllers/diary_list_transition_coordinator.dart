// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/diaries_page.dart';

/// 日记列表过渡协调器。
///
/// 职责边界：
/// - 处理筛选切换的进出场节奏（冻结旧列表、退场、等待新数据首帧、定位、
///   级联入场，见 [DiaryListSwitchMotion]）；
/// - 维护删除/归档过程中的隐藏与出现动画状态；
/// - 统一管理相关计时器，避免页面销毁后回调触发。
class DiaryListTransitionCoordinator {
  const DiaryListTransitionCoordinator(this._state);

  /// 页面状态引用，内部动画状态都托管在页面 State 字段里。
  final _DiariesPage _state;

  /// 新查询首帧数据的最长等待时间；超时后照常入场（退化为旧行为），
  /// 避免查询异常挂起时列表一直不可见。
  static const Duration _maxFreshPageWait = Duration(milliseconds: 600);

  /// 新建日记放出的兜底超时（非动画计时）：上层路由退场被打断、或新卡片不在
  /// 当前筛选窗口里时，到点仍放出 / 清除出现标记。
  static const Duration _createdRevealTimeout = Duration(milliseconds: 1200);

  /// 应用筛选变更并启动列表过渡。
  ///
  /// 时序：
  /// 1) 冻结当前展示列表（并记下此刻标签条上的位置，见 [tagStripPosition]），
  ///    然后立即写入筛选（标签选中态下一帧即反馈）；
  /// 2) 后台过渡：退场 -> 等新查询首帧数据 -> 定位 -> 换数据 -> 级联入场
  ///    （见 [DiaryListSwitchMotion]）；
  /// 3) 过渡途中再次变更只会递增 generation，循环会继续处理最新一轮，
  ///    且只为最新结果入场，不会把中间态或旧数据露出来。
  ///
  /// [directional] 为 true（点标签、清空标签）时按冻结时与此刻的标签条位置
  /// 定左右方向（连点 A→B→C 按 A→C 算）；其余变更（长按多选、排序、日记本
  /// 与章节）没有左右之分，纵向进出。
  ///
  /// [scrollToTop] 为 true 时，换数据的同一帧让列表回到最顶（见
  /// [_jumpListToTop]）；[scrollToListStart] 为 true 时只回到列表开头、刊头
  /// 保持原状（见 [jumpDiaryListToStart]）。两个标记都跨轮保留，期间又有
  /// 变更也会在最终换数据时生效，同时置位时回到最顶。
  void queueFilterMutation(
    VoidCallback mutation, {
    bool scrollToTop = false,
    bool scrollToListStart = false,
    bool directional = false,
  }) {
    if (_state._heldDisplayedItems == null) {
      _state._heldDisplayedItems = _state._lastDisplayedItems;
      _state._heldTagStripPosition = _currentTagStripPosition();
    }
    _state._filterMutationGeneration++;
    if (scrollToTop) {
      _state._scrollToTopOnFilterRelease = true;
    }
    if (scrollToListStart) {
      _state._scrollToListStartOnFilterRelease = true;
    }
    mutation();
    _state._listSwitchDirection = directional
        ? tagSwitchDirection(
            _state._heldTagStripPosition,
            _currentTagStripPosition(),
            Directionality.of(_state.context),
          )
        : 0;
    _state._queuedFilterTransition ??= _runFilterTransition();
  }

  /// 当前筛选在标签条上的位置（按标签条此刻的显示顺序）。
  int? _currentTagStripPosition() => tagStripPosition(
    _state.ref.read(diaryFilterProvider).selectedTagIds,
    <int>[for (final tag in _state._cachedTagFilters) tag.id],
  );

  Future<void> _runFilterTransition() async {
    var settledGeneration = -1;
    try {
      while (_state.mounted &&
          settledGeneration != _state._filterMutationGeneration) {
        final generation = _state._filterMutationGeneration;
        await _exitListIfNeeded();
        if (!_state.mounted) {
          return;
        }
        // 筛选写入后要到下一帧重建才会产生新的分页 query。
        await WidgetsBinding.instance.endOfFrame;
        if (!_state.mounted) {
          return;
        }
        await _waitForFreshPage();
        if (!_state.mounted) {
          return;
        }
        if (generation != _state._filterMutationGeneration) {
          // 等待期间又有新筛选：保持退场与冻结，直接处理最新一轮。
          continue;
        }
        _positionListForRelease();
        // 入场归零与换数据落在同一帧：新列表第一帧就是不可见的起点。
        final animate = !_reduceMotion;
        if (animate) {
          _state._listSwitchMotion.prepareEnter(_state._listSwitchDirection);
        } else {
          _state._listSwitchMotion.settle();
        }
        _state.setState(() => _state._heldDisplayedItems = null);
        await WidgetsBinding.instance.endOfFrame;
        if (!_state.mounted) {
          return;
        }
        // 入场不等它走完就结束本轮：之后再有变更立即开始新一轮退场，从入场
        // 进行到一半的画面出发，而不是等入场播完。
        if (animate) {
          unawaited(_state._listSwitchMotion.enter());
        }
        settledGeneration = generation;
      }
    } finally {
      _state._queuedFilterTransition = null;
    }
  }

  /// 换数据之前的定位：回到最顶，或回到列表开头（保持刊头原状）。
  void _positionListForRelease() {
    final toTop = _state._scrollToTopOnFilterRelease;
    final toStart = _state._scrollToListStartOnFilterRelease;
    _state._scrollToTopOnFilterRelease = false;
    _state._scrollToListStartOnFilterRelease = false;
    if (toTop) {
      _jumpListToTop();
      return;
    }
    if (!toStart) {
      return;
    }
    final tagBarContext = _state._listScrollContext;
    final listSliver = _state._listSliverKey.currentContext?.findRenderObject();
    if (tagBarContext == null ||
        !tagBarContext.mounted ||
        listSliver is! RenderSliver) {
      return;
    }
    jumpDiaryListToStart(
      tagBarContext: tagBarContext,
      listSliver: listSliver,
      leadingGap: HomeTopBarSurface.contentGapOf(_state.context),
    );
  }

  /// 等待当前分页 query 拿到首帧数据（或错误）。
  ///
  /// family 换 key 后首帧必为 loading；若只等一帧就入场，入场的会是旧列表，
  /// 新数据随后在半透明状态下硬替换。已缓存的 query 会经 fireImmediately
  /// 立刻完成。页面销毁时由 [dispose] 提前完成，避免悬挂计时器。
  Future<void> _waitForFreshPage() async {
    final query = _state._currentDiaryPageQuery;
    if (query == null) {
      return;
    }
    final waiter = Completer<void>();
    _state._filterQueryWaiter = waiter;
    final subscription = _state.ref
        .listenManual<AsyncValue<PagedDiariesResult>>(
          pagedDiariesProvider(query),
          (previous, next) {
            if ((next.hasValue || next.hasError) && !waiter.isCompleted) {
              waiter.complete();
            }
          },
          fireImmediately: true,
        );
    try {
      await waiter.future.timeout(_maxFreshPageWait, onTimeout: () {});
    } finally {
      subscription.close();
      if (identical(_state._filterQueryWaiter, waiter)) {
        _state._filterQueryWaiter = null;
      }
    }
  }

  /// 让主列表直接跳回顶部（不滚动）。
  ///
  /// 只在换数据前调用：跳转与换入新数据落在同一帧，列表此时已退场，看不到
  /// 跳动；减少动画时没有退场，两者也合成一次变化，而不是旧列表先跳一下。
  /// 主列表挂在 Tab 级 PrimaryScrollController 上，可能同时挂着多个位置
  /// （布局切换交叉期间），逐个处理。
  void _jumpListToTop() {
    final controller = PrimaryScrollController.maybeOf(_state.context);
    if (controller == null || !controller.hasClients) {
      return;
    }
    for (final position in controller.positions.toList(growable: false)) {
      position.jumpTo(position.minScrollExtent);
    }
  }

  /// 切换布局：退场 → 应用 [apply]（换布局）→ 下一帧级联入场（纵向）。
  ///
  /// 布局必须在退场完成后再换：先换再退场等于硬切后补一个淡出。入场归零与
  /// 换布局同一帧，新布局第一帧不可见。减少动画或筛选过渡正在进行时直接
  /// 应用（后者换数据时会自行入场）。
  Future<void> switchLayout(VoidCallback apply) async {
    if (_reduceMotion || _state._queuedFilterTransition != null) {
      apply();
      return;
    }
    await _state._listSwitchMotion.exit(0);
    if (!_state.mounted) {
      return;
    }
    _state._listSwitchMotion.prepareEnter(0);
    apply();
    await WidgetsBinding.instance.endOfFrame;
    if (!_state.mounted) {
      return;
    }
    unawaited(_state._listSwitchMotion.enter());
  }

  /// 系统开启“减少动画”时不做进出场，只保留“数据到齐再替换”。
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(_state.context);

  /// 列表可见时执行退场（方向取本轮的 [_DiariesPage._listSwitchDirection]）。
  Future<void> _exitListIfNeeded() async {
    if (!_state.mounted || _reduceMotion) {
      return;
    }
    await _state._listSwitchMotion.exit(_state._listSwitchDirection);
  }

  /// 为即将删除/归档的项启动收起动画计时器。
  ///
  /// 同一批共用一个计时器（[_HideBatch]）：全选后批量归档 / 删除可能有几千
  /// 篇（多数还没加载、不会被构建），逐篇各起一个计时器、到点各自 setState
  /// 没有必要；到点时一次 setState 把这一批仍在等待的都转为隐藏。
  void startHideAnimations(Iterable<String> diaryIds) {
    final targetIds = diaryIds.toSet();
    if (targetIds.isEmpty) {
      return;
    }

    final batch = _HideBatch(<String>{...targetIds});
    for (final diaryId in targetIds) {
      _state._appearingTimers.remove(diaryId)?.cancel();
      _state._pendingHideTimers.remove(diaryId)?.release(diaryId);
      _state._pendingHideTimers[diaryId] = batch;
    }
    batch.timer = Timer(_DiariesPage._listItemTransitionDuration, () {
      // 期间被撤销 / 清理的 id 已从 batch.ids 里释放，剩下的才转为隐藏。
      final fired = batch.ids.toList(growable: false);
      for (final diaryId in fired) {
        _state._pendingHideTimers.remove(diaryId);
      }
      if (!_state.mounted || fired.isEmpty) {
        return;
      }
      _state.setState(() {
        _state._pendingHideDiaryIds.removeAll(fired);
        _state._optimisticHiddenDiaryIds.addAll(fired);
      });
    });

    _state.setState(() {
      _state._appearingDiaryIds.removeAll(targetIds);
      _state._pendingHideDiaryIds.addAll(targetIds);
    });
  }

  /// 立即隐藏指定日记项（无等待动画，常用于回滚场景）。
  void hideDiariesImmediately(Iterable<String> diaryIds) {
    final targetIds = diaryIds.toSet();
    if (targetIds.isEmpty) {
      return;
    }
    clearTransitionTimers(targetIds);
    _state.setState(() {
      _state._pendingHideDiaryIds.removeAll(targetIds);
      _state._appearingDiaryIds.removeAll(targetIds);
      _state._optimisticHiddenDiaryIds.addAll(targetIds);
    });
  }

  /// 撤销后让指定日记重新出现。
  ///
  /// `animate=true` 时先进入“出现动画集合”，动画结束自动移除标记。
  void revealDiaries(Iterable<String> diaryIds, {required bool animate}) {
    final targetIds = diaryIds.toSet();
    if (targetIds.isEmpty) {
      return;
    }

    for (final diaryId in targetIds) {
      _state._pendingHideTimers.remove(diaryId)?.release(diaryId);
      _state._appearingTimers.remove(diaryId)?.cancel();
    }

    _state.setState(() {
      _state._pendingHideDiaryIds.removeAll(targetIds);
      _state._optimisticHiddenDiaryIds.removeAll(targetIds);
      if (animate) {
        _state._appearingDiaryIds.addAll(targetIds);
      } else {
        _state._appearingDiaryIds.removeAll(targetIds);
      }
    });
  }

  /// 新建日记发布后回到列表：等上层路由退场结束，再让新卡片展开出现。
  ///
  /// 退场途中列表正随路由滑入，若此时插入卡片，展开动画会和转场叠在一起、
  /// 大半被遮住；先把它压住不参与构建，本页所在路由的 secondaryAnimation 回到
  /// dismissed（上层退场结束）后再以出现动画放出。减少动画时直接显示。
  void revealCreatedDiary(String diaryId) {
    final secondary = ModalRoute.of(_state.context)?.secondaryAnimation;
    if (ExpressiveMotion.reduceMotion(_state.context) ||
        secondary == null ||
        secondary.isDismissed) {
      _revealCreatedDiary(diaryId);
      return;
    }
    _state.setState(() => _state._optimisticHiddenDiaryIds.add(diaryId));
    var released = false;
    late final AnimationStatusListener listener;
    void release() {
      if (released) {
        return;
      }
      released = true;
      secondary.removeStatusListener(listener);
      _state._appearingTimers.remove(diaryId)?.cancel();
      if (_state.mounted) {
        _revealCreatedDiary(diaryId);
      }
    }

    listener = (AnimationStatus status) {
      if (status.isDismissed) {
        release();
      }
    };
    secondary.addStatusListener(listener);
    _state._appearingTimers.remove(diaryId)?.cancel();
    _state._appearingTimers[diaryId] = Timer(_createdRevealTimeout, release);
  }

  void _revealCreatedDiary(String diaryId) {
    revealDiaries(<String>[
      diaryId,
    ], animate: !ExpressiveMotion.reduceMotion(_state.context));
    // 新日记可能不在当前筛选/排序窗口里，永远不会被构建；到点清除出现标记，
    // 免得之后某次筛选变化时它意外播放出现动画。已经可见时 syncAppearingTimers
    // 会因这里已有计时器而跳过，标记晚一点清除不影响已播完的动画。
    _state._appearingTimers[diaryId] = Timer(_createdRevealTimeout, () {
      _state._appearingTimers.remove(diaryId);
      if (_state.mounted) {
        _state.setState(() => _state._appearingDiaryIds.remove(diaryId));
      }
    });
  }

  /// 清理指定日记项关联的过渡计时器，避免悬挂回调。
  void clearTransitionTimers(Iterable<String> diaryIds) {
    for (final diaryId in diaryIds) {
      _state._pendingHideTimers.remove(diaryId)?.release(diaryId);
      _state._appearingTimers.remove(diaryId)?.cancel();
    }
  }

  /// 与最新可见数据同步“出现动画”计时器集合，清理失效 ID。
  void syncAppearingTimers(List<DiaryWithTags> visibleItems) {
    if (_state._appearingDiaryIds.isEmpty) {
      return;
    }
    final visibleIds = visibleItems
        .map((DiaryWithTags item) => item.diary.diaryId)
        .toSet();
    final targetIds = _state._appearingDiaryIds.intersection(visibleIds);
    if (targetIds.isEmpty) {
      return;
    }

    for (final diaryId in targetIds) {
      if (_state._appearingTimers.containsKey(diaryId)) {
        continue;
      }
      _state._appearingTimers[diaryId] = Timer(
        _DiariesPage._listItemTransitionDuration,
        () {
          _state._appearingTimers.remove(diaryId);
          if (!_state.mounted) {
            return;
          }
          _state.setState(() {
            _state._appearingDiaryIds.remove(diaryId);
          });
        },
      );
    }
  }

  /// 页面销毁时释放所有动画计时器。
  void dispose() {
    final waiter = _state._filterQueryWaiter;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
    for (final batch in _state._pendingHideTimers.values) {
      batch.timer.cancel();
    }
    _state._pendingHideTimers.clear();
    for (final timer in _state._appearingTimers.values) {
      timer.cancel();
    }
    _state._appearingTimers.clear();
  }
}

/// 一批收起动画共用的计时器（见 [DiaryListTransitionCoordinator.startHideAnimations]）。
///
/// [ids] 为这一批里仍在等待收起的日记；某篇被撤销或清理时 [release] 把它
/// 拿出，整批都拿空时取消计时器，不留悬挂回调。
class _HideBatch {
  _HideBatch(this.ids);

  final Set<String> ids;
  late final Timer timer;

  void release(String diaryId) {
    if (ids.remove(diaryId) && ids.isEmpty) {
      timer.cancel();
    }
  }
}
