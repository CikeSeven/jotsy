import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import 'tag_filter_chip.dart';

/// 日记页顶部标签筛选栏。
///
/// 结构：
/// - 左侧纯 `X` 清空筛选按钮（带缩放 + 旋转反馈）；
/// - 右侧横向滚动的标签筛选 chip 列表。
class DiaryTagFilterBar extends StatefulWidget {
  const DiaryTagFilterBar({
    super.key,
    required this.tags,
    required this.selectedTagFilterIds,
    required this.onToggleTagFilter,
    required this.onClearTagFilters,
  });

  final List<Tag> tags;
  final Set<int> selectedTagFilterIds;
  final void Function(int tagId, bool selected) onToggleTagFilter;
  final VoidCallback onClearTagFilters;

  @override
  State<DiaryTagFilterBar> createState() => _DiaryTagFilterBarState();
}

class _DiaryTagFilterBarState extends State<DiaryTagFilterBar>
    with SingleTickerProviderStateMixin {
  /// 半圈角度（180°），用于清空按钮单向旋转动画。
  static const double _halfTurn = 3.1415926535897932;

  // 清空按钮反馈动画：缩放 + 旋转。
  late final AnimationController _clearController;
  late final Animation<double> _clearScale;
  late final Animation<double> _clearRotation;
  double _clearBaseAngle = 0;

  @override
  void initState() {
    super.initState();
    _clearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _clearScale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 0.78).chain(
          CurveTween(curve: const Cubic(0.2, 0.0, 0.0, 1.0)),
        ),
        weight: 32,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.78, end: 1.06).chain(
          CurveTween(curve: const Cubic(0.16, 1, 0.3, 1)),
        ),
        weight: 44,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.06, end: 1).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 24,
      ),
    ]).animate(_clearController);
    _clearRotation = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: _halfTurn).chain(
          CurveTween(curve: const Cubic(0.2, 0.0, 0.0, 1.0)),
        ),
        weight: 100,
      ),
    ]).animate(_clearController);
  }

  @override
  void dispose() {
    _clearController.dispose();
    super.dispose();
  }

  Future<void> _handleClearTap() async {
    if (_clearController.isAnimating) {
      return;
    }
    // 点击即刻清空，再异步播放动画，保证“响应优先”。
    widget.onClearTagFilters();
    unawaited(_playClearAnimation());
  }

  Future<void> _playClearAnimation() async {
    await _clearController.forward(from: 0);
    if (!mounted) {
      return;
    }
    setState(() {
      _clearBaseAngle += _halfTurn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelection = widget.selectedTagFilterIds.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.xs,
        AppSpacing.m,
        AppSpacing.xs,
      ),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: widget.tags.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              // 左侧清空按钮：按需求保持纯图标，无额外背景包裹。
              return AnimatedBuilder(
                animation: _clearController,
                builder: (BuildContext context, Widget? child) {
                  return Transform.rotate(
                    angle: _clearBaseAngle + _clearRotation.value,
                    child: Transform.scale(
                      scale: _clearScale.value,
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleClearTap,
                  child: SizedBox(
                    width: 26,
                    height: 32,
                    child: Center(
                      child: FaIcon(
                        FontAwesomeIcons.xmark,
                        size: 16,
                        color:
                            hasSelection
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }

            final tag = widget.tags[index - 1];
            final selected = widget.selectedTagFilterIds.contains(tag.id);
            // 普通标签筛选项：白底轻描边，选中态强化边框色。
            return TagFilterChip(
              label: tag.name,
              colorDot: Color(tag.color),
              colorDotSize: 12,
              selected: selected,
              selectedColor: Colors.white,
              selectedForegroundColor: colorScheme.primary,
              unselectedColor: Colors.white,
              unselectedForegroundColor: colorScheme.onSurface,
              radius: 9,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              animateBorder: true,
              showSelectedShadow: false,
              onTap: () => widget.onToggleTagFilter(tag.id, !selected),
            );
          },
        ),
      ),
    );
  }
}
