import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../controllers/diary_block_language_tracker.dart';
import '../../models/diary_code_block/diary_code_language.dart';
import '../../viewmodels/diary_code_block_look.dart';
import 'diary_editor_spans.dart';
import 'diary_editor_styles.dart';

/// 代码块直接包住原生可选文字节点：标题栏与行号不进入文档或文字偏移，
/// 也不参与输入法；布局跟随该节点，删除、嵌套与拖动不会留下绘制层残影。
class DiaryCodeBlockSurface extends StatelessWidget {
  const DiaryCodeBlockSurface({
    super.key,
    required this.node,
    required this.look,
    required this.tracker,
    required this.child,
  });
  final af.Node node;
  final DiaryCodeBlockLook look;
  final DiaryBlockLanguageTracker tracker;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = node.delta?.toPlainText() ?? '';
    final choice = DiaryCodeLanguageChoice.fromAttributeValue(
      node.attributes['language'],
    );
    final detected = diaryBlockHighlightLanguage(node, text, look, tracker);
    final l10n = context.l10n;
    final label = choice.isPlain
        ? l10n.codeBlockLanguagePlain
        : diaryCodeLanguageById(choice.languageId ?? detected ?? '')?.name ??
              l10n.codeBlockLabelGeneric;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: DiaryCodeBlockLook.blockGap,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: look.palette.background,
          borderRadius: BorderRadius.circular(look.style.radius),
          border: look.style.border
              ? Border.all(color: look.palette.border, width: 0.8)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (look.header)
              Container(
                height: DiaryCodeBlockLook.headerHeight,
                padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
                decoration: BoxDecoration(
                  color: look.palette.header,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(look.style.radius),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: look.palette.foreground,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.codeBlockCopy,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 32,
                      ),
                      padding: EdgeInsets.zero,
                      icon: FaIcon(
                        FontAwesomeIcons.copy,
                        size: 13,
                        color: look.palette.foreground,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          HomeHintVisibilityScope.showTrackedSnackBar(
                            context: context,
                            snackBar: SnackBar(
                              content: Text(l10n.codeBlockCopied),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gutter = look.lineNumbers ? 32.0 : 0.0;
                  return Stack(
                    children: [
                      if (look.lineNumbers)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _CodeLineNumbers(
                                text,
                                look.codeTextStyle,
                                look.palette.lineNumber,
                                (constraints.maxWidth - gutter).clamp(
                                  1,
                                  double.infinity,
                                ),
                                diaryEditorTextScaler(context),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.only(left: gutter),
                        child: child,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 每个逻辑行按可用宽度测出换行后的高度，行号仍对齐逻辑行；宽度、字号或
/// 系统字体缩放改变时重测，颜色改变不影响文档布局。
///
/// 行号与代码文字的基线必须一致：代码文字是一整段，按正文的行高规则
/// （[kDiaryTextHeightBehavior]）只有第一行上方不加行距，其余行行距上下
/// 均分。所以第一行按同一规则去掉上方行距，其余行保留完整行高，行号与所在
/// 行同规则排版；缩放沿用正文的线性倍数（[diaryEditorTextScaler]）。
class _CodeLineNumbers extends CustomPainter {
  _CodeLineNumbers(this.text, this.style, this.color, this.width, this.scaler);
  final String text;
  final TextStyle style;
  final Color color;
  final double width;
  final TextScaler scaler;

  /// 段内的行：上下都保留行距，均分方式与正文一致。
  static final TextHeightBehavior _innerLine = TextHeightBehavior(
    leadingDistribution: kDiaryTextHeightBehavior.leadingDistribution,
  );

  @override
  void paint(Canvas canvas, Size size) {
    var top = 0.0;
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final behavior = i == 0 ? kDiaryTextHeightBehavior : _innerLine;
      final measure = TextPainter(
        text: TextSpan(text: lines[i].isEmpty ? ' ' : lines[i], style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        textHeightBehavior: behavior,
      )..layout(maxWidth: width);
      final number = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: style.copyWith(color: color),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        textHeightBehavior: behavior,
      )..layout();
      number.paint(canvas, Offset(22 - number.width, top));
      top += measure.height;
      measure.dispose();
      number.dispose();
    }
  }

  @override
  bool shouldRepaint(_CodeLineNumbers old) =>
      text != old.text ||
      style != old.style ||
      color != old.color ||
      width != old.width ||
      scaler != old.scaler;
}
