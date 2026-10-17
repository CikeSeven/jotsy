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
