import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../l10n/app_localizations.dart';

/// 一页的外壳：还原页内的起滑距离、按可见性开关 ticker 与共享元素，并提供
/// “上一篇 / 下一篇”读屏动作（[PageView] 自带的滚动语义照常保留）。
class DiaryPagerPageFrame extends StatelessWidget {
  const DiaryPagerPageFrame({
    super.key,
    required this.index,
    required this.visibility,
    required this.gestureSettings,
    required this.onPrevious,
    required this.onNext,
    required this.child,
  });

  final int index;
  final ValueListenable<DiaryPagerVisibility> visibility;
  final DeviceGestureSettings gestureSettings;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onPrevious = this.onPrevious;
    final onNext = this.onNext;
    final page = MediaQuery(
      data: MediaQuery.of(context).copyWith(gestureSettings: gestureSettings),
      // 独立的语义节点：动作挂在“这一页”上，而不是并进外层的滚动节点。
      child: Semantics(
        container: true,
        customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
          if (onPrevious != null)
            CustomSemanticsAction(label: l10n.diaryPreviewPrevious): onPrevious,
          if (onNext != null)
            CustomSemanticsAction(label: l10n.diaryPreviewNext): onNext,
        },
        child: child,
      ),
    );
    return ValueListenableBuilder<DiaryPagerVisibility>(
      valueListenable: visibility,
      child: page,
      builder:
          (BuildContext context, DiaryPagerVisibility visible, Widget? page) {
            return TickerMode(
              enabled: visible.shows(index),
              child: HeroMode(enabled: visible.current == index, child: page!),
            );
          },
    );
  }
}

/// 翻页器滑动途中露出的页区间与当前页（四舍五入的那一页）。
@immutable
class DiaryPagerVisibility {
  const DiaryPagerVisibility(this.first, this.last, this.current);

  factory DiaryPagerVisibility.at(double page) =>
      DiaryPagerVisibility(page.floor(), page.ceil(), page.round());

  final int first;
  final int last;
  final int current;

  bool shows(int index) => index >= first && index <= last;

  @override
  bool operator ==(Object other) =>
      other is DiaryPagerVisibility &&
      other.first == first &&
      other.last == last &&
      other.current == current;

  @override
  int get hashCode => Object.hash(first, last, current);
}

/// 只在缓存区、还看不见的一页：翻页动画进行中先不建内容，停下后再建。
///
/// 为什么：翻页器缓存左右各一页（`allowImplicitScrolling`）。手指一动，
/// 视口外再往前的那一篇就进入缓存区，整页（顶栏、元信息、正文编辑器）在
/// 这一帧里建出来并布局，真机上这一帧 10–20ms，正好落在翻页动画的开头，
/// 掉帧最显眼。它此刻看不见，晚一点建不影响画面。
///
/// 状态：首次挂上时，若这一页已经露出来（[DiaryPagerVisibility.shows]）或
/// 所在的滚动视图没有在滚动，立即建；否则先占一块空位，等到滚动停下
/// （`isScrollingNotifier` 变为 false）或这一页开始露出来时再建——用户在
/// 动画停下前就把它翻进视口时，在露出来的那一帧建，与原先相同。建过之后
/// 不再回到占位。
class DiaryPagerDeferredPage extends StatefulWidget {
  const DiaryPagerDeferredPage({
    super.key,
    required this.index,
    required this.visibility,
    required this.child,
  });

  final int index;
  final ValueListenable<DiaryPagerVisibility> visibility;
  final Widget child;

  @override
  State<DiaryPagerDeferredPage> createState() => _DiaryPagerDeferredPageState();
}

class _DiaryPagerDeferredPageState extends State<DiaryPagerDeferredPage> {
  bool _ready = false;
  ValueListenable<bool>? _scrolling;
  ValueListenable<DiaryPagerVisibility>? _visibility;

  bool get _shouldBuild =>
      widget.visibility.value.shows(widget.index) ||
      !(_scrolling?.value ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) {
      return;
    }
    final scrolling = Scrollable.maybeOf(context)?.position.isScrollingNotifier;
    if (!identical(scrolling, _scrolling)) {
      _scrolling?.removeListener(_check);
      _scrolling = scrolling?..addListener(_check);
    }
    if (_shouldBuild) {
      _ready = true;
      _detach();
    } else {
      _visibility ??= widget.visibility..addListener(_check);
    }
  }

  @override
  void didUpdateWidget(covariant DiaryPagerDeferredPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready) return;
    if (!identical(oldWidget.visibility, widget.visibility)) {
      _visibility?.removeListener(_check);
      _visibility = widget.visibility..addListener(_check);
    }
    if (_shouldBuild) {
      _ready = true;
      _detach();
    }
  }

  void _check() {
    if (_ready || !mounted || !_shouldBuild) {
      return;
    }
    _detach();
    setState(() => _ready = true);
  }

  void _detach() {
    _scrolling?.removeListener(_check);
    _scrolling = null;
    _visibility?.removeListener(_check);
    _visibility = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? widget.child : const SizedBox.expand();
}
