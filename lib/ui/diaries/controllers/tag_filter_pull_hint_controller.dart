import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/feature_tips.dart';
import '../../../core/services/settings_service.dart';

/// 首页标签栏“下拉展开”提示的时序与记录。
///
/// 输入（都由日记页喂进来）：
/// - [sync]：每次 build 调用，给出设置、首页入场编排的进度、此刻能否提示
///   （日记 Tab 可见、路由在最上层、不在多选、标签栏收着）与是否减少动画；
/// - [reportHiddenTags]：标签栏布局后回报收起的一行是否放不下全部标签；
/// - [handleExpanded]：标签栏完全展开（拖动或点提示行都算）；
/// - [handleUserInteraction]：用户开始拖动标签栏或滑动日记列表。
///
/// 输出：[visible]（提示行是否显示，变化时 notifyListeners）与 [peek]（轻推
/// 演示的进度，0 → 1 → 0，标签栏据此往下探一段再弹回）。
///
/// 副作用：出现时与学会时把 [FeatureTips] 写回设置（本机偏好）。
///
/// 状态机：idle →（条件全部满足）scheduled →（[showDelay] 后）showing →
/// （[visibleDuration] 后自动收起，或条件失效、用户动手）finished。scheduled
/// 期间条件失效就退回 idle 并取消计时，下次满足时重新等待；用户动手则把
/// 计时推迟到停手之后，不在操作途中冒出来；finished 是本次
/// 页面生命周期的终态。日记页在 Home 里一直保活，所以每次冷启动最多出现
/// 一次；累计出现 [FeatureTip.maxShows] 次或学会后，以后的启动都不再进入
/// scheduled。
class TagFilterPullHintController extends ChangeNotifier {
  TagFilterPullHintController({required TickerProvider vsync})
    : _peekController = AnimationController(vsync: vsync, duration: _peekTotal);

  static const FeatureTip _tip = FeatureTip.tagFilterPull;

  /// 条件满足后再等一会儿：首页刚落定时用户的注意力还在内容上，紧接着
  /// 出现会和入场编排抢戏。非动画计时。
  static const Duration showDelay = Duration(milliseconds: 900);

  /// 提示行停留多久后自动收起。非动画计时。
  static const Duration visibleDuration = Duration(seconds: 8);

  // 轻推演示：先停一个 medium 等提示行展开，standard 下探，停一个 fast，
  // 再 standard 弹回。全部由 ExpressiveMotion token 拼成。
  static final Duration _peekTotal =
      ExpressiveMotion.medium +
      ExpressiveMotion.standard +
      ExpressiveMotion.fast +
      ExpressiveMotion.standard;

  final AnimationController _peekController;

