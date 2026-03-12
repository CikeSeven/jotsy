// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/diaries_page.dart';

/// 日记列表过渡协调器。
///
/// 职责边界：
/// - 处理筛选切换的淡入淡出节奏；
/// - 维护删除/归档过程中的隐藏与出现动画状态；
/// - 统一管理相关计时器，避免页面销毁后回调触发。
class DiaryListTransitionCoordinator {
  const DiaryListTransitionCoordinator(this._state);

  /// 页面状态引用，内部动画状态都托管在页面 State 字段里。
  final _DiariesPage _state;

  /// 把筛选变更加入队列。
  ///
  /// 连续多次切换时只保留最新 mutation，保证过渡顺序稳定且不会抖动。
  void queueFilterMutation(VoidCallback mutation) {
    _state._pendingFilterMutation = mutation;
    _state._queuedFilterTransition ??= _drainQueuedFilterMutations();
  }

  /// 串行消费筛选队列：淡出 -> 应用筛选 -> 等待一帧 -> 淡入。
  Future<void> _drainQueuedFilterMutations() async {
    while (_state.mounted && _state._pendingFilterMutation != null) {
      await _fadeOutListIfNeeded();
      if (!_state.mounted) {
        break;
      }

      // 每轮只处理一次筛选变更，避免完全隐藏状态下吞并多次更新。
      final mutation = _state._pendingFilterMutation!;
      _state._pendingFilterMutation = null;
      mutation();
      await WidgetsBinding.instance.endOfFrame;
      if (!_state.mounted) {
        break;
      }

      await _fadeInListIfNeeded();
    }
    _state._queuedFilterTransition = null;
  }

  /// 当列表当前可见时执行整体淡出。
  Future<void> _fadeOutListIfNeeded() async {
    if (!_state.mounted || _state._listRefreshPulseController.value <= 0) {
      return;
    }
    await _state._listRefreshPulseController.animateTo(
      0,
      duration: _DiariesPage._listRefreshFadeOutDuration,
      curve: Curves.easeInOutSine,
    );
  }

  /// 当列表非全可见时执行整体淡入。
  Future<void> _fadeInListIfNeeded() async {
    if (!_state.mounted || _state._listRefreshPulseController.value >= 1) {
      return;
    }
    await _state._listRefreshPulseController.animateTo(
      1,
      duration: _DiariesPage._listRefreshFadeInDuration,
      curve: Curves.easeInOutSine,
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
    final visibleIds =
        visibleItems.map((DiaryWithTags item) => item.diary.diaryId).toSet();
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
