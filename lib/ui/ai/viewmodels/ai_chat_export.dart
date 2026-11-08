// 导出对话：把选中的消息写成一份 Markdown 或纯文本（纯函数）。
//
// 结构：标题、“导出于 … · 共 N 条消息”，然后按时间逐条——
// - 问题：“你 · 时间”与原文；
// - 回答：“人设名 · 时间”，可选的思考过程（各步与最后一段）、可选的过程
//   与操作（调用工具前说的话、每个调用的具体标题与结果，撤销过、取消、
//   失败的照实写），正文（Markdown 原样保留 `[Dn]`；纯文本由块文档转成
//   纯文字、去掉引用编号），参考的日记，出错 / 已停止的说明。
//
// 只用落库的内容，不联网、不读日记全文。

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/ai_chat_controller.dart';
import '../controllers/ai_save_as_diary_flow.dart';
import '../models/ai_agent_steps.dart';
import '../tools/ai_tool_registry.dart';
import 'ai_labels.dart';
import 'ai_task_prompts.dart';
import 'ai_tool_facts.dart';

enum AiChatExportFormat {
  markdown('md', 'text/markdown'),
  text('txt', 'text/plain');

  const AiChatExportFormat(this.extension, this.mimeType);

  final String extension;
  final String mimeType;
}

/// 导出选项（本次运行内记住，见 `aiChatExportOptionsProvider`）。
@immutable
class AiChatExportOptions {
  const AiChatExportOptions({
    this.format = AiChatExportFormat.markdown,
    this.reasoning = false,
    this.steps = true,
  });

  final AiChatExportFormat format;

  /// 带上思考过程。
  final bool reasoning;

  /// 带上过程与操作（工具调用）。
  final bool steps;

  AiChatExportOptions copyWith({
    AiChatExportFormat? format,
    bool? reasoning,
    bool? steps,
  }) => AiChatExportOptions(
    format: format ?? this.format,
    reasoning: reasoning ?? this.reasoning,
    steps: steps ?? this.steps,
  );
}

/// 导出文件名：对话标题（去掉文件名里不能用的字符，最长 40 字）+ 日期。
String aiChatExportFileName(
  String title,
  DateTime now,
  AiChatExportFormat format,
) {
  final clean = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final stem = clean.length > 40 ? clean.substring(0, 40).trim() : clean;
  final date = DateFormat('yyyy-MM-dd').format(now);
  return '${stem.isEmpty ? 'chat' : stem} $date.${format.extension}';
}

