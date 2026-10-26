import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/services/app_platform.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/expressive_button_group.dart';
import '../../widgets/expressive_image_frame.dart';
import '../../widgets/long_image/long_image_policy.dart';
import '../controllers/support_developer_controller.dart';
import '../models/support_channel.dart';

/// 打开“支持开发者”面板（设置 → 关于）。
///
/// 面板自上而下：标题与说明 → 微信 / 支付宝切换 → 收款码 → 付款步骤说明 →
/// 主次两个按钮 → 结果说明行。只负责挑选与展示，打开应用、保存收款码由
/// [SupportDeveloperController] 执行；结果写在按钮下方（面板遮罩会盖住 SnackBar）。
/// [createController] 仅供测试注入，面板销毁时一并释放。
Future<void> showSupportDeveloperSheet(
  BuildContext context, {
  @visibleForTesting SupportDeveloperController Function()? createController,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 收款码加说明在矮屏或大字号下超过默认 9/16 屏高，按内容撑高、放不下时面板内滚动。
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 640),
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) =>
        SupportDeveloperSheet(createController: createController),
  );
}

class SupportDeveloperSheet extends StatefulWidget {
  const SupportDeveloperSheet({super.key, this.createController});

  final SupportDeveloperController Function()? createController;

  @override
  State<SupportDeveloperSheet> createState() => _SupportDeveloperSheetState();
}

class _SupportDeveloperSheetState extends State<SupportDeveloperSheet> {
  late final SupportDeveloperController _controller =
      widget.createController?.call() ?? SupportDeveloperController();
  SupportChannel _channel = SupportChannel.wechat;

  /// 当前渠道最近一次操作的说明；切换渠道或顺利交给其他应用时清空。
  SupportActionResult? _feedback;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(SupportChannel channel) {
    if (channel == _channel) {
      return;
    }
    setState(() {
      _channel = channel;
      _feedback = null;
    });
  }

