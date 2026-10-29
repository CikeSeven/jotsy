// 扫码页（“扫码连接”，DESIGN.md §5.27“扫码页”）：装配相机、识别与结果。
//
// 只在 `AppPlatform.supportsQrScan`（Android，mobile_scanner 自带 ML Kit）时
// 可达，入口在同步页英雄卡；结果经 Navigator 返回给打开者
// （`scanLanSyncQr`），由它调用 `connectQr` 或打开手动输入地址。
//
// - 识别：每帧交给 [LanSyncScanDetector]；认出 Jotsy 码即 selectionClick 并
//   关闭页面返回原文，别的码在底部轻提示一次（3 秒后消失，非动画计时）；
// - 相机：权限被拒或相机不可用时，mobile_scanner 把错误放进控制器状态，
//   这里据此换成说明（权限被拒带“去设置”：经 `DayPhotoLibrary.openSettings`
//   打开本应用的系统设置页，那是仓库里现成的入口，不为此加依赖）；
// - 外观：整页套用由应用种子色推出的暗色主题（画在相机画面上，与应用当前
//   明暗无关），状态栏图标为浅色。
//
// 不接入页面背景（AppPageBackground）：相机画面铺满整页，背景图透不出来。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/seeded_theme_cache.dart';
import '../../../core/services/day_photo_library.dart';
import '../../../core/services/lan_sync/lan_sync_qr_payload.dart';
import '../../diaries/providers/diary_preview_style_provider.dart';
import '../controllers/lan_sync_scan_detector.dart';
import '../widgets/lan_sync_scan_view.dart';

/// 扫码页的结果：扫到的 Jotsy 码原文，或用户选了“手动输入地址”。
@immutable
class LanSyncScanResult {
  const LanSyncScanResult.payload(String this.payload);
  const LanSyncScanResult.manualAddress() : payload = null;

  /// 扫到的码；null 为“手动输入地址”。
  final String? payload;
}

/// 见文件头注释。
class LanSyncScanPage extends ConsumerStatefulWidget {
  const LanSyncScanPage({super.key, this.cameraBuilder});

  /// 测试用：代替相机画面，并拿到识别回调（不创建 mobile_scanner 控制器）。
  @visibleForTesting
  final Widget Function(
    BuildContext context,
    void Function(Iterable<String?> values) onDetect,
  )?
  cameraBuilder;

  static Route<LanSyncScanResult> route() =>
      MaterialPageRoute<LanSyncScanResult>(
        builder: (_) => const LanSyncScanPage(),
      );

  @override
  ConsumerState<LanSyncScanPage> createState() => _LanSyncScanPageState();
}

class _LanSyncScanPageState extends ConsumerState<LanSyncScanPage> {
  MobileScannerController? _scanner;
  late final LanSyncScanDetector _detector = LanSyncScanDetector(
    onJotsy: _onJotsy,
    onOther: _onOther,
  );
  String? _hint;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    if (widget.cameraBuilder == null) {
      _scanner = MobileScannerController(
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      );
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    unawaited(_scanner?.dispose());
    super.dispose();
  }

  void _onJotsy(String payload) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(LanSyncScanResult.payload(payload));
  }

  void _onOther(LanSyncQrError error) {
    final l10n = context.l10n;
    _hintTimer?.cancel();
    setState(() {
      _hint = switch (error) {
        LanSyncQrError.notLanSync => l10n.lanSyncScanNotJotsy,
        LanSyncQrError.unsupportedVersion => l10n.lanSyncScanNewerVersion,
        LanSyncQrError.malformed => l10n.lanSyncScanMalformed,
      };
    });
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  void _manualAddress() =>
      Navigator.of(context).pop(const LanSyncScanResult.manualAddress());

  Widget _buildView(
    BuildContext context, {
    required Widget camera,
    LanSyncScanFailure? failure,
    LanSyncTorch torch = LanSyncTorch.unavailable,
  }) {
    return LanSyncScanView(
      camera: camera,
      failure: failure,
      torch: torch,
      hint: _hint,
      onClose: () => Navigator.of(context).maybePop(),
      onToggleTorch: () => unawaited(_scanner?.toggleTorch()),
      onManualAddress: _manualAddress,
      onOpenSettings: () =>
          unawaited(ref.read(dayPhotoLibraryProvider).openSettings()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = SeededThemeCache.of(
      ref.watch(appThemeSeedColorProvider),
      Brightness.dark,
      reduceMotion: ExpressiveMotion.reduceMotion(context),
    );
    final scanner = _scanner;
    final cameraBuilder = widget.cameraBuilder;
    final Widget body;
    if (cameraBuilder != null) {
      body = Builder(
        builder: (BuildContext context) => _buildView(
          context,
          camera: cameraBuilder(context, _detector.handle),
        ),
      );
    } else {
      final camera = MobileScanner(
        controller: scanner,
        onDetect: (BarcodeCapture capture) => _detector.handle(
          capture.barcodes.map((Barcode barcode) => barcode.rawValue),
        ),
        // 错误画面由 LanSyncScanView 统一画；这里只给一块底色。
        errorBuilder: (BuildContext context, MobileScannerException _) =>
            const SizedBox.expand(),
      );
      body = ValueListenableBuilder<MobileScannerState>(
        valueListenable: scanner!,
        builder: (BuildContext context, MobileScannerState state, _) =>
            _buildView(
              context,
              camera: camera,
              failure: switch (state.error?.errorCode) {
                null => null,
                MobileScannerErrorCode.permissionDenied =>
                  LanSyncScanFailure.permissionDenied,
                _ => LanSyncScanFailure.unavailable,
              },
              torch: switch (state.torchState) {
                TorchState.on => LanSyncTorch.on,
                TorchState.unavailable => LanSyncTorch.unavailable,
                TorchState.off || TorchState.auto => LanSyncTorch.off,
              },
            ),
      );
    }
    return Theme(
      data: theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: theme.colorScheme.surfaceContainerLowest,
          body: body,
        ),
      ),
    );
  }
}
