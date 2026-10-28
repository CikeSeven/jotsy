import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/journal_import_models.dart';
import '../../../l10n/app_localizations.dart';

/// 来源应用的展示名称：外文应用名是专有名词不翻译；Apple 手记、印象笔记、
/// 榴莲日记与国内手机厂商的笔记按各自的中文名（英文界面用官方英文名）。
String journalImportSourceName(
  AppLocalizations l10n,
  JournalImportSource source,
) {
  return switch (source) {
    JournalImportSource.dayOne => 'Day One',
    JournalImportSource.journey => 'Journey',
    JournalImportSource.diarium => 'Diarium',
    JournalImportSource.daylio => 'Daylio',
    JournalImportSource.appleJournal => l10n.journalImportAppleJournal,
    JournalImportSource.diaro => 'Diaro',
    JournalImportSource.durianDiary => l10n.journalImportDurianDiary,
    JournalImportSource.evernote => l10n.journalImportEvernote,
    JournalImportSource.googleKeep => 'Google Keep',
    JournalImportSource.joplin => 'Joplin',
    JournalImportSource.memos => 'Memos',
    JournalImportSource.markdown => l10n.journalImportMarkdown,
    JournalImportSource.xiaomiNotes => l10n.journalImportXiaomiNotes,
    JournalImportSource.huaweiNotepad => l10n.journalImportHuaweiNotepad,
    JournalImportSource.oppoNotes => l10n.journalImportOppoNotes,
    JournalImportSource.vivoNotes => l10n.journalImportVivoNotes,
    JournalImportSource.honorNotes => l10n.journalImportHonorNotes,
    JournalImportSource.meizuNotes => l10n.journalImportMeizuNotes,
    JournalImportSource.wpsNotes => l10n.journalImportWpsNotes,
    JournalImportSource.smartisanNotes => l10n.journalImportSmartisanNotes,
  };
}

/// 列表项下方的导出说明；手机云笔记共用分组说明，返回 null。
String? journalImportSourceHint(
  AppLocalizations l10n,
  JournalImportSource source,
) {
  return switch (source) {
    JournalImportSource.dayOne => l10n.journalImportDayOneHint,
    JournalImportSource.journey => l10n.journalImportJourneyHint,
    JournalImportSource.diarium => l10n.journalImportDiariumHint,
    JournalImportSource.daylio => l10n.journalImportDaylioHint,
    JournalImportSource.appleJournal => l10n.journalImportAppleJournalHint,
    JournalImportSource.diaro => l10n.journalImportDiaroHint,
    JournalImportSource.durianDiary => l10n.journalImportDurianDiaryHint,
    JournalImportSource.evernote => l10n.journalImportEvernoteHint,
    JournalImportSource.googleKeep => l10n.journalImportGoogleKeepHint,
    JournalImportSource.joplin => l10n.journalImportJoplinHint,
    JournalImportSource.memos => l10n.journalImportMemosHint,
    JournalImportSource.markdown => l10n.journalImportMarkdownHint,
    _ => null,
  };
}

FaIconData journalImportSourceIcon(JournalImportSource source) {
  return switch (source) {
    JournalImportSource.dayOne => FontAwesomeIcons.bookOpen,
    JournalImportSource.journey => FontAwesomeIcons.route,
    JournalImportSource.diarium => FontAwesomeIcons.calendarDays,
    JournalImportSource.daylio => FontAwesomeIcons.faceSmile,
    JournalImportSource.appleJournal => FontAwesomeIcons.apple,
    JournalImportSource.diaro => FontAwesomeIcons.penNib,
    JournalImportSource.durianDiary => FontAwesomeIcons.bookBookmark,
    JournalImportSource.evernote => FontAwesomeIcons.evernote,
    JournalImportSource.googleKeep => FontAwesomeIcons.lightbulb,
    JournalImportSource.joplin => FontAwesomeIcons.fileLines,
    JournalImportSource.memos => FontAwesomeIcons.feather,
    JournalImportSource.markdown => FontAwesomeIcons.markdown,
    _ => FontAwesomeIcons.mobileScreenButton,
  };
}

/// 导入预览里“整篇跳过了几篇”的说明，按 [JournalSkipReason] 分行。
String journalSkipReasonText(
  AppLocalizations l10n,
  JournalSkipReason reason,
  int count,
) {
  return switch (reason) {
    JournalSkipReason.encrypted => l10n.backupImportSkippedEncrypted(count),
    JournalSkipReason.unsupported => l10n.backupImportSkippedUnsupported(count),
    JournalSkipReason.unreadable => l10n.backupImportSkippedUnreadable(count),
  };
}