/// 写出导出内容。[messages] 为选中的消息（按时间先后），[assistantName]
/// 为回答的署名（人设名）。
String aiChatExportText({
  required AppLocalizations l10n,
  required String title,
  required List<AiMessageRow> messages,
  required String assistantName,
  required AiChatExportOptions options,
  required DateTime now,
}) {
  final markdown = options.format == AiChatExportFormat.markdown;
  final locale = l10n.localeName;
  final time = DateFormat.yMMMd(locale).add_Hm();
  final out = StringBuffer();

  void heading(String text, {int level = 3}) {
    out.writeln(markdown ? '${'#' * level} $text' : '【$text】');
    out.writeln();
  }

  void paragraph(String text) {
    if (text.trim().isEmpty) return;
    out.writeln(text.trim());
    out.writeln();
  }

  void label(String text) => out.writeln(markdown ? '**$text**' : '（$text）');

  if (markdown) {
    out.writeln('# $title');
  } else {
    out.writeln(title);
  }
  out.writeln();
  paragraph(l10n.aiChatExportAt(time.format(now), messages.length));
  if (markdown) {
    out.writeln('---');
    out.writeln();
  }

  for (final message in messages) {
    final user = message.role == AiMessageRole.user;
    heading(
      '${user ? l10n.aiChatExportYou : assistantName} · '
      '${time.format(message.createdAt)}',
    );
    if (user) {
      paragraph(message.content);
      continue;
    }
    final steps = AiAgentStepRecord.decodeList(message.steps);
    if (options.reasoning) {
      final thoughts = <String>[
        for (final step in steps)
          if (step.reasoning.trim().isNotEmpty) step.reasoning.trim(),
        if (message.reasoning.trim().isNotEmpty) message.reasoning.trim(),
      ];
      if (thoughts.isNotEmpty) {
        label(l10n.aiChatExportReasoning);
        for (final thought in thoughts) {
          for (final line in thought.split('\n')) {
            out.writeln(markdown ? '> $line' : line);
          }
          out.writeln(markdown ? '>' : '');
        }
        out.writeln();
      }
    }
    if (options.steps) {
      final lines = _stepLines(l10n, steps);
      if (lines.isNotEmpty) {
        label(l10n.aiChatExportSteps);
        for (final line in lines) {
          out.writeln(markdown ? '- $line' : '· $line');
        }
        out.writeln();
      }
    }
    if (markdown) {
      paragraph(message.content);
    } else {
      paragraph(_plainText(message.content));
    }
    final citations = AiCitation.decodeList(message.citations);
    if (citations.isNotEmpty) {
      label(l10n.aiChatExportReferences);
      final day = DateFormat.yMMMd(locale);
      for (final citation in citations) {
        final name = citation.title.trim().isEmpty
            ? day.format(citation.date)
            : '${citation.title.trim()} · ${day.format(citation.date)}';
        out.writeln(markdown ? '- [${citation.ref}] $name' : '· $name');
      }
      out.writeln();
    }
    if (aiMessageError(message) case final error?) {
      final reason = l10n.aiChatExportError(aiErrorMessage(l10n, error));
      paragraph(markdown ? '*$reason*' : reason);
    } else if (message.status == AiMessageStatus.stopped) {
      paragraph(
        markdown ? '*${l10n.aiChatStoppedLabel}*' : l10n.aiChatStoppedLabel,
      );
    }
  }
  return '${out.toString().trimRight()}\n';
}

/// 过程与操作：调用工具前说的话，和每个调用“具体标题 —— 结果：涉及的对象”。
List<String> _stepLines(AppLocalizations l10n, List<AiAgentStepRecord> steps) {
  final lines = <String>[];
  for (final step in steps) {
    if (step.text.trim().isNotEmpty) {
      lines.add(step.text.trim().replaceAll('\n', ' '));
    }
    for (final call in step.calls) {
      final tool = aiToolByName(call.tool);
      final title =
          tool?.labelWith(l10n, call.args, call.subjects) ?? call.tool;
      final note = call.undone
          ? l10n.aiAgentStepUndone
          : switch (call.status) {
              AiToolCallStatus.failed => call.summary ?? l10n.aiAgentStepFailed,
              AiToolCallStatus.rejected ||
              AiToolCallStatus.cancelled => l10n.aiAgentStepCancelled,
              AiToolCallStatus.executing ||
              AiToolCallStatus.awaitingConfirmation =>
                l10n.aiAgentStepInterrupted,
              AiToolCallStatus.succeeded => call.summary,
            };
      final names = [
        for (final subject in call.subjects)
          if (!subject.input) aiSubjectName(l10n, subject),
      ];
      final buffer = StringBuffer(title);
      if (note != null && note.isNotEmpty) buffer.write(' —— $note');
      if (names.isNotEmpty) {
        buffer.write(
          l10n.aiChatExportSubjects(aiJoinNames(l10n, names, show: 5)),
        );
      }
      lines.add(buffer.toString());
    }
  }
  return lines;
}

/// Markdown 正文转成纯文字（与另存为日记同一转换，去掉 `[Dn]`）。
String _plainText(String markdown) {
  if (markdown.trim().isEmpty) return '';
  final document = aiMarkdownDiaryDocument(markdown);
  final text = diaryBlocksPlainText(document);
  return text.trim().isEmpty ? markdown : text;
}
