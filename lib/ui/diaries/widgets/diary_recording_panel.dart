import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/app_effects.dart';
import 'package:node_diary/app/theme/app_radii.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_surface.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:node_diary/ui/diaries/widgets/diary_live_voiceprint.dart';
import 'package:node_diary/ui/diaries/widgets/diary_recording_controls.dart';
import 'package:node_diary/ui/diaries/widgets/diary_recording_readout.dart';
import 'package:node_diary/ui/diaries/widgets/diary_recording_rename_dialog.dart';

/// 悬浮在编辑器工具栏下方的录音面板。
///
/// 输入：控制器的阶段、计时、失败原因与振幅采样；输出：开始/暂停/继续/结束/
/// 关闭/重命名回调。面板不持有录音状态，只负责排版与动效：
/// - 版面由“稳定阶段”决定（见 [settleRecordingPhase]），暂停/继续途中不塌缩；
/// - 面板高度在三个阶段间恒定，不会因为出现声纹或按钮而跳动；
/// - REC 圆点与暂停时的计时闪烁共用一个呼吸循环，减少动画时不启动。
class DiaryRecordingPanel extends StatefulWidget {
  const DiaryRecordingPanel({
    super.key,
    required this.phase,
    required this.elapsed,
    required this.failure,
    this.waveform = const <double>[],
    this.recordingName,
    this.onNameChanged,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onClose,
  });

  final DiaryRecordingPhase phase;
  final Duration elapsed;
  final DiaryRecordingFailure? failure;

  /// 本次录音已采集的振幅（旧→新），驱动实时声纹。
  final List<double> waveform;
  final String? recordingName;
  final ValueChanged<String>? onNameChanged;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final VoidCallback onClose;

  @override
  State<DiaryRecordingPanel> createState() => _DiaryRecordingPanelState();
}

class _DiaryRecordingPanelState extends State<DiaryRecordingPanel>
    with SingleTickerProviderStateMixin {
  /// 呼吸周期：渐隐 + 渐显各一个 `long`，整体约 1 秒一个来回。
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.long,
  );
  late final Animation<double> _breath = Tween<double>(begin: 1, end: 0.3)
      .animate(
        CurvedAnimation(
          parent: _pulse,
          curve: ExpressiveMotion.effects,
          reverseCurve: ExpressiveMotion.exit,
        ),
      );
  late DiaryRecordingPhase _settled = settleRecordingPhase(
    widget.phase,
    DiaryRecordingPhase.idle,
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncPulse();
  }

  @override
  void didUpdateWidget(DiaryRecordingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _settled = settleRecordingPhase(widget.phase, _settled);
    _syncPulse();
  }

  /// 只有会话期间才需要呼吸；待机或减少动画时停掉并回到完全不透明，避免控制器
  /// 空转，也避免停在半透明的中间值。
  void _syncPulse() {
    final shouldRun = !_reduceMotion && _settled != DiaryRecordingPhase.idle;
    if (shouldRun) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating || _pulse.value != 0) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _rename(BuildContext context) async {
    final l10n = context.l10n;
    final chosen = await showDiaryRecordingRenameDialog(
      context,
      initialName: widget.recordingName ?? l10n.recordingDefaultTitle,
    );
    // 弹窗打开期间面板可能已随页面关闭；此时回调的控制器可能已释放。
    if (chosen == null || !mounted) return;
    widget.onNameChanged?.call(
      chosen.isEmpty ? l10n.recordingDefaultTitle : chosen,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final recording = _settled == DiaryRecordingPhase.recording;

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RecordingHeader(
            name: widget.recordingName ?? l10n.recordingDefaultTitle,
            onRename: () => _rename(context),
            onClose: widget.onClose,
          ),
          const SizedBox(height: 4),
          DiaryRecordingStatus(
            settled: _settled,
            failure: widget.failure,
            breath: _breath,
          ),
          DiaryRecordingTimer(
            text: formatRecordingDuration(widget.elapsed),
            settled: _settled,
            breath: _breath,
          ),
          const SizedBox(height: 8),
          LiveVoiceprintVisualizer(
            samples: widget.waveform,
            active: recording,
            height: 48,
          ),
          const SizedBox(height: 20),
          DiaryRecordingControls(
            settled: _settled,
            phase: widget.phase,
            onStart: widget.onStart,
            onPause: widget.onPause,
            onResume: widget.onResume,
            onFinish: widget.onFinish,
          ),
        ],
      ),
    );
    // 录音面板挂在悬浮工具栏下方、随工具栏一起入场淡出，材质跟随工具栏：
    // 一张玻璃一张实色既不协调，实色块在 GlassReveal 下也不会淡入（会硬切）。
    // 玻璃叠在正文之上，总是模糊；投影只画在外侧（软阴影会从半透明底里透出）。
    if (AppGlass.of(context).isGlass(AppGlassComponent.toolbar)) {
      return AppGlassSurface(
        component: AppGlassComponent.toolbar,
        borderRadius: BorderRadius.circular(AppRadii.card),
        blur: AppGlassBlur.always,
        shadow: true,
        child: body,
      );
    }
    // 浮动面板按设计规范使用单层软阴影；阴影画在裁剪之外的 DecoratedBox 上。
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppEffects.softShadow(colors),
      ),
      child: Material(
        color: ExpressiveSurfaces.cardColor(colors),
        shape: ExpressiveSurfaces.cardShape(colors),
        clipBehavior: Clip.antiAlias,
        child: body,
      ),
    );
  }
}

/// 顶部：可点击重命名的名称胶囊 + 关闭按钮。
class _RecordingHeader extends StatelessWidget {
  const _RecordingHeader({
    required this.name,
    required this.onRename,
    required this.onClose,
  });

  final String name;
  final VoidCallback onRename;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            // 微胶囊：主色低透明度底、无边框，与标签胶囊同一套视觉语言。
            child: Material(
              color: colors.primary.withValues(alpha: 0.12),
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onRename,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.microphoneLines,
                        size: 13,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FaIcon(
                        FontAwesomeIcons.penToSquare,
                        size: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n.recordingClose,
          visualDensity: VisualDensity.compact,
          color: colors.onSurfaceVariant,
          onPressed: onClose,
          icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
        ),
      ],
    );
  }
}
