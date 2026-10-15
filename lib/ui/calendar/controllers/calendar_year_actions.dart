part of 'package:node_diary/ui/calendar/pages/calendar_page.dart';

/// 年视图的操作：切换着色依据、把整年网格导出为图片分享。
extension _CalendarYearActions on _CalendarPageController {
  /// 着色依据随显示选项保存，下次打开年视图沿用。
  void setYearBasis(CalendarYearBasis basis) {
    final options = _state._displayOptions;
    if (options.yearBasis == basis) {
      return;
    }
    saveDisplayOptions(options.copyWith(yearBasis: basis));
  }

  /// 截取年视图的“年份 + 网格 + 图例”区域为 PNG，交给系统分享面板。
  ///
  /// 流程：标记导出中（按钮禁用、页面遮罩在 300ms 后淡入）→ 等遮罩所在帧
  /// 提交 → 按设备像素比（2~3 倍）截图 → 写入临时目录 → 分享。截图区不在
  /// 屏幕上（年视图已关闭）时直接放弃；失败以本地化提示告知，不暴露底层
  /// 异常文本。
  Future<void> exportYearImage() async {
    if (_state._exportingYear) {
      return;
    }
    final year = _state._focusedMonth.year;
    final l10n = _state.context.l10n;
    final pixelRatio = MediaQuery.devicePixelRatioOf(
      _state.context,
    ).clamp(2.0, 3.0);
    _state.applyState(() => _state._exportingYear = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _state._yearCaptureKey.currentContext
          ?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        return;
      }
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? data;
      try {
        data = await image.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        image.dispose();
      }
      if (data == null) {
        throw StateError('Year image encoding returned no bytes');
      }
      final directory = await getTemporaryDirectory();
      final file = File(p.join(directory.path, 'jotsy_year_$year.png'));
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      await Share.shareXFiles(<XFile>[XFile(file.path)]);
    } catch (_) {
      if (_state.mounted) {
        unawaited(
          HomeHintVisibilityScope.showTrackedSnackBar(
            context: _state.context,
            snackBar: SnackBar(content: Text(l10n.calendarYearExportFailed)),
          ),
        );
      }
    } finally {
      _state.applyState(() => _state._exportingYear = false);
    }
  }
}
