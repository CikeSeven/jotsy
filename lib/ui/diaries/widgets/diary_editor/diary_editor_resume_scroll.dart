import 'dart:async';

import 'package:flutter/widgets.dart';

/// 拉起键盘编辑时切到别的应用再回来，把正文放回离开前的滚动位置；只由
/// `DiaryEditorViewport` 驱动。
///
/// 离开时系统收起键盘，页面视口随之变高；正文离末尾不到一个键盘高时，滚动
/// 位置会被夹到新的上限。回来键盘重新升起，按光标揭示只会把光标顶到遮挡
/// 上方，停不回原处，整页看起来自己往上滚了一截。这里在离开那一刻记下滚动
/// 位置，键盘回来时逐帧放回（视口逐帧变矮、上限逐帧变大，每帧夹到当前上
/// 限），放回期间视口不揭示光标（[pending]）。
///
/// 输入：键盘高度变化（[keyboardChanged]）与应用生命周期（[lifecycleChanged]）。
/// 输出：直接滚动 [position]；放回结束或放弃等待时调 [onSettled]，由视口
/// 补一次光标核对（键盘高度变了时光标仍要露出来）。用户回来后动了光标、
/// 打字或拖动正文（[cancel]）就不再放回。
class DiaryEditorResumeScroll {
  DiaryEditorResumeScroll({required this.position, required this.onSettled});

  final ScrollPosition? Function() position;
  final VoidCallback onSettled;

  /// 键盘先收起、应用随后才变为 inactive 时，离开前的位置只能取键盘刚开始
  /// 收起那一刻的记录；超过这段时间的记录当作用户自己收起键盘，不算离开。
  static const Duration _hideGrace = Duration(seconds: 1);

  /// 回到前台后等键盘重新升起的时间（超时，不是动画时长）：键盘每升高一帧
  /// 重新计时；一直没升起（输入法没有恢复，或只是被通知栏短暂盖住）就放弃。
  static const Duration _returnWindow = Duration(seconds: 1);

  double _keyboard = 0;
  bool _resumed = true;
  _ScrollMark? _hide;
  _ScrollMark? _away;
  Timer? _window;
  bool _scheduled = false;

  /// 等着放回：视口这期间不揭示光标。
  bool get pending => _away != null;

  /// 挂载时的键盘高度：页面可能在键盘已升起时才建出正文（之后没有度量
  /// 变化），按 0 算会把离开时的键盘当成没升起。
  void syncKeyboard(double inset) => _keyboard = inset;

  /// 键盘高度（逻辑像素）从上次的值变为 [inset]；在本帧布局之前调用，此刻
  /// 的滚动位置还没被新视口夹过。返回 true 表示键盘升高由放回处理，视口
  /// 不再按键盘升高揭示光标。
  bool keyboardChanged(double inset) {
    final previous = _keyboard;
    _keyboard = inset;
    if (inset < previous) {
      if (_hide == null || !_hide!.fresh) {
        final pixels = position()?.pixels;
        _hide = pixels == null ? null : _ScrollMark(pixels, previous);
      }
      return false;
    }
    if (inset == previous) return false;
    _hide = null;
    if (_away == null) return false;
    if (_resumed) _armWindow();
    _scheduleRestore();
    return true;
  }

  /// 应用生命周期变化。只在离开 resumed 的那一下记位置：回来路上的
  /// hidden → inactive 不算离开。[focused] 为正文此刻是否有焦点：没在编辑
  /// 正文就不记（手机上切后台不会移走焦点）。
  void lifecycleChanged(AppLifecycleState state, {required bool focused}) {
    if (state == AppLifecycleState.resumed) {
      _resumed = true;
      if (_away != null) _armWindow();
      return;
    }
    final leaving = _resumed;
    _resumed = false;
    _window?.cancel();
    if (!leaving || _away != null || !focused) return;
    final hide = _hide;
    if (hide != null && hide.fresh) {
      _away = hide;
      return;
    }
    final pixels = position()?.pixels;
    if (_keyboard > 0 && pixels != null) _away = _ScrollMark(pixels, _keyboard);
  }

  /// 用户回来后自己动了（改光标、打字、拖动正文）：不再放回。
  void cancel() {
    _away = null;
    _hide = null;
    _window?.cancel();
  }

  void dispose() => _window?.cancel();

  void _armWindow() {
    _window?.cancel();
    _window = Timer(_returnWindow, _settle);
  }

  void _settle() {
    if (_away == null) return;
    _away = null;
    _window?.cancel();
    onSettled();
  }

  /// 视口按新键盘高度布局完、滚动上限更新之后再放回。
  void _scheduleRestore() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _restore();
    });
  }

  void _restore() {
    final away = _away;
    final position = this.position();
    if (away == null || position == null || !position.hasContentDimensions) {
      return;
    }
    final target = away.pixels.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() > 0.5) position.jumpTo(target);
    if (_keyboard < away.keyboard - 0.5) return;
    // 键盘回到离开时的高度、位置也放回了才算完。键盘到位而上限还差一点
    // （悬浮工具栏的留白晚一帧才回来这类）时下一帧再放；键盘回来时矮了
    // 一截停不到这里，由回到前台的等待超时收尾。
    if ((target - away.pixels).abs() <= 0.5) {
      _settle();
    } else {
      _scheduleRestore();
    }
  }
}

/// 某一刻的滚动位置与当时的键盘高度。
class _ScrollMark {
  _ScrollMark(this.pixels, this.keyboard) : _at = DateTime.now();

  final double pixels;
  final double keyboard;
  final DateTime _at;

  bool get fresh =>
      DateTime.now().difference(_at) < DiaryEditorResumeScroll._hideGrace;
}
