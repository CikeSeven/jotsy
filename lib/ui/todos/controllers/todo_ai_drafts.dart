import 'package:flutter/foundation.dart';

import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/http_cancel_token.dart';
import '../../ai/controllers/ai_stream_run.dart';

/// 把已收到的全部文字解析成此刻的全部建议；[complete] 为生成已正常结束。
typedef TodoAiParse<T> =
    List<T> Function(String text, {required bool complete});

/// 一次待办 AI 生成的预览（详情的“AI 拆解”与快速新建的“AI 整理”共用）。
///
/// - 流式生成交给 [AiStreamRun]（取消、合帧通知、出错都在那里）；每次它
///   通知，就把全部已收文字重新解析一遍（[TodoAiParse]，纯函数）：已经
///   长出来的建议不会变，新收完一整行就多出一条，预览里逐条长出；
/// - 用户可以勾掉某条（[toggle]）、改写某条（[edit]）。勾选与改写按位置
///   记，解析结果只会在末尾变长，位置不会错开；
/// - 状态：[active] 为 false 时不显示；[start] 后为生成中，结束、停止或
///   出错后结果留着（停止 / 出错时保留已收完的行），直到 [reset]。
class TodoAiDrafts<T> extends ChangeNotifier {
  TodoAiDrafts(this._parse) {
    _run.addListener(_onRun);
  }

  final TodoAiParse<T> _parse;
  final AiStreamRun _run = AiStreamRun();
  List<T> _parsed = <T>[];
  final Map<int, T> _edits = <int, T>{};
  final Set<int> _off = <int>{};
  bool _active = false;
  bool _disposed = false;

  /// 预览是否显示（开始后到 [reset] 之前）。
  bool get active => _active;
  bool get running => _run.running;
  AiRunStatus get status => _run.status;
  Object? get error => _run.error;

  /// 此刻的全部建议（含改写过的）。
  List<T> get items => <T>[
    for (var i = 0; i < _parsed.length; i++) _edits[i] ?? _parsed[i],
  ];

  bool isOn(int index) => !_off.contains(index);

  /// 勾着的建议，按原先后。
  List<T> get chosen => <T>[
    for (var i = 0; i < _parsed.length; i++)
      if (!_off.contains(i)) _edits[i] ?? _parsed[i],
  ];

  /// 开始一次生成（取代上一次）。返回时生成已经结束。
  Future<void> start(Stream<AiChunk> Function(HttpCancelToken token) open) {
    _active = true;
    _parsed = <T>[];
    _edits.clear();
    _off.clear();
    return _run.start(open);
  }

  /// 停止生成，已收完的行留着。
  void stop() => _run.stop();

  /// 收起预览、丢掉结果（停止还在进行的生成）。
  void reset() {
    _active = false;
    _parsed = <T>[];
    _edits.clear();
    _off.clear();
    _run.reset();
  }

  void toggle(int index) {
    if (!_off.remove(index)) _off.add(index);
    notifyListeners();
  }

  void edit(int index, T value) {
    if (index < 0 || index >= _parsed.length) return;
    _edits[index] = value;
    notifyListeners();
  }

  void _onRun() {
    if (_disposed) return;
    if (_active) {
      _parsed = _parse(_run.text, complete: _run.status == AiRunStatus.done);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _run.removeListener(_onRun);
    _run.dispose();
    super.dispose();
  }
}
