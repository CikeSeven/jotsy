import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_field.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_language.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';
import '../../../widgets/desktop_horizontal_scroll.dart';

/// 语言选项的高度与行列间距。
const double kDiaryCodeLanguageChipHeight = 32;
const double kDiaryCodeLanguageChipGap = 8;

/// 两行选项区的总高度。
const double kDiaryCodeLanguageChipsHeight =
    2 * kDiaryCodeLanguageChipHeight + kDiaryCodeLanguageChipGap;

/// 一个可选的语言选项：写回的选择与显示的名称。
typedef DiaryCodeLanguageOption = ({
  DiaryCodeLanguageChoice choice,
  String label,
});

/// 代码块面板里的语言选项：两行共用一个横向滚动区。
///
/// - 输入：按顺序排好的选项、当前选中的选择（选区跨了取值不同的代码块时为
///   null，不选中任何一项）、点按回调；
/// - 排布：按列从上到下填（第 0 项在上、第 1 项在下、第 2 项在上……），两行
///   长度大致相同，不会一行很长、一行很短；
/// - 打开时把选中项滚到可见范围中间（`medium` + effects，减少动画时直接
///   跳到），之后不再跟随，避免用户刚滑开就被拉回去；
/// - 选项只是按钮，不请求焦点、不开路由，正文焦点与键盘保持不动。
class DiaryCodeLanguageChips extends StatefulWidget {
  const DiaryCodeLanguageChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.horizontalInset = 0,
  });

  final List<DiaryCodeLanguageOption> options;
  final DiaryCodeLanguageChoice? selected;
  final ValueChanged<DiaryCodeLanguageChoice> onSelected;

  /// 滚动内容两端的留白，与面板标题、操作按钮对齐。
  final double horizontalInset;

  @override
  State<DiaryCodeLanguageChips> createState() => _DiaryCodeLanguageChipsState();
}

class _DiaryCodeLanguageChipsState extends State<DiaryCodeLanguageChips> {
  final ScrollController _scroll = ScrollController();

  /// 每个选项一把固定的 key：选中项变化时各选项保持原元素，颜色才能补间；
  /// 打开时也靠它找到选中项的位置。
  final Map<DiaryCodeLanguageChoice, GlobalKey> _chipKeys =
      <DiaryCodeLanguageChoice, GlobalKey>{};

  GlobalKey _keyFor(DiaryCodeLanguageChoice choice) =>
      _chipKeys.putIfAbsent(choice, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    // 首帧布局完成后才知道选中项的位置。
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 只滚这一个横向滚动区：`Scrollable.ensureVisible` 会连带外层（面板被
  /// 夹住时的纵向滚动）一起滚。
  void _revealSelected() {
    if (!mounted || !_scroll.hasClients) return;
    final selected = widget.selected;
    if (selected == null) return;
    final box = _chipKeys[selected]?.currentContext?.findRenderObject();
    if (box == null) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final position = _scroll.position;
    final target = viewport
        .getOffsetToReveal(box, 0.5, axis: Axis.horizontal)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target == position.pixels) return;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (duration == Duration.zero) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: duration,
        curve: ExpressiveMotion.effects,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = <Widget>[];
    final bottom = <Widget>[];
    for (var index = 0; index < widget.options.length; index++) {
      final option = widget.options[index];
      final selected = option.choice == widget.selected;
      final row = index.isEven ? top : bottom;
      if (row.isNotEmpty) {
        row.add(const SizedBox(width: kDiaryCodeLanguageChipGap));
      }
      row.add(
        _DiaryCodeLanguageChip(
          key: _keyFor(option.choice),
          label: option.label,
          selected: selected,
          onTap: () => widget.onSelected(option.choice),
        ),
      );
    }
    return SizedBox(
      height: kDiaryCodeLanguageChipsHeight,
      child: DesktopHorizontalScroll(
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: widget.horizontalInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(children: top),
              const SizedBox(height: kDiaryCodeLanguageChipGap),
              Row(children: bottom),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单个语言选项：未选沿用应用 chip 主题（surfaceContainerHigh、16dp 圆角）；
/// 选中用工具栏“已选中工具”的 primaryContainer，而不是 chip 主题的
/// secondaryContainer——下方三个 tonal 操作按钮就是 secondaryContainer，
/// 同色时选中项看起来像按钮、也不比未选的醒目。选中态经
/// [ExpressiveStateBlend] 补间。不加勾号：勾号会改变选项宽度，两行的排布
/// 随选中项跳动。
class _DiaryCodeLanguageChip extends StatelessWidget {
  const _DiaryCodeLanguageChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    // 在玻璃工具栏里未选中的底色换成半透明填充（“控件”为玻璃时再加玻璃
    // 描边）；选中色不变，描边随选中淡出。经典时两者都是原值。
    final glassField = AppGlassField.of(context);
    final restingSide = glassField?.border ?? BorderSide.none;
    return Semantics(
      button: true,
      selected: selected,
      child: ExpressiveStateBlend(
        active: selected,
        builder: (BuildContext context, double t, Widget? child) {
          final foreground = Color.lerp(
            colors.onSurface,
            colors.onPrimaryContainer,
            t,
          )!;
          return Material(
            color: Color.lerp(
              glassField?.fill ?? colors.surfaceContainerHigh,
              colors.primaryContainer,
              t,
            ),
            shape: shape.copyWith(
              side: BorderSide.lerp(restingSide, BorderSide.none, t),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: shape,
              child: Container(
                height: kDiaryCodeLanguageChipHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