  /// 位移允许弹簧过冲：下探时略越过落点，弹回时可能略低于 0，由标签栏
  /// 夹到 0 以上。
  late final Animation<double> peek =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: ConstantTween<double>(0),
          weight: ExpressiveMotion.medium.inMilliseconds.toDouble(),
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 0,
            end: 1,
          ).chain(CurveTween(curve: ExpressiveMotion.spatial)),
          weight: ExpressiveMotion.standard.inMilliseconds.toDouble(),
        ),
        TweenSequenceItem<double>(
          tween: ConstantTween<double>(1),
          weight: ExpressiveMotion.fast.inMilliseconds.toDouble(),
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1,
            end: 0,
          ).chain(CurveTween(curve: ExpressiveMotion.spatial)),
          weight: ExpressiveMotion.standard.inMilliseconds.toDouble(),
        ),
      ]).animate(_peekController);

  SettingsService? _settings;
  FeatureTips _tips = FeatureTips.empty;
  _HintPhase _phase = _HintPhase.idle;
  bool _visible = false;
  bool _pageActive = false;
  bool _hasHiddenTags = false;
  bool _reduceMotion = false;
  bool _evaluateQueued = false;
  bool _disposed = false;
  Animation<double>? _reveal;
  Timer? _showTimer;
  Timer? _hideTimer;

  /// 提示行是否显示。
  bool get visible => _visible;

  bool get _revealed {
    final reveal = _reveal;
    return reveal != null && reveal.value >= 1;
  }

  bool get _eligible => _pageActive && _revealed && _hasHiddenTags;

  /// 在 build 里调用：只记下输入，评估推迟到这一帧结束后，免得在 build
  /// 期间通知页面重建。
  ///
  /// [reveal] 为 null（没有 `LaunchRevealScope`，即不在首页之内）时永不
  /// 提示；编排还没播完（应用锁盖着时会一直停在开头）时等它播完。
  void sync({
    required SettingsService settings,
    required Animation<double>? reveal,
    required bool pageActive,
    required bool reduceMotion,
  }) {
    if (_disposed) return;
    if (!identical(settings, _settings)) {
      _settings = settings;
      _tips = FeatureTips.decode(settings.featureTipsRaw);
    }
    _attachReveal(reveal);
    _pageActive = pageActive;
    _reduceMotion = reduceMotion;
    _scheduleEvaluate();
  }

  /// 标签栏在布局后（post-frame）回报收起的一行是否放不下全部标签；
  /// 没有被藏起来的标签时不提示，正在显示的也随之收起。
  void reportHiddenTags(bool hasHiddenTags) {
    if (_disposed || hasHiddenTags == _hasHiddenTags) return;
    _hasHiddenTags = hasHiddenTags;
    _evaluate();
  }

  /// 标签栏完全展开：用户会用这个功能了，记下后永不再提示。没看到提示、
  /// 自己展开过的同样算学会。
  void handleExpanded() {
    if (_disposed) return;
    final next = _tips.markLearned(_tip);
    if (!identical(next, _tips)) {
      _tips = next;
      _persist();
    }
    _finish();
  }

  /// 用户开始拖动标签栏或滑动日记列表。
  ///
  /// 正在显示时收起，本次启动不再出现（这次照常计入次数）：注意力已经转到
  /// 别处，提示行再留着只是占地方。还在等待时从现在起重新计时，免得在
  /// 操作途中冒出来、把列表往下推。
  void handleUserInteraction() {
    if (_disposed) return;
    switch (_phase) {
      case _HintPhase.showing:
        _finish();
      case _HintPhase.scheduled:
        _showTimer?.cancel();
        _showTimer = Timer(showDelay, _show);
      case _HintPhase.idle:
      case _HintPhase.finished:
        break;
    }
  }

  void _attachReveal(Animation<double>? reveal) {
    if (identical(reveal, _reveal)) return;
    _reveal?.removeListener(_handleRevealTick);
    _reveal = reveal;
    if (reveal != null && reveal.value < 1) {
      reveal.addListener(_handleRevealTick);
    }
  }

  void _handleRevealTick() {
    final reveal = _reveal;
    if (reveal == null || reveal.value < 1) return;
    reveal.removeListener(_handleRevealTick);
    _evaluate();
  }

  void _scheduleEvaluate() {
    if (_evaluateQueued) return;
    _evaluateQueued = true;
    final scheduler = SchedulerBinding.instance;
    scheduler.addPostFrameCallback((_) {
      _evaluateQueued = false;
      _evaluate();
    });
    // 帧回调本身不会请求新的一帧：在 build 里调用时当前帧结束就会执行，
    // 不在帧内（空闲时）调用则要补一帧，否则评估会一直等到下次重绘。
    scheduler.ensureVisualUpdate();
  }

  void _evaluate() {
    if (_disposed) return;
    switch (_phase) {
      case _HintPhase.idle:
        if (_eligible && _tips.shouldShow(_tip)) {
          _phase = _HintPhase.scheduled;
          _showTimer = Timer(showDelay, _show);
        }
      case _HintPhase.scheduled:
        if (!_eligible) {
          _showTimer?.cancel();
          _showTimer = null;
          _phase = _HintPhase.idle;
        }
      case _HintPhase.showing:
        if (!_eligible) _finish();
      case _HintPhase.finished:
        break;
    }
  }

  void _show() {
    _showTimer = null;
    if (_disposed || _phase != _HintPhase.scheduled) return;
    // 计时期间条件都经 _evaluate 跟进过，这里再确认一次兜底。
    if (!_eligible || !_tips.shouldShow(_tip)) {
      _phase = _HintPhase.idle;
      return;
    }
    _phase = _HintPhase.showing;
    _tips = _tips.markShown(_tip);
    _persist();
    _visible = true;
    notifyListeners();
    if (!_reduceMotion) {
      unawaited(_peekController.forward(from: 0));
    }
    _hideTimer = Timer(visibleDuration, _finish);
  }

  void _finish() {
    _showTimer?.cancel();
    _showTimer = null;
    _hideTimer?.cancel();
    _hideTimer = null;
    _phase = _HintPhase.finished;
    // 下探中途被打断（多半是用户开始拖动）时直接归零，交给拖动接手。
    _peekController.value = 0;
    if (_visible) {
      _visible = false;
      notifyListeners();
    }
  }

  /// 只把这条提示的进度合进设置里最新的整份进度（别的提示可能在这之后
  /// 写过，见 `SettingsService.updateFeatureTips`）。写失败只会让提示多
  /// 出现一次，不值得打扰用户，吞掉错误。
  void _persist() {
    final settings = _settings;
    if (settings == null) return;
    final record = _tips.recordOf(_tip);
    unawaited(
      settings
          .updateFeatureTips((latest) => latest.withRecord(_tip, record))
          .catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _reveal?.removeListener(_handleRevealTick);
    _peekController.dispose();
    super.dispose();
  }
}

enum _HintPhase { idle, scheduled, showing, finished }
