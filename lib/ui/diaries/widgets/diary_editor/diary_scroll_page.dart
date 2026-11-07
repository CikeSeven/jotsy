import 'package:appflowy_editor/appflowy_editor.dart' as af;
// 上游的页面块把正文交给内部的 ScrollablePositionedList，页头 / 页尾套
// IgnoreEditorSelectionGesture，两者都没有导出；这里按固定版本复刻页面块
// 的滚动分支（见 DiaryScrollPageBuilder）。
// ignore: implementation_imports
import 'package:appflowy_editor/src/editor/block_component/base_component/widget/ignore_parent_gesture.dart'
    show IgnoreEditorSelectionGesture;
// ignore: implementation_imports
import 'package:appflowy_editor/src/flutter/scrollable_positioned_list/scrollable_positioned_list.dart'
    show ScrollablePositionedList;
import 'package:flutter/material.dart';

import '../../models/diary_thumbnail_rows.dart';
import 'diary_thumbnail_row.dart';

/// 可滚动编辑器的页面块：与上游 `PageBlockComponent` 的滚动分支逐项相同，
/// 只多一层记忆——同一次页面构建内，每一项（页头、各顶层块、页尾）只构建
/// 一次。
///
/// 为什么：上游的 ScrollablePositionedList 在 LayoutBuilder 里按视口高度计算
/// 缓存范围，高度一变就重建整张列表。软键盘升降时 Scaffold 逐帧缩小 body，
/// 可见的每个段落块（连同选区层与文字排版）因此逐帧重建，键盘拉起、收起
/// 明显卡顿。这些重建的输入（节点、渲染器、样式）都没有变：交回上一次的
/// widget 实例，框架在每一项止步；块自己的内容变化仍由各块的
/// `Consumer<Node>` 刷新，选区由块内的监听刷新。
///
/// 记忆随页面构建失效：页面块每次重建（顶层块增删、换渲染器或样式而换上
/// 新的编辑器）都会生成新的 itemBuilder 闭包，带着空的记忆，所有项照上游
/// 重建（如有序列表的序号跟着前后块变化）。收缩（shrinkWrap）的编辑器原样
/// 交给上游页面块。
///
/// 与上游唯一的不同：顶层连续的小图三张一排（diary_thumbnail_rows.dart），
/// 一排画在它第一张那一项里，其余的项为空。分排变了也整页重建
/// （[DiaryThumbnailRowsBuilder]）。
class DiaryScrollPageBuilder extends af.BlockComponentBuilder {
  DiaryScrollPageBuilder({required this.state, required this.scroll});

  final af.EditorState state;

  /// 交给上游编辑器的同一个滚动控制器（上游页面块从 Provider 读它）。
  final af.EditorScrollController scroll;

  @override
  af.BlockComponentWidget build(af.BlockComponentContext context) =>
      _DiaryScrollPage(
        key: context.node.key,
        node: context.node,
        state: state,
        scroll: scroll,
        header: context.header,
        footer: context.footer,
        wrapper: context.wrapper,
      );
}

class _DiaryScrollPage extends af.BlockComponentStatelessWidget {
  const _DiaryScrollPage({
    super.key,
    required super.node,
    required this.state,
    required this.scroll,
    this.header,
    this.footer,
    this.wrapper,
  }) : super(configuration: const af.BlockComponentConfiguration());

  final af.EditorState state;
  final af.EditorScrollController scroll;
  final Widget? header;
  final Widget? footer;
  final af.BlockComponentWrapper? wrapper;

  @override
  Widget build(BuildContext context) {
    if (scroll.shrinkWrap) {
      return af.PageBlockComponent(
        node: node,
        header: header,
        footer: footer,
        wrapper: wrapper,
      );
    }
    // 分排变了（某张图片设为 / 取消小图）也要整页重建，见该组件。
    return DiaryThumbnailRowsBuilder(
      state: state,
      root: node,
      builder: _buildList,
    );
  }

  Widget _buildList(BuildContext context) {
    final header = this.header;
    final footer = this.footer;
    final wrapper = this.wrapper;
    final items = node.children;
    final extentCount = (header == null ? 0 : 1) + (footer == null ? 0 : 1);
    final itemCount = items.length + extentCount;
    // 本次构建的记忆：下标 → 已构建的项（见类注释）。
    final built = <int, Widget>{};

    Widget block(BuildContext context, af.Node node) {
      final child = state.renderer.build(context, node);
      return wrapper == null
          ? child
          : wrapper(context, node: node, child: child);
    }

    Widget buildItem(BuildContext context, int index) {
      if (header != null && index == 0) {
        return IgnoreEditorSelectionGesture(child: header);
      }
      if (footer != null && index == itemCount - 1) {
        return IgnoreEditorSelectionGesture(child: footer);
      }
      final position = index - (header == null ? 0 : 1);
      final node = items[position];
      // 并排的小图都画在这一排第一张那一项里（DiaryThumbnailRowView），其余
      // 的项是空的：列表的下标仍与顶层块一一对应，上游按下标算可见范围、
      // 跳转都不受影响。
      final row = diaryThumbnailRowOf(node);
      if (row != null && row.start != position) return const SizedBox.shrink();
      final Widget child;
      if (row != null && row.end - row.start > 1) {
        child = DiaryThumbnailRowView(
          align: node.attributes['align'],
          children: [
            for (var i = row.start; i < row.end; i++) block(context, items[i]),
          ],
        );
      } else {
        child = block(context, node);
      }
      return Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: state.editorStyle.maxWidth ?? double.infinity,
          ),
          padding: state.editorStyle.padding,
          child: child,
        ),
      );
    }

    return ScrollablePositionedList.builder(
      shrinkWrap: scroll.shrinkWrap,
      itemCount: itemCount,
      itemBuilder: (BuildContext context, int index) {
        // 与上游相同，每次取项都把当前的滚动视图交给自动滚动。
        state.updateAutoScroller(Scrollable.of(context));
        return built[index] ??= buildItem(context, index);
      },
      itemScrollController: scroll.itemScrollController,
      scrollOffsetController: scroll.scrollOffsetController,
      itemPositionsListener: scroll.itemPositionsListener,
      scrollOffsetListener: scroll.scrollOffsetListener,
    );
  }
}
