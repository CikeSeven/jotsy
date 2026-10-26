import 'dart:async';

import 'package:flutter/foundation.dart';
import 'diary_editor_controller.dart';

import '../models/diary_code_block/diary_code_highlighter.dart';

// 未指定语言的代码块的自动识别结果，每个 DiaryEditorController 一份。
//
// 输入：渲染时传入的代码块（Node 节点）与它当前的纯文本。
// 输出：该块用于高亮的语言 id（认不出时为 null）；识别结果变化时通知监听者
// （正文样式构建器据此重建，标题栏与工具栏的语言名也读同一份）。
// 副作用：一个 600ms 的防抖计时器（非动画计时）。
//
// 为什么“粘住旧结果 + 防抖重识别”：
// - 自动识别看的是整块文本，边打字边识别时，半截代码经常在几种语言之间
//   来回跳（`def` 还没写完像 Ruby，写完像 Python），每敲一个字整块颜色都
//   跟着闪；
// - 有界的语法特征扫描虽然便宜，连续输入仍只需合并识别一次，避免无谓唤醒。
// 所以文本变了先沿用上一次的结果（不闪），停手 600ms 后再统一重识别，只在
// 结果真的变了时才通知一次。第一次见到某个块（打开日记、粘贴进来）没有
// 旧结果可用，同步识别一次，首帧就是正确的颜色。
//
// 用 Expando 挂在控制器与 Node 上：编辑器、代码块标题栏与工具栏面板各自
// 拿到同一份结果，块被删除或控制器释放后随之回收，不需要显式注销。

/// 代码块语言自动识别的共享状态；用 [DiaryBlockLanguageTracker.of] 获取。
class DiaryBlockLanguageTracker extends ChangeNotifier {
  DiaryBlockLanguageTracker._();

  /// 停手多久后重新识别（非动画计时，不走 ExpressiveMotion）。
  static const Duration debounce = Duration(milliseconds: 600);

  static final Expando<DiaryBlockLanguageTracker> _trackers =
      Expando<DiaryBlockLanguageTracker>('diaryCodeLanguageTracker');

  /// [controller] 的识别状态；首次调用时创建，之后同一控制器返回同一份
  /// （已被释放的会换一份新的）。
  static DiaryBlockLanguageTracker of(DiaryEditorController controller) {
    final existing = _trackers[controller];
    if (existing != null && !existing._disposed) {
      return existing;
    }
    return _trackers[controller] = DiaryBlockLanguageTracker._();
  }

  final Expando<_Detection> _detections = Expando<_Detection>(
    'diaryCodeLanguageDetection',
  );

  /// 等待重识别的块。按身份比较：Node 未覆写 ==，这里显式写明。
  final Set<Node> _pending = Set<Node>.identity();
  Timer? _timer;
  bool _disposed = false;

  /// [block] 当前用于高亮的语言 id（只用于未指定语言的块）。
  ///
  /// - 第一次见到该块：同步识别并记住；
  /// - 文本与上次识别时相同：直接返回记住的结果；
  /// - 文本变了：返回上次的结果（不闪），并（重新）开始防抖计时，停手后
  ///   统一重识别。
  String? languageFor(Node block, String text) {
    final detection = _detections[block];
    if (detection == null) {
      _detections[block] = _Detection(
        text,
        DiaryCodeHighlighter.instance.detect(text),
      );
      return _detections[block]!.id;
    }
    if (detection.text == text) {
      if (detection.pendingText != null) {
        // 改回了识别时的文本：之前排队的重识别已无必要。
        cancelPendingFor(block);
      }
      return detection.id;
    }
    if (detection.pendingText != text && !_disposed) {
      // 只有文本又变了才重新计时；同一份文本的重复构建（选区变化、主题
      // 切换引起的重建）不推迟识别。
      detection.pendingText = text;
      _pending.add(block);
      _timer?.cancel();
      _timer = Timer(debounce, _redetect);
    }
    return detection.id;
  }

  /// 上一次识别出的语言；不触发识别。没见过该块时为 null。
  String? lastDetected(Node block) => _detections[block]?.id;

  /// 切为手选/纯文本、关闭自动识别或超出渲染上限后，不再为这一块唤醒计时器。
  /// 保留旧结果，切回自动时仍可立即显示；如果内容变过，再按正常流程排队。
  void cancelPendingFor(Node block) {
    _detections[block]?.pendingText = null;
    _pending.remove(block);
    if (_pending.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _redetect() {
    _timer = null;
    if (_disposed) {
      return;
    }
    var changed = false;
    for (final block in _pending) {
      if (block.parent == null) {
        _detections[block]?.pendingText = null;
        continue;
      }
      final detection = _detections[block];
      final text = detection?.pendingText;
      if (detection == null || text == null) {
        continue;
      }
      final id = DiaryCodeHighlighter.instance.detect(text);
      detection
        ..text = text
        ..pendingText = null;
      if (id != detection.id) {
        detection.id = id;
        changed = true;
      }
    }
    _pending.clear();
    if (changed) {
      notifyListeners();
    }
  }

  /// 最后一个监听者离开时（编辑器关闭）丢弃排队的重识别：没有人再显示
  /// 结果，也不留下悬空的计时器。旧结果保留，再次显示时按文本是否变化
  /// 重新排队。
  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _cancelPending();
    }
  }

  void _cancelPending() {
    _timer?.cancel();
    _timer = null;
    for (final block in _pending) {
      _detections[block]?.pendingText = null;
    }
    _pending.clear();
  }

  @override
  void dispose() {
    _cancelPending();
    _disposed = true;
    super.dispose();
  }
}

/// 某个块最近一次识别：识别时的文本、结果，以及等待重识别的新文本。
class _Detection {
  _Detection(this.text, this.id);

  String text;
  String? id;
  String? pendingText;
}
