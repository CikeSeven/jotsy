import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

/// 将当前系统时间插入到编辑器当前选区。
///
/// 如果用户已选中文字，则替换选区；如果编辑器暂时没有有效选区，则插入到文档末尾。
void insertDiaryToolbarCurrentTime(
  BuildContext context,
  quill.QuillController controller, {
  String? formatPattern,
}) {
  final now = DateTime.now();
  final insertedText = formatDiaryToolbarCurrentTime(
    context.l10n,
    now,
    customPattern: formatPattern,
  );
  final documentLength = controller.document.length;
  final selection = controller.selection;
  final start = selection.isValid
      ? _clampQuillOffset(selection.start, documentLength)
      : _clampQuillOffset(documentLength - 1, documentLength);
  final end = selection.isValid
      ? _clampQuillOffset(selection.end, documentLength)
      : start;
  final replaceLength = end - start;
  controller.replaceText(
    start,
    replaceLength < 0 ? 0 : replaceLength,
    insertedText,
    TextSelection.collapsed(offset: start + insertedText.length),
  );
}

const String kDefaultDiaryToolbarCurrentTimeFormat = 'M月d日 HH:mm';

String formatDiaryToolbarCurrentTime(
  AppLocalizations l10n,
  DateTime value, {
  String? customPattern,
}) {
  final local = value.toLocal();
  final normalizedPattern = customPattern?.trim();
  if (normalizedPattern != null && normalizedPattern.isNotEmpty) {
    return DateFormat(normalizedPattern, l10n.localeName).format(local);
  }
  return DateFormat(kDefaultDiaryToolbarCurrentTimeFormat, 'zh').format(local);
}

bool isValidDiaryToolbarCurrentTimeFormat(
  AppLocalizations l10n,
  String formatPattern,
) {
  final normalized = formatPattern.trim();
  if (normalized.isEmpty) {
    return true;
  }
  try {
    formatDiaryToolbarCurrentTime(
      l10n,
      DateTime(2026, 3, 11, 21, 30),
      customPattern: normalized,
    );
    return true;
  } catch (_) {
    return false;
  }
}

int _clampQuillOffset(int offset, int documentLength) {
  final maxOffset = documentLength <= 0 ? 0 : documentLength - 1;
  if (offset < 0) {
    return maxOffset;
  }
  if (offset > maxOffset) {
    return maxOffset;
  }
  return offset;
}
