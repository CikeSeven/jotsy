// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/diaries_page.dart';

/// 宽窗口日记页（双栏）里“正在阅读”的选中：哪一篇显示在右栏。
///
/// 职责边界：
/// - 选中只是页面的内存状态（`_DiariesPage._readingDiaryId`），不持久化，启动
///   时不自动选中；与多选（`_selectedDiaryIds`）互不影响，多选模式下点卡片
///   仍是勾选；
/// - 顺序与预览页左右翻页同一口径（[DiariesPageController.readingOrder]）；
/// - 窗口不是双栏时选中保留但不显示，点卡片照旧推入预览页；回到双栏时
///   重新显示；
/// - 删除后的去向、列表里不见了时的清除、离开私密日记本时的清除都在这里；
/// - 键盘（只在双栏、焦点在日记页里且不在输入框时）：↑ / ← 上一篇、↓ / →
///   下一篇（并把选中的卡片滚进视口），Enter 编辑选中的一篇，Esc 清除选中；
///   移过已加载部分的末尾时先加载下一页，到达后接着选下一篇；
/// - 不构建 UI（右栏见 `DiaryDetailPane`）。
class DiariesReadingSelectionController {
  DiariesReadingSelectionController(this._state);

  final _DiariesPage _state;

  /// 交给右栏嵌入预览的宿主：删除与“日记不见了”都回到这里。只建一次，
  /// 右栏重建时不必换。
  late final DiaryPreviewHost host = DiaryPreviewHost(
    onDeleted: handleDeleted,
    onVanished: clear,
  );

  /// 键盘移过已加载部分的末尾时记下的“从哪一篇往下”：下一页到达后若选中
  /// 仍是它，就接着选它后面的一篇（见 [syncWithList]）。
  String? _pendingAdvanceFromId;

  String? get selectedId => _state._readingDiaryId;

  /// 选中 [diaryId] 在右栏阅读（点卡片、键盘、右栏的上一篇 / 下一篇）。
  ///
  /// 焦点移回日记页，之后的方向键由日记页处理（点卡片本身不会移动焦点）。
  /// [reveal] 时把选中的卡片滚进视口：[forward] 为往下移时让它贴着视口
  /// 底部出现，往上移时贴着顶部。
  void select(String diaryId, {bool reveal = false, bool forward = true}) {
    _pendingAdvanceFromId = null;
    _state._keyboardFocusNode.requestFocus();
    if (_state._readingDiaryId != diaryId) {
      _state.setState(() => _state._readingDiaryId = diaryId);
    }
    if (reveal) {
      _revealSelectedCard(forward: forward);
    }
  }

  /// 清除选中，右栏回到“选一篇日记来读”。
  void clear() {
    _pendingAdvanceFromId = null;
    if (_state._readingDiaryId == null || !_state.mounted) {
      return;
    }
    _state.setState(() => _state._readingDiaryId = null);
  }

  /// 按列表顺序移动选中：[delta] 为 1 是下一篇、-1 是上一篇。
  ///
  /// 没有选中时从第一篇开始；到第一篇再往上不动；到已加载部分的末尾而列表
  /// 还有下一页时先加载，到达后接着选下一篇（[_pendingAdvanceFromId]）。
  void moveBy(int delta) {
    final order = _state._controller.readingOrder();
    if (order.isEmpty) {
      return;
    }
    final current = selectedId;
    final index = current == null
        ? -1
        : order.indexWhere(
            (DiaryWithTags item) => item.diary.diaryId == current,
          );
    if (index < 0) {
      select(order.first.diary.diaryId, reveal: true, forward: false);
      return;
    }
    final target = index + delta;
    if (target < 0) {
      return;
    }
    if (target >= order.length) {
      if (_state._hasMoreDiaries) {
        _pendingAdvanceFromId = current;
        _state._requestLoadMoreDiaries();
      }
      return;
    }
    select(order[target].diary.diaryId, reveal: true, forward: delta > 0);
  }

  /// 编辑选中的一篇（Enter）：与右栏顶栏的“编辑”同一流程，编辑页里删除时
  /// 按 [handleDeleted] 收尾。未解封的时间胶囊不能编辑（右栏只显示封存页），
  /// 忽略。
  Future<void> openEditorForSelected() async {
    final diaryId = selectedId;
    if (diaryId == null) {
      return;
    }
    for (final item in _state._controller.readingOrder()) {
      if (item.diary.diaryId != diaryId) {
        continue;
      }
      final capsule = TimeCapsuleState.fromFields(
        lockedAt: item.diary.capsuleLockedAt,
        unlockAt: item.diary.capsuleUnlockAt,
        now: DateTime.now(),
      );
      if (capsule.isLocked) {
        return;
      }
      break;
    }
    final deleted = await openDiaryEditorFromPreview(
      _state.context,
      _state.ref,
      diaryId,
    );
    if (_state.mounted && deleted) {
      handleDeleted(diaryId);
    }
  }

