// 流式回答的“匀速释放”：网络一阵一阵地送来文字，直接显示会一顿一顿地成块
// 蹦出来；这里把已经收到的文字按稳定的速度逐字放出，观感连贯。
//
// 输入：已经收到的全文（不断变长）与它是否还在生成。
// 输出：只画出“放到这里”的那一段 Markdown（流式增量解析、新段淡入）。
// 副作用：无。这只是显示层的节奏——停止、复制、落库用的始终是控制器里的
//         完整文字，与这里放到哪里无关。
//
// 节奏（[AiRevealPace]）：积压（收到而还没放出的字数）按“大约 0.35 秒内放
// 完”定速度，不低于每秒 40 字。模型稳定输出时，显示落后约三分之一秒、匀速
// 跟随；一下子来了一大段就自动加速，不会越落越远；流结束后剩下的也在同一个
// 时间量级内放完。
//
// 生命周期与边界：
// - 逐帧由 `Ticker` 推进（跟随屏幕刷新率，页面被盖住时随 `TickerMode` 暂停），
//   没有积压就停表，文字变长时再开；只有放出的字数变了才重建。
// - 系统开着“减少动画”时不做节奏，收到多少显示多少。
// - 进行中的那一项与落库后的那条回答是列表里两个不同的组件：生成结束的
//   那一帧前者换成后者。[AiRevealHandoff] 记着放到了哪里，后者接着放完，
//   结尾不会突然跳出一截。隔了一阵才重新建立（滚出屏幕又回来）时不接着
//   放，直接显示全部——不把看过的内容重播一遍。
// - 切开的位置不落在代理对中间（表情符号等），免得闪一个乱码。

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme/expressive_motion.dart';
import '../viewmodels/ai_citations.dart';
import 'ai_markdown_view.dart';

/// 释放速度的计算（纯函数，便于测试）。
abstract final class AiRevealPace {
  /// 积压在这么久之内放完（秒）。
  static const double catchUpSeconds = 0.35;

  /// 最低速度（字 / 秒）：积压很少时也不拖沓。
  static const double minRate = 40;

  /// 已经放出 [shown]（可带小数）、共收到 [total] 字，过了 [seconds] 秒之后
  /// 应该放到哪里。不会超过 [total]。
  static double advance(double shown, int total, double seconds) {
    final backlog = total - shown;
    if (backlog <= 0 || seconds <= 0) {
      return shown > total ? total + 0.0 : shown;
    }
    final rate = backlog / catchUpSeconds > minRate
        ? backlog / catchUpSeconds
        : minRate;
    final next = shown + rate * seconds;
    return next > total ? total + 0.0 : next;
  }

  /// 把切开的位置挪到不拆开代理对的地方（落在低位代理上就往后挪一位）。
  static int safeCut(String text, int index) {
    if (index <= 0) return 0;
    if (index >= text.length) return text.length;
    final unit = text.codeUnitAt(index);
    return unit >= 0xDC00 && unit <= 0xDFFF ? index + 1 : index;
  }
}

/// 进行中的那一项与落库后的回答之间交接“放到了哪里”。对话页持有一个，
/// 传给进行中的回答与最后一条回答。
class AiRevealHandoff {
  String _text = '';
  int _shown = 0;
  final Stopwatch _sinceUpdate = Stopwatch();

  /// 交接的有效期：超过这么久没有更新就算“隔了一阵”。
  static const Duration freshness = Duration(seconds: 1);

  /// 记下这一刻放到了哪里。
  void update(String text, int shown) {
    _text = text;
    _shown = shown;
    _sinceUpdate
      ..reset()
      ..start();
  }

  /// [text] 是不是刚才那段文字（或它的延长）。还什么都没放出过时不算——
  /// 空前缀与任何文字都“对得上”，新的一轮会被当成放完了的旧回答。
  bool matches(String text) =>
      _shown > 0 &&
      _shown <= _text.length &&
      text.startsWith(_text.substring(0, _shown));

  /// 刚刚还在放（可以接着放）。
  bool get fresh => _sinceUpdate.isRunning && _sinceUpdate.elapsed < freshness;

  int get shown => _shown;
}

/// 按节奏放出的回答正文。
class AiRevealedMarkdown extends StatefulWidget {
  const AiRevealedMarkdown({
    super.key,
    required this.text,
    required this.live,
    this.handoff,
    this.onCitation,
    this.bodyStyle,
  });

  /// 已经收到的全文。
  final String text;

  /// 还在生成（文字会继续变长）。
  final bool live;

  final AiRevealHandoff? handoff;
  final ValueChanged<String>? onCitation;
  final TextStyle? bodyStyle;

  @override
  State<AiRevealedMarkdown> createState() => _AiRevealedMarkdownState();
}

class _AiRevealedMarkdownState extends State<AiRevealedMarkdown>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);

  /// 放到了哪里（带小数，逐帧累加）。
  double _shown = 0;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _shown = _initialShown().toDouble();
  }

  /// 建立时从哪里开始：接着刚才那一项放；隔了一阵或对不上时，进行中的从头
  /// 放（新的一轮），已经落库的直接显示全部。
  int _initialShown() {
    final text = widget.text;
    final handoff = widget.handoff;
    if (handoff != null && handoff.matches(text)) {
      return handoff.fresh ? handoff.shown : text.length;
    }
    return widget.live ? 0 : text.length;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AiRevealedMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换了一段文字（不是原来的延长）：从头来过。
    if (!widget.text.startsWith(oldWidget.text)) {
      _shown = widget.live ? 0 : widget.text.length.toDouble();
    }
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// 有积压就开表，没有就停；减少动画时直接放完。
  void _sync() {
    final total = widget.text.length;
    if (_shown > total) _shown = total.toDouble();
    if (ExpressiveMotion.reduceMotion(context)) {
      _shown = total.toDouble();
    }
    if (_shown < total) {
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
    // 只有还在生成或还在放的才记进交接：早已放完的旧回答重建时不去覆盖
    // 正在进行的那一项记下的位置。
    if (widget.live || _shown < total) {
      widget.handoff?.update(widget.text, _cut);
    }
  }

  void _onTick(Duration elapsed) {
    final seconds = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final total = widget.text.length;
    final before = _cut;
    _shown = AiRevealPace.advance(_shown, total, seconds);
    if (_shown >= total) _ticker.stop();
    final after = _cut;
    if (after != before) {
      widget.handoff?.update(widget.text, after);
      setState(() {});
    }
  }

  /// 这一帧显示到哪个位置。
  int get _cut => AiRevealPace.safeCut(widget.text, _shown.floor());

  @override
  Widget build(BuildContext context) {
    final cut = _cut;
    final done = cut >= widget.text.length;
    return AiMarkdownView(
      markdown: aiNormalizeCitations(
        done ? widget.text : widget.text.substring(0, cut),
      ),
      onCitation: widget.onCitation,
      bodyStyle: widget.bodyStyle,
      // 生成结束并放完之后换成整段解析（引用式链接等以整段为准）。
      streaming: widget.live || !done,
    );
  }
}
