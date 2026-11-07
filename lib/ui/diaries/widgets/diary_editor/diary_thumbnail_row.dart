import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../widgets/width_layout_builder.dart';
import '../../models/diary_thumbnail_rows.dart';
import '../diary_image_thumbnail.dart';

/// 页面块（`DiaryScrollPage` / `DiaryInlinePage`）里并排的一排小图。
///
/// 输入是这一排每张小图已经建好的块组件（`state.renderer.build`，各自带着
/// `node.key`）：每块仍是完整的图片块，选区、光标、点按菜单、退格选中都照
/// 常；这里只负责横着摆。每格宽为同一个边长（[diaryThumbnailExtentFor]，按
/// 整排的宽度算，经 [DiaryThumbnailExtent] 交给每张小图），格间
/// [kDiaryThumbnailRowGap]；整排按第一张的对齐靠行首 / 居中 / 居右。
///
/// 只按宽度构建（[WidthLayoutBuilder]）：键盘升降逐帧改变高度时不重建这一
/// 排。
class DiaryThumbnailRowView extends StatelessWidget {
  const DiaryThumbnailRowView({
    super.key,
    required this.align,
    required this.children,
  });

  /// 第一张图片块的 `data.align`（center / right，其余靠行首）。
  final Object? align;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => WidthLayoutBuilder(
    builder: (context, width) {
      final extent = diaryThumbnailExtentFor(width);
      return DiaryThumbnailExtent(
        extent: extent,
        child: Align(
          alignment: switch (align) {
            'center' => Alignment.center,
            'right' => Alignment.centerRight,
            _ => AlignmentDirectional.centerStart,
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: kDiaryThumbnailRowGap),
                SizedBox(width: extent, child: children[i]),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// 顶层块的分排（[diaryThumbnailRows]）变了才重建 [builder]。
///
/// 为什么要单独监听：页面块只在顶层块增删时重建（上游根节点的通知），
/// 某张图片设为 / 取消小图只通知它自己——它还画在原来那一项里，一排的
/// 划分却已经变了。这里在每个事务应用后（事务流同步广播，与节点通知同一
/// 帧）重算分排，有变化就重建列表：一排的几块挪进第一张那一项、其余项
/// 变空，块组件带着 `node.key` 在同一帧里换位置，不会出现同一个 key 两处
/// 都有。页面块重建（顶层块增删）时也重算。
class DiaryThumbnailRowsBuilder extends StatefulWidget {
  const DiaryThumbnailRowsBuilder({
    super.key,
    required this.state,
    required this.root,
    required this.builder,
  });

  final af.EditorState state;

  /// 页面根节点。
  final af.Node root;

  /// 每次调用都应生成新的列表项（分排变了，旧的项不能沿用）。
  final WidgetBuilder builder;

  @override
  State<DiaryThumbnailRowsBuilder> createState() =>
      _DiaryThumbnailRowsBuilderState();
}

class _DiaryThumbnailRowsBuilderState extends State<DiaryThumbnailRowsBuilder> {
  /// 上一次构建时的分排。在 initState 里算好：不能是惰性初值，否则第一次
  /// 读取已在改动之后，比较不出变化。
  late List<DiaryThumbnailRow> _rows;
  StreamSubscription<af.EditorTransactionValue>? _edits;

  List<DiaryThumbnailRow> _compute() =>
      diaryThumbnailRows(widget.root.children.toList(growable: false));

  @override
  void initState() {
    super.initState();
    _rows = _compute();
    _listen();
  }

  void _listen() {
    _edits = widget.state.transactionStream.listen((event) {
      if (event.$1 == af.TransactionTime.after) _refresh();
    });
  }

  void _refresh() {
    if (!mounted) return;
    // 构建、布局途中应用的事务（个别块在回调里改文档）不能当场标脏，留到
    // 这一帧结束；其余（点按、打字、菜单）当场重建，与节点通知同一帧。
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _refresh());
      return;
    }
    final next = _compute();
    if (!listEquals(next, _rows)) setState(() => _rows = next);
  }

  @override
  void didUpdateWidget(DiaryThumbnailRowsBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      unawaited(_edits?.cancel());
      _listen();
    }
    _rows = _compute();
  }

  @override
  void dispose() {
    unawaited(_edits?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
