import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 只在 [selector] 选出的片段变化时重建的 [ValueListenableBuilder]。
///
/// 多个区块监听同一个草稿时（如发布面板的封面、标签、心情、精力），拖动
/// 精力滑块每一格都会通知全部监听者；用它让每个区块只关心自己的字段，其余
/// 区块不重建。选出的值按 `==` 比较，记录（record）可以组合多个字段。
class ValueListenableSelector<T, S> extends StatefulWidget {
  const ValueListenableSelector({
    super.key,
    required this.valueListenable,
    required this.selector,
    required this.builder,
    this.child,
  });

  final ValueListenable<T> valueListenable;
  final S Function(T value) selector;
  final ValueWidgetBuilder<S> builder;
  final Widget? child;

  @override
  State<ValueListenableSelector<T, S>> createState() =>
      _ValueListenableSelectorState<T, S>();
}

class _ValueListenableSelectorState<T, S>
    extends State<ValueListenableSelector<T, S>> {
  late S _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selector(widget.valueListenable.value);
    widget.valueListenable.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant ValueListenableSelector<T, S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueListenable != widget.valueListenable) {
      oldWidget.valueListenable.removeListener(_onChanged);
      widget.valueListenable.addListener(_onChanged);
    }
    // selector 可能是新的闭包（捕获了新的外部值），按当前值重新选取。
    _selected = widget.selector(widget.valueListenable.value);
  }

  @override
  void dispose() {
    widget.valueListenable.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final next = widget.selector(widget.valueListenable.value);
    if (next != _selected) {
      setState(() => _selected = next);
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _selected, widget.child);
}
