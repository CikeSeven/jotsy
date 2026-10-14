// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/diaries_page.dart';

/// 日记列表过渡协调器。
///
/// 职责边界：
/// - 处理筛选切换的淡入淡出节奏（冻结旧列表、等待新数据首帧再淡入）；
/// - 维护删除/归档过程中的隐藏与出现动画状态；
/// - 统一管理相关计时器，避免页面销毁后回调触发。
class DiaryListTransitionCoordinator {
  const DiaryListTransitionCoordinator(this._state);

  /// 页面状态引用，内部动画状态都托管在页面 State 字段里。
  final _DiariesPage _state;

  /// 新查询首帧数据的最长等待时间；超时后照常淡入（退化为旧行为），
  /// 避免查询异常挂起时列表一直不可见。
  static const Duration _maxFreshPageWait = Duration(milliseconds: 600);

  /// 新建日记放出的兜底超时（非动画计时）：上层路由退场被打断、或新卡片不在
  /// 当前筛选窗口里时，到点仍放出 / 清除出现标记。
  static const Duration _createdRevealTimeout = Duration(milliseconds: 1200);

  /// 应用筛选变更并启动列表过渡。
  ///
  /// 时序：
  /// 1) 冻结当前展示列表，然后立即写入筛选（标签选中态下一帧即反馈）；
  /// 2) 后台过渡：淡出 -> 等新查询首帧数据 -> 释放冻结 -> 淡入；
  /// 3) 过渡途中再次变更只会递增 generation，循环会继续处理最新一轮，
  ///    且只为最新结果淡入，不会把中间态或旧数据淡入出来。
  void queueFilterMutation(VoidCallback mutation) {
    _state._heldDisplayedItems ??= _state._lastDisplayedItems;
    _state._filterMutationGeneration++;
    mutation();
    _state._queuedFilterTransition ??= _runFilterTransition();
  }

  Future<void> _runFilterTransition() async {
    var settledGeneration = -1;
    try {
      while (_state.mounted &&
          settledGeneration != _state._filterMutationGeneration) {
        final generation = _state._filterMutationGeneration;
        await _fadeOutListIfNeeded();
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
          // 等待期间又有新筛选：保持淡出与冻结，直接处理最新一轮。
          continue;
        }
        _state.setState(() => _state._heldDisplayedItems = null);
        await WidgetsBinding.instance.endOfFrame;
        if (!_state.mounted) {
          return;
        }
        await _fadeInListIfNeeded();
        settledGeneration = generation;
      }
    } finally {
      _state._queuedFilterTransition = null;
    }
  }

  /// 等待当前分页 query 拿到首帧数据（或错误）。
  ///
  /// family 换 key 后首帧必为 loading；若只等一帧就淡入，淡入的会是旧列表，
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

  /// 切换布局：整体淡出 → 应用 [apply]（换布局）→ 下一帧淡入。
  ///
  /// 布局必须在淡出完成后再换：先换再淡出等于硬切后补一个淡出。减少动画或
  /// 筛选过渡正在进行时直接应用（后者结束时会自行淡入）。
  Future<void> switchLayout(VoidCallback apply) async {
    if (_reduceMotion || _state._queuedFilterTransition != null) {
      apply();
      return;
    }
    await _fadeOutListIfNeeded();
    if (!_state.mounted) {
      return;
    }
    apply();
    await WidgetsBinding.instance.endOfFrame;
    if (!_state.mounted) {
      return;
    }
    await _fadeInListIfNeeded();
  }

  /// 系统开启“减少动画”时不做整列表淡入淡出，只保留“数据到齐再替换”。
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(_state.context);

  /// 当列表当前可见时执行整体淡出。
  Future<void> _fadeOutListIfNeeded() async {
    if (!_state.mounted ||
        _reduceMotion ||
        _state._listRefreshPulseController.value <= 0) {
      return;
    }
    await _state._listRefreshPulseController.animateTo(
      0,
      duration: _DiariesPage._listRefreshFadeOutDuration,
      curve: ExpressiveMotion.effects,
    );
  }

  /// 当列表非全可见时执行整体淡入。
  Future<void> _fadeInListIfNeeded() async {
    if (!_state.mounted || _state._listRefreshPulseController.value >= 1) {
      return;
    }
    if (_reduceMotion) {
      _state._listRefreshPulseController.value = 1;
      return;
    }
    await _state._listRefreshPulseController.animateTo(
      1,
      duration: _DiariesPage._listRefreshFadeInDuration,
      curve: ExpressiveMotion.effects,
    );
  }

  /// 为即将删除/归档的项启动收起动画计时器。
  void startHideAnimations(Iterable<String> diaryIds) {
    final targetIds = diaryIds.toSet();
    if (targetIds.isEmpty) {
      return;
    }

    for (final diaryId in targetIds) {
      _state._appearingTimers.remove(diaryId)?.cancel();
      _state._pendingHideTimers[diaryId]?.cancel();
      _state._pendingHideTimers[diaryId] = Timer(
        _DiariesPage._listItemTransitionDuration,
        () {
          _state._pendingHideTimers.remove(diaryId);
          if (!_state.mounted) {
            return;
          }
          _state.setState(() {
            _state._pendingHideDiaryIds.remove(diaryId);
            _state._optimisticHiddenDiaryIds.add(diaryId);
          });
        },
      );
    }

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
      _state._pendingHideTimers.remove(diaryId)?.cancel();
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
      _state._pendingHideTimers.remove(diaryId)?.cancel();
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
    for (final timer in _state._pendingHideTimers.values) {
      timer.cancel();
    }
    _state._pendingHideTimers.clear();
    for (final timer in _state._appearingTimers.values) {
      timer.cancel();
    }
    _state._appearingTimers.clear();
  }
}
