import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 对话消息列表的滚动控制器：贴着底部时跟随新内容，用户一往上翻就放手；
/// 视口变矮（键盘升起、输入框变高）时让底边那一行留在原处。
///
/// 为什么不在每次流式更新后 `jumpTo` 到底部（改版前的做法）：`jumpTo` 先
/// `goIdle`，会把用户正在进行的按住 / 拖动直接取消。生成中每秒几十次更新，
/// 离底部一段距离以内的拖动不断被打断，往上翻要用力一下甩出这个范围才行；
/// 键盘升起时视口变矮却没有内容更新，列表停在原处，底部的消息被挡住。
///
/// 现在的规则：
/// - 是否跟随（[following]）只由用户的滚动决定：手指或滚轮一往上（看更早
///   的消息）就不再跟随，不等松手；每次滚动结束时停在离底部
///   [resumeDistance] 以内就重新跟随，否则不跟随（拖滚动条等也按这条）。
/// - 跟随时，内容变高（流式文字、步骤卡、新消息）与视口变矮都在布局阶段
///   直接把位置改到新的底部：同一帧到位、不闪，也不经 `jumpTo`。
/// - 不跟随时，视口高度变化按差值平移：键盘升起，视口底边看着的那一行跟着
///   上移，而不是被挡到键盘后面；收起时同理落回。
/// - 按住、拖动与惯性滚动期间一律不改位置，列表不会从手指下跑开，也不和
///   惯性模拟抢位置。
/// - 每次滚动停下时把位置与是否跟随记进最近的 `PageStorage`（对话页给每段
///   对话一个常驻本次运行的存储桶）；[restoreSaved] 时（从首页“回到对话”）
///   新建的列表按记下的位置与跟随状态恢复，否则从底部开始。
class AiChatScrollController extends ScrollController {
  AiChatScrollController({super.debugLabel});

  /// 滚动结束时离底部不超过这个距离就重新跟随。
  static const double resumeDistance = 48;

  bool _following = true;

  /// 是否贴着底部跟随新内容。
  bool get following => _following;

  /// 列表建好时按 `PageStorage` 里记下的位置恢复（回到对话），而不是从底部
  /// 开始。只影响之后新建的滚动位置。
  bool restoreSaved = false;

  /// 跟随状态在存储桶里的标识（滚动位置本身用列表的 `PageStorageKey`）。
  static const String _followingId = 'ai-chat-following';

  /// 回到底部并重新跟随（发送问题、打开对话时）。还没排版时只记下跟随，
  /// 首次排版就停在底部。
  void jumpToBottom() {
    _following = true;
    if (!hasClients) return;
    final position = this.position;
    if (position.hasContentDimensions) {
      position.jumpTo(position.maxScrollExtent);
    }
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _AiChatScrollPosition(
      owner: this,
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _AiChatScrollPosition extends ScrollPositionWithSingleContext {
  _AiChatScrollPosition({
    required this.owner,
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  final AiChatScrollController owner;

  /// 上次排版以来视口变矮了多少（变高为负），在 [applyContentDimensions]
  /// 里消化。视口每次排版只报一次高度，内容尺寸可能要报好几轮。
  double _viewportShrink = 0;

  /// 用户按着、拖着，或正在惯性滚动。
  bool get _moving {
    final activity = this.activity;
    return activity is HoldScrollActivity || (activity?.isScrolling ?? false);
  }

  @override
  bool applyViewportDimension(double viewportDimension) {
    if (hasViewportDimension) {
      _viewportShrink += this.viewportDimension - viewportDimension;
    }
    return super.applyViewportDimension(viewportDimension);
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final before = hasPixels ? pixels : null;
    final shrink = _viewportShrink;
    _viewportShrink = 0;
    // 先让默认逻辑（RangeMaintainingScrollPhysics 夹回范围）处理完，再按
    // 上面的规则改位置：反过来的话，默认逻辑会把我们改出的“超出旧范围”
    // 当成越界量保留下来。
    final settled = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    if (before == null || _moving) return settled;
    final end = math.max(minScrollExtent, maxScrollExtent);
    final double target;
    if (owner._following) {
      target = end;
    } else if (shrink != 0) {
      target = (before + shrink).clamp(minScrollExtent, end);
    } else {
      return settled;
    }
    // 懒加载列表的总高是估算的，越靠近末尾越准；差得很小就不再改，免得
    // 估算的细微抖动让视口一轮轮重排。
    if ((target - pixels).abs() < 0.5) return settled;
    correctPixels(target);
    // 位置变了：返回 false 让视口按新位置重新排一遍。
    return false;
  }

  /// 回到对话时恢复离开前的位置与跟随状态；没记过（一直停在底部）就照常
  /// 从底部开始。不恢复时什么都不读。
  @override
  void restoreScrollOffset() {
    if (!owner.restoreSaved) return;
    final storage = PageStorage.maybeOf(context.storageContext);
    final following = storage?.readState(
      context.storageContext,
      identifier: AiChatScrollController._followingId,
    );
    if (following is! bool) return;
    owner._following = following;
    if (!following) super.restoreScrollOffset();
  }

  @override
  void saveScrollOffset() {
    super.saveScrollOffset();
    PageStorage.maybeOf(context.storageContext)?.writeState(
      context.storageContext,
      owner._following,
      identifier: AiChatScrollController._followingId,
    );
  }

  @override
  void updateUserScrollDirection(ScrollDirection value) {
    // forward = 内容往下走、看更早的消息。手指一动就放手，不等松开。
    if (value == ScrollDirection.forward) owner._following = false;
    super.updateUserScrollDirection(value);
  }

  @override
  void didEndScroll() {
    // 先定下是否跟随再交给默认实现：它会顺带存下位置与跟随状态。
    if (hasContentDimensions && hasPixels) {
      owner._following =
          maxScrollExtent - pixels <= AiChatScrollController.resumeDistance;
    }
    super.didEndScroll();
  }
}