  /// 执行一次操作并更新说明行。忙碌中被忽略（null）时不动说明；结果回来时
  /// 用户已切到另一个渠道的，丢弃这条结果，避免说明落到不相干的收款码下。
  Future<void> _perform(
    Future<SupportActionResult?> Function(AppLocalizations l10n) action,
  ) async {
    final channel = _channel;
    final result = await action(context.l10n);
    if (!mounted || result == null || channel != _channel) {
      return;
    }
    setState(() => _feedback = result.message == null ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.l,
        ),
        child: ListenableBuilder(
          listenable: _controller,
          builder: (BuildContext context, Widget? _) {
            final busy = _controller.isBusy;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.supportDeveloperTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.supportDeveloperIntro,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                ExpressiveButtonGroup<SupportChannel>(
                  minSegmentWidth: 96,
                  segments: <ButtonSegment<SupportChannel>>[
                    ButtonSegment<SupportChannel>(
                      value: SupportChannel.wechat,
                      icon: const FaIcon(FontAwesomeIcons.weixin, size: 16),
                      label: Text(l10n.supportDeveloperWeChat),
                    ),
                    ButtonSegment<SupportChannel>(
                      value: SupportChannel.alipay,
                      icon: const FaIcon(FontAwesomeIcons.alipay, size: 16),
                      label: Text(l10n.supportDeveloperAlipay),
                    ),
                  ],
                  selected: <SupportChannel>{_channel},
                  onSelectionChanged: (Set<SupportChannel> selection) =>
                      _select(selection.single),
                ),
                const SizedBox(height: AppSpacing.xl),
                // 两个渠道的说明长短不同：内容交叉淡入，高度随之平滑变化。
                AnimatedSize(
                  duration: ExpressiveMotion.durationNonZero(
                    context,
                    ExpressiveMotion.medium,
                  ),
                  curve: ExpressiveMotion.effects,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: ExpressiveMotion.duration(
                      context,
                      ExpressiveMotion.fast,
                    ),
                    switchInCurve: ExpressiveMotion.effects,
                    switchOutCurve: ExpressiveMotion.exit,
                    layoutBuilder: _topAlignedLayout,
                    child: _SupportChannelPane(
                      key: ValueKey<SupportChannel>(_channel),
                      channel: _channel,
                      onOpen: busy
                          ? null
                          : () => _perform(
                              _channel == SupportChannel.alipay
                                  ? _controller.openAlipay
                                  : _controller.openWeChat,
                            ),
                      onSave: busy
                          ? null
                          : () => _perform(
                              (l10n) => _controller.saveCode(_channel, l10n),
                            ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: ExpressiveMotion.durationNonZero(
                    context,
                    ExpressiveMotion.medium,
                  ),
                  curve: ExpressiveMotion.effects,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: ExpressiveMotion.duration(
                      context,
                      ExpressiveMotion.fast,
                    ),
                    layoutBuilder: _topAlignedLayout,
                    child: _feedback == null
                        ? const SizedBox(width: double.infinity)
                        : _SupportFeedbackLine(
                            key: ObjectKey(_feedback),
                            result: _feedback!,
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Widget _topAlignedLayout(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) {
    return Stack(
      alignment: Alignment.topCenter,
      children: <Widget>[...previousChildren, ?currentChild],
    );
  }
}

/// 某个渠道的收款码、付款步骤与按钮。支付宝能直接跳到付款页，主按钮为
/// “打开支付宝付款”；微信只能扫相册里的码，主按钮为“保存到相册”。
class _SupportChannelPane extends StatelessWidget {
  const _SupportChannelPane({
    super.key,
    required this.channel,
    required this.onOpen,
    required this.onSave,
  });

  final SupportChannel channel;
  final VoidCallback? onOpen;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isAlipay = channel == SupportChannel.alipay;
    final open = (
      icon: isAlipay ? FontAwesomeIcons.alipay : FontAwesomeIcons.weixin,
      label: isAlipay
          ? l10n.supportDeveloperOpenAlipay
          : l10n.supportDeveloperOpenWeChat,
      onPressed: onOpen,
    );
    final save = (
      icon: FontAwesomeIcons.download,
      // 桌面没有相册，同一按钮弹出“另存为…”对话框。
      label: AppPlatform.savesImagesToGallery
          ? l10n.supportDeveloperSaveCode
          : l10n.desktopSaveAs,
      onPressed: onSave,
    );
    final primary = isAlipay ? open : save;
    final secondary = isAlipay ? save : open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: _SupportCodeImage(
            channel: channel,
            semanticLabel: isAlipay
                ? l10n.supportDeveloperAlipayCodeLabel
                : l10n.supportDeveloperWeChatCodeLabel,
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        Text(
          isAlipay
              ? l10n.supportDeveloperAlipayHint
              : l10n.supportDeveloperWeChatHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        FilledButton.icon(
          onPressed: primary.onPressed,
          icon: FaIcon(primary.icon, size: 16),
          label: Text(primary.label),
        ),
        const SizedBox(height: AppSpacing.s),
        OutlinedButton.icon(
          onPressed: secondary.onPressed,
          icon: FaIcon(secondary.icon, size: 16),
          label: Text(secondary.label),
        ),
      ],
    );
  }
}

/// 收款码图片：最宽 240dp 的正方形，按显示像素解码。
///
/// 图片自带白底与静区（扫码需要浅色留白，暗色主题下也保持白底，属于码本身而
/// 非界面配色），四角在图片里已是透明圆角（约边长的 7.5%）；这里只沿同样的
/// 圆角描一圈卡片微边框，让白底码在亮色面板上也有边界。
class _SupportCodeImage extends StatelessWidget {
  const _SupportCodeImage({required this.channel, required this.semanticLabel});

  static const double _maxSide = 240;
  static const double _cornerFraction = 0.075;

  final SupportChannel channel;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final side = math.min(constraints.maxWidth, _maxSide);
        final decodeSide = (side * MediaQuery.devicePixelRatioOf(context))
            .ceil();
        return Container(
          width: side,
          height: side,
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(side * _cornerFraction),
            border: Border.fromBorderSide(
              ExpressiveSurfaces.cardBorderSide(colorScheme),
            ),
          ),
          child: Image(
            image: boundedImageProvider(
              AssetImage(channel.assetPath),
              width: decodeSide,
              height: decodeSide,
            ),
            width: side,
            height: side,
            fit: BoxFit.contain,
            semanticLabel: semanticLabel,
            frameBuilder: expressiveImageFrameBuilder,
          ),
        );
      },
    );
  }
}

/// 按钮下方的一行结果说明：成功为主色，失败为 error 色。
class _SupportFeedbackLine extends StatelessWidget {
  const _SupportFeedbackLine({super.key, required this.result});

  final SupportActionResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = result.isError
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.m),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FaIcon(
            result.isError
                ? FontAwesomeIcons.circleExclamation
                : FontAwesomeIcons.circleCheck,
            size: 14,
            color: color,
          ),
          const SizedBox(width: AppSpacing.s),
          Flexible(
            child: Text(
              result.message ?? '',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
