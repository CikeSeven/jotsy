import 'package:flutter/foundation.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../ai/controllers/ai_stream_run.dart';
import '../viewmodels/mind_map_ai_prompts.dart';

/// 导图 AI 面板做的事。
enum MindMapAiTask {
  /// 按主题生成整张导图（替换当前导图）。
  generate,

  /// 给选中的主题添加子主题。
  expand,

  /// 由一篇文字日记生成一篇新的导图日记。
  fromDiary,

  /// 总结整张导图（回复是文字）。
  summarize,
}

/// 一次导图 AI 生成：流式接收（状态只经 [AiStreamRun]，可停止），边收边把
/// 到目前为止的文字解析成预览——生成整张图时为 [map]，添加子主题时为
/// [branches]，总结时只有文字 [AiStreamRun.text]。
///
/// 生命周期：面板持有并在关闭时 [dispose]（进行中的请求随之取消）；每次
/// [start] 取代上一次。解析结果按文字缓存，同一段文字只解析一次。
class MindMapAiSession extends ChangeNotifier {
  MindMapAiSession(this.task) {
    run.addListener(_onRun);
  }

  final MindMapAiTask task;
  final AiStreamRun run = AiStreamRun();

  /// 生成整张图时固定的中心主题（用户填的主题；为空时用模型给的）。
  String _topic = '';

  String? _parsedFrom;
  MindMapNode? _map;
  List<MindMapNode> _branches = const <MindMapNode>[];

  /// 生成整张图（生成 / 由日记生成）时到目前为止的中心主题。
  MindMapNode? get map => _map;

  /// 添加子主题时到目前为止的新子主题。
  List<MindMapNode> get branches => _branches;

  /// 预览里的主题数（不含中心主题；子主题含下一级）。
  int get topicCount {
    int count(MindMapNode node) =>
        node.children.fold(node.children.length, (sum, c) => sum + count(c));
    return switch (task) {
      MindMapAiTask.expand => _branches.fold(
        _branches.length,
        (sum, branch) => sum + count(branch),
      ),
      MindMapAiTask.generate ||
      MindMapAiTask.fromDiary => _map == null ? 0 : count(_map!),
      MindMapAiTask.summarize => 0,
    };
  }

  /// 已经结束且读得出可用的结果（总结为有文字）。
  bool get hasUsableResult {
    if (!run.hasResult) return false;
    return switch (task) {
      MindMapAiTask.expand => _branches.isNotEmpty,
      MindMapAiTask.generate ||
      MindMapAiTask.fromDiary => _map != null && _map!.children.isNotEmpty,
      MindMapAiTask.summarize => run.text.trim().isNotEmpty,
    };
  }

  /// 正常结束却读不出任何主题（提示换个说法再试）。
  bool get finishedEmpty =>
      run.status == AiRunStatus.done &&
      task != MindMapAiTask.summarize &&
      !hasUsableResult;

  /// 开始一次生成。[topic] 只对整张图有用。
  Future<void> start({
    required AiService service,
    required AiResolvedModel model,
    required AiRequest request,
    String topic = '',
  }) {
    _topic = topic;
    _parsedFrom = null;
    _map = null;
    _branches = const <MindMapNode>[];
    return run.start(
      (token) => service.stream(model, request, cancelToken: token),
    );
  }

  void stop() => run.stop();

  void _onRun() {
    final text = run.text;
    if (text != _parsedFrom) {
      _parsedFrom = text;
      switch (task) {
        case MindMapAiTask.generate || MindMapAiTask.fromDiary:
          _map = mindMapAiParseMap(text, topic: _topic);
        case MindMapAiTask.expand:
          _branches = mindMapAiParseBranches(text);
        case MindMapAiTask.summarize:
          break;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    run
      ..removeListener(_onRun)
      ..dispose();
    super.dispose();
  }
}
