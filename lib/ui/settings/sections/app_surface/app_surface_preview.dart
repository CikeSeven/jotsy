import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/seeded_theme_cache.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/models/app_surface_settings.dart';
import '../../../app_surface/widgets/app_card_surface.dart';
import '../../../app_surface/widgets/app_glass_scope.dart';
import '../../../app_surface/widgets/app_glass_surface.dart';
import '../../../app_surface/widgets/app_page_background.dart';
import '../../../diaries/providers/diary_preview_style_provider.dart';
import '../../controllers/app_surface_editor_controller.dart';
import 'app_surface_labels.dart';
import 'app_surface_preview_parts.dart';

/// “背景与材质”的实时预览：一块缩小的“手机页面”样稿。
///
/// 输入：编辑控制器（草稿设置、预览区域与明暗）；输出：圆角画框里的页面——
/// 顶栏（二级页顶栏材质）、两张内容卡片（卡片材质）、一条编辑器工具栏样条
/// （工具栏材质）与一个圆形新建按钮（小控件材质），垫在预览区域的草稿背景
/// 上。无副作用、不可交互。
///
/// 复用正式渲染管线而不是另画一套：背景经 [AppPageBackground.preview]（同一
/// 套解码、缓存、遮罩与交叉淡入），组件经 [AppGlassScope] 读草稿材质后由
/// 真实的 [AppCardSurface] / [AppGlassSurface] 绘制。
///
/// 为什么按真实手机尺寸排版再整体缩小（[FittedBox]）：背景图按显示尺寸
/// 解码，模糊半径按逻辑像素给出——直接在一百多 dp 宽的小框里排版，同样的
/// 模糊会显得重好几倍，顶栏、卡片的比例也不对。手机竖屏时模拟的就是本机
/// 屏幕（解码键与真实页面相同，还能直接命中缓存）；宽窗口与横屏模拟一台
/// 常见尺寸的手机。
class AppSurfacePreview extends ConsumerWidget {
  const AppSurfacePreview({
    super.key,
    required this.controller,
    this.bottomPadding = 0,
  });

  final AppSurfaceEditorController controller;

  /// 预览底部被选项面板圆角压住的高度；画框在它之上结束。
  final double bottomPadding;

  /// 宽窗口、横屏时模拟的手机尺寸（逻辑像素）。
  static const Size fallbackPhoneSize = Size(390, 844);

  /// 模拟的手机尺寸：本机竖屏且是手机宽度时用本机屏幕，否则用
  /// [fallbackPhoneSize]。
  static Size phoneSizeOf(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    if (screen.width > 0 &&
        screen.width < 600 &&
        screen.height > screen.width) {
      return screen;
    }
    return fallbackPhoneSize;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = Theme.of(context);
    final brightness = controller.previewBrightness ?? appTheme.brightness;
    final previewTheme = brightness == appTheme.brightness
        ? appTheme
        : SeededThemeCache.of(
            ref.watch(appThemeSeedColorProvider),
            brightness,
            reduceMotion: MediaQuery.disableAnimationsOf(context),
          );
    final phone = phoneSizeOf(context);
    final settings = controller.style;
    final radius = BorderRadius.circular(AppRadii.card);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomPadding),
      child: Center(
        child: Semantics(
          container: true,
          label: context.l10n.appSurfacePreviewLabel,
          child: ExcludeSemantics(
            child: AspectRatio(
              aspectRatio: phone.width / phone.height,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: previewTheme.colorScheme.outlineVariant,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox.fromSize(
                      size: phone,
                      child: Theme(
                        data: previewTheme,
                        // 画框里是一台“手机”：尺寸换成模拟的屏幕，去掉
                        // 外面页面的系统内边距与键盘。
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            size: phone,
                            padding: EdgeInsets.zero,
                            viewPadding: EdgeInsets.zero,
                            viewInsets: EdgeInsets.zero,
                          ),
                          child: AppGlassScope(
                            style: settings.glass,
                            child: IgnorePointer(
                              child: _PreviewPage(
                                area: controller.previewArea,
                                background: controller.previewBackground,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 样稿页面：草稿背景之上的顶栏、卡片、工具栏与新建按钮。
class _PreviewPage extends StatelessWidget {
  const _PreviewPage({required this.area, required this.background});

  final AppBackgroundArea area;
  final AppBackground background;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppPageBackground.preview(
      area: area,
      background: background,
      child: Builder(
        builder: (BuildContext context) => Material(
          color: AppPageBackdrop.pageColorOf(context),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppSurfacePreviewTopBar(
                    title: appSurfaceAreaLabel(l10n, area),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        AppSurfacePreviewCard(
                          title: l10n.appSurfacePreviewCardTitle1,
                          body: l10n.appSurfacePreviewCardBody1,
                        ),
                        const SizedBox(height: 12),
                        AppSurfacePreviewCard(
                          title: l10n.appSurfacePreviewCardTitle2,
                          body: l10n.appSurfacePreviewCardBody2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Positioned(
                right: 20,
                bottom: 96,
                child: AppSurfacePreviewCreateButton(),
              ),
              const Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: AppSurfacePreviewToolbar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