  /// 日记页焦点子树里的按键（见类注释）。只处理按下与长按重复（Enter 只认
  /// 按下）；带 Ctrl / ⌘ / Alt 的组合留给首页快捷键；焦点在输入框里时不抢
  /// 方向键与回车；单栏时全部不处理（方向键照常滚动列表）。
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // 日记页在首页里保活：切到别的 Tab 后焦点可能还留在这里，那时不响应。
    if (!_state._twoPane ||
        !TickerMode.valuesOf(_state.context).enabled ||
        _focusInTextField()) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowRight) {
      moveBy(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowLeft) {
      moveBy(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (selectedId == null) {
        return KeyEventResult.ignored;
      }
      if (event is KeyDownEvent) {
        unawaited(openEditorForSelected());
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && selectedId != null) {
      clear();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 焦点是否在输入框里（搜索框、对话框外的文字输入等）。
  static bool _focusInTextField() {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) {
      return false;
    }
    return focused.widget is EditableText ||
        focused.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// 下一帧把选中的卡片滚进视口。
  ///
  /// 卡片还没构建（列表被滚到了远处，懒加载的 sliver 没建它）时找不到它：
  /// 先按它在顺序里的位置估一个偏移跳过去让它建出来，下一帧再精确揭示，
  /// 最多试三次。
  void _revealSelectedCard({required bool forward, int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_state.mounted) {
        return;
      }
      final selected = selectedId;
      if (selected == null) {
        return;
      }
      final cardContext = _state._readingCardLocator.contextFor(selected);
      if (cardContext != null) {
        unawaited(
          Scrollable.ensureVisible(
            cardContext,
            duration: ExpressiveMotion.duration(
              _state.context,
              ExpressiveMotion.fast,
            ),
            curve: ExpressiveMotion.effects,
            alignmentPolicy: forward
                ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
                : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          ),
        );
        return;
      }
      final anchor = _state._listScrollContext;
      final position = anchor == null || !anchor.mounted
          ? null
          : Scrollable.maybeOf(anchor)?.position;
      if (attempt >= 3 || position == null) {
        return;
      }
      final order = _state._controller.readingOrder();
      final index = order.indexWhere(
        (DiaryWithTags item) => item.diary.diaryId == selected,
      );
      if (index < 0) {
        return;
      }
      final fraction = order.length <= 1 ? 0.0 : index / (order.length - 1);
      position.jumpTo(
        (position.maxScrollExtent * fraction).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      _revealSelectedCard(forward: forward, attempt: attempt + 1);
    });
  }

  /// 右栏里删除了一篇（“更多”、编辑页或封存页里删除）：先把选中移到列表里的
  /// 下一篇（它是最后一篇时移到上一篇，都没有时清除），再给出与预览页删除
  /// 相同的撤销提示；撤销只恢复日记，选中不跳回去。
  ///
  /// 顺序在删除写库之后、列表数据推送之前读取，这时被删的一篇通常还在列表
  /// 里；已经不在时（推送更快）选中由 [syncWithList] 清除。
  void handleDeleted(String diaryId) {
    if (_state._readingDiaryId == diaryId) {
      final order = _state._controller.readingOrder();
      final index = order.indexWhere(
        (DiaryWithTags item) => item.diary.diaryId == diaryId,
      );
      String? next;
      if (index >= 0 && index + 1 < order.length) {
        next = order[index + 1].diary.diaryId;
      } else if (index > 0) {
        next = order[index - 1].diary.diaryId;
      }
      _state.setState(() => _state._readingDiaryId = next);
    }
    unawaited(_state._controller.offerUndoForDeletedDiary(diaryId));
  }

  /// 列表拿到新数据后对一次选中：选中的一篇不在 [items] 里了（换了筛选、
  /// 日记本或排序后不在已加载的部分，或被归档、删除）就清除。
  ///
  /// 只在页面 build 里、数据不是筛选过渡冻结的旧列表时调用：直接改字段，
  /// 同一次 build 随后读取，不另起重建。
  ///
  /// 键盘移过末尾而等着下一页时（[_pendingAdvanceFromId]），新数据里那一篇
  /// 后面有了日记就接着选中它并滚进视口；列表已没有下一页时放弃等待。
  void syncWithList(List<DiaryWithTags> items) {
    final selected = _state._readingDiaryId;
    if (selected == null) {
      _pendingAdvanceFromId = null;
      return;
    }
    final index = items.indexWhere(
      (DiaryWithTags item) => item.diary.diaryId == selected,
    );
    if (index < 0) {
      _pendingAdvanceFromId = null;
      _state._readingDiaryId = null;
      return;
    }
    if (_pendingAdvanceFromId != selected) {
      _pendingAdvanceFromId = null;
      return;
    }
    if (index + 1 < items.length) {
      _pendingAdvanceFromId = null;
      _state._readingDiaryId = items[index + 1].diary.diaryId;
      _revealSelectedCard(forward: true);
    } else if (!_state._hasMoreDiaries) {
      _pendingAdvanceFromId = null;
    }
  }

  /// 日记本范围变了：离开的是私密日记本（隐藏或上锁）时立即清除，不等新
  /// 范围的数据到达——重锁遮罩里选了“回到全部日记”之后，右栏不应再露出
  /// 那本里的日记（独立的预览页此时会随 popUntil 关掉）。其余情况交给
  /// [syncWithList]：选中的一篇还在新范围里就保留。
  void handleScopeChanged() {
    if (_state._readingScopePrivate) {
      clear();
    }
  }

  /// 右栏的位置：顶栏“位置”标题与正文末尾的上一篇 / 下一篇（在列表里换选）。
  DiaryPreviewPaging? pagingFor(BuildContext context, String diaryId) {
    final order = _state._controller.readingOrder();
    final index = order.indexWhere(
      (DiaryWithTags item) => item.diary.diaryId == diaryId,
    );
    if (index < 0) {
      return null;
    }
    final hasMore = _state._hasMoreDiaries;
    // 与方向键同一条路径：末尾还有下一页时“下一篇”先加载再接着选。
    return DiaryPreviewPaging.of(
      context.l10n,
      DiaryPagerPosition(
        index: index,
        count: order.length,
        onPrevious: index > 0 ? () => moveBy(-1) : null,
        onNext: index + 1 < order.length || hasMore ? () => moveBy(1) : null,
      ),
      hasMore: hasMore,
      titleAt: (int at) =>
          at >= 0 && at < order.length ? order[at].diary.title : null,
    );
  }
}
