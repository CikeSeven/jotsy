---
id: import-other-apps
title: Import from other apps
summary: Which journaling and note apps you can move from, what export file each needs, and where to import it.
features: []
platforms: []
destinations: [data_management]
keywords: [import, move, migrate, other apps, Day One, Journey, Diarium, Daylio, Apple Journal, Diaro, Durian Diary, Evernote, Google Keep, Joplin, Memos, Markdown, Obsidian, Notion, Xiaomi Notes, Huawei Notepad, OPPO Notes, vivo Notes, WPS Notes, cloud notes]
---
Export your data in the old app first, then choose the exported file in Jotsy to bring your diaries and notes over. Everything is checked before importing, and you can merge or overwrite as usual.

## Where
Settings → Data Management → Import from other journal apps, then pick the source in the "Import from which app?" sheet.

## Sources and the files they need
Journaling apps:
- **Day One**: export as JSON (.zip).
- **Journey**: export to ZIP (.zip).
- **Diarium**: JSON export (.json) or backup file (.diary).
- **Daylio**: backup file (.daylio) or CSV export (.csv).
- **Apple Journal**: on iPhone, Settings › Apps › Journal › Export All Journal Entries (.zip).
- **Diaro**: backup file (.zip); encrypted backups can't be imported.
- **Durian Diary**: the archive exported from Import & Export (.lld), or a backup folder compressed to .zip.

Note apps:
- **Evernote**: export notebooks as ENEX (.enex), or several in a .zip.
- **Google Keep**: export Keep with Google Takeout (.zip).
- **Joplin**: export as JEX (.jex).
- **Memos**: Settings › Export & Import, v0.31 or later (.zip).
- **Markdown / plain text**: .md / .txt files from Obsidian, Bear, Notion and more, or a .zip of them, one entry per file. Markdown exported from Jotsy itself can be brought back the same way.

Phone & WPS cloud notes (phones only): Xiaomi Notes, Huawei Notepad, OPPO Notes, vivo Notes, HONOR Notes, Meizu Notes, WPS Notes, Smartisan Notes. No file is needed: pick one, sign in on the official web page inside the app, and Jotsy reads your notes, folders and image attachments straight from the cloud. It only reads notes; the sign-in is used for this import only and cleared afterwards, never saved or used for anything else.

## Steps
1. Pick the source, then the export file (or sign in, for cloud notes).
2. The preview shows how many entries there are, how many are already on this device, and what will be skipped, such as encrypted or locked notes, handwritten notes, mind maps and other special formats, or media missing from the export.
3. Choose how to import: "Merge (recommended)" only adds what this device doesn't have; when some already exist you can also choose "Overwrite existing diaries". Imports from other apps can't overwrite all data.
4. If the source has notebooks or folders, choose under "Original notebooks / folders" whether they become Notebooks, Tags or Both. A notebook with the same name joins your existing one.

## Notes
- Importing the same export again doesn't create duplicates: merging skips entries already on this device.
- With notebooks turned off, the original notebooks and folders become tags with the same names.
- The desktop apps don't have the cloud notes group, because it needs an in-app web sign-in.
- Only you can run an import; the AI assistant can open the Data Management page for you.
- To move data from another Jotsy, use a full backup or a diary file; see "Backup and restore".
