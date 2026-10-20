import 'package:flutter/foundation.dart';

/// 样式编辑页（卡片样式、预览页样式、代码块样式）共用的草稿与写入编排。
///
/// 输入：持久化的 raw 字符串（经 [rawNotifier] 读取并监听）与它的解码、
/// 写入函数；[T] 是整体写入的设置（可能另带“我的样式”、阅读行为等），
/// [S] 是正在编辑的样式，二者经 [currentOf] / [withCurrent] 互换（设置本身
/// 就是样式时两者都是恒等）。输出：当前样式与预览明暗，以及预览、提交、
/// 整体套用与重置动作。副作用：经 [persist] 写入设置。
///
/// 写入时机：
/// - 开关、单选与滑块松手（[commit]）即写入，真实页面随即生效；
/// - 滑块拖动中只更新草稿（[preview]），预览即时重绘但不写盘——否则每帧
///   一次写入，还会让后方的真实页面跟着逐帧重建。
///
/// 外部改动（备份恢复、失败回滚）经 [rawNotifier] 同步进来并丢弃草稿。写盘
/// 失败不打断编辑：内存里的样式已经生效，与日历显示选项的处理一致。
abstract class StyleDraftController<T, S> extends ChangeNotifier {
  StyleDraftController({
    required this.rawNotifier,
    required this.decode,
    required this.persist,
    required this.currentOf,
    required this.withCurrent,
    required this.defaultStyle,
  }) : _stored = decode(rawNotifier.value) {
    rawNotifier.addListener(_syncFromStorage);
  }

  final ValueListenable<String?> rawNotifier;
  final T Function(String? raw) decode;
  final Future<void> Function(T value) persist;

  /// 从整体设置里取出正在编辑的样式。
  final S Function(T value) currentOf;

  /// 把样式写回整体设置（其余部分保持不变）。
  final T Function(T value, S style) withCurrent;
  final S defaultStyle;

  T _stored;
  S? _draft;
  Brightness? _previewBrightness;
  bool _disposed = false;

  /// 已写入（或正在写入）的整体设置，不含拖动中的草稿。
  @protected
  T get stored => _stored;

  /// 预览与各分组展示的样式：拖动中的草稿优先。
  S get style => _draft ?? currentOf(_stored);

  /// 预览的明暗；null 表示跟随应用当前主题。
  Brightness? get previewBrightness => _previewBrightness;

  set previewBrightness(Brightness? value) {
    if (value == _previewBrightness) {
      return;
    }
    _previewBrightness = value;
    notify();
  }

  /// 拖动中的即时预览，不写盘。
  void preview(S next) {
    if (next == style) {
      return;
    }
    _draft = next;
    notify();
  }

  /// 写入新样式（并丢弃草稿）。
  Future<void> commit(S next) {
    _draft = null;
    return save(withCurrent(_stored, next));
  }

  /// 整体替换当前样式（套用预设、我的样式、导入或撤销）；返回此前的样式。
  Future<S> applyStyle(S next) async {
    final previous = style;
    await commit(next);
    return previous;
  }

  /// 恢复默认样式；返回此前的样式供撤销。
  Future<S> reset() => applyStyle(defaultStyle);

  /// 丢弃拖动中的草稿，回到已写入的样式（子类整体写入前调用）。
  @protected
  void dropDraft() => _draft = null;

  /// 写入整体设置；与当前相同时只刷新监听者。
  @protected
  Future<void> save(T next) async {
    if (next == _stored) {
      notify();
      return;
    }
    _stored = next;
    notify();
    try {
      await persist(next);
    } catch (error, stackTrace) {
      // 外观偏好写盘失败不打断编辑：内存与真实页面已经生效。
      debugPrint('Failed to persist style settings: $error\n$stackTrace');
    }
  }

  @protected
  void notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _syncFromStorage() {
    final next = decode(rawNotifier.value);
    if (next == _stored) {
      return;
    }
    _stored = next;
    _draft = null;
    notify();
  }

  @override
  void dispose() {
    _disposed = true;
    rawNotifier.removeListener(_syncFromStorage);
    super.dispose();
  }
}
