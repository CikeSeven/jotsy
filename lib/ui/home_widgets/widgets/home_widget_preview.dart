// 小组件的实时预览：嵌入原生按同一份代码画出来的真实小组件（PlatformView
// `com.jotsy.diary/home_widget_preview`，`WidgetPreviewView.kt`），所见即所得。
//
// 原生用最新的快照（数据、文案）加上这里传入的配置绘制；草稿里还没进快照的
// 自选配色随参数一起传过去。配置变化时经通道 `update` 重画同一个视图，不重建
// PlatformView。
//
// 只有真机的 Android 工程注册了这个视图：其他平台与 widget 测试里画一个
// 同尺寸的占位（种类图标与名字），页面布局不受影响。

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/home_widgets/home_widget_kind.dart';
import '../../../l10n/app_localizations.dart';
import '../models/home_widget_cell_size.dart';
import 'home_widget_kind_labels.dart';

const String _viewType = 'com.jotsy.diary/home_widget_preview';
const MethodChannel _channel = MethodChannel(
  'com.jotsy.diary/home_widget_preview',
);

/// 原生预览视图是否可用（真机 Android）。运行时判断留在原生视图旁边：
/// widget 测试的目标平台虽是 Android，宿主上并没有这个视图。
bool get _nativePreviewAvailable => !kIsWeb && Platform.isAndroid;

class HomeWidgetPreview extends StatefulWidget {
  const HomeWidgetPreview({
    super.key,
    required this.kind,
    required this.nativeConfig,
    required this.size,
    required this.dark,
    this.extraPalettes = const <String, Object?>{},
  });

  final HomeWidgetKind kind;

  /// 原生口径的实例配置（`homeWidgetNativeConfig`）。
  final Map<String, Object?> nativeConfig;

  final HomeWidgetCellSize size;
  final bool dark;

  /// 快照里还没有的配色（草稿刚选的自选颜色）。
  final Map<String, Object?> extraPalettes;

  @override
  State<HomeWidgetPreview> createState() => _HomeWidgetPreviewState();
}

class _HomeWidgetPreviewState extends State<HomeWidgetPreview> {
  int? _viewId;

  Map<String, Object?> get _params {
    final size = widget.size.previewSize;
    return <String, Object?>{
      'kind': widget.kind.id,
      'config': jsonEncode(widget.nativeConfig),
      'palettes': jsonEncode(widget.extraPalettes),
      'width': size.width,
      'height': size.height,
      'dark': widget.dark,
    };
  }

  /// 上一次交给原生的参数（编码后比较：配置是嵌套 Map，按引用比较总是不等）。
  String? _sent;

  @override
  void didUpdateWidget(HomeWidgetPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final viewId = _viewId;
    if (viewId == null) return;
    final params = _params;
    final encoded = jsonEncode(params);
    if (encoded == _sent) return;
    _sent = encoded;
    _channel
        .invokeMethod<void>('update', <String, Object?>{
          ...params,
          'viewId': viewId,
        })
        .catchError((Object error) {
          debugPrint('home widget preview: update failed: $error');
        });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size.previewSize;
    return SizedBox.fromSize(
      size: size,
      child: _nativePreviewAvailable
          ? AndroidView(
              viewType: _viewType,
              creationParams: _params,
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: (int id) {
                _viewId = id;
                _sent = jsonEncode(_params);
              },
            )
          : _PreviewPlaceholder(kind: widget.kind),
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({required this.kind});

  final HomeWidgetKind kind;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FaIcon(
              homeWidgetKindIcon(kind),
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 6),
            Text(
              homeWidgetKindName(context.l10n, kind),
              style: Theme.of(context).textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
