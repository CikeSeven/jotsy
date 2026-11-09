---
id: backup-restore
title: Backup and restore
summary: Export a full backup ZIP with an optional password, import it by merging or overwriting, and use diary files.
features: []
platforms: []
destinations: [data_management, cloud_backup]
keywords: [backup, restore, export data, import data, ZIP, backup password, encryption, merge, overwrite, diary file, new phone, migrate, uninstall]
---
Jotsy keeps your data only on this device. A full backup packs everything into one ZIP file. Keep it somewhere else and you can restore from it after switching phones, reinstalling or losing data.

## Where
Settings → Data Management, the "Backup & restore" group: "Export Data" and "Import Data". The same group has "Cloud backup", see "Cloud backup".

## Export a full backup
1. Tap "Export Data".
2. In "Set export password (optional)", enter a password, or leave it empty to skip encryption. Password-protected backups use AES-256 encryption.
3. Choose where to save it.

The backup contains all diaries (including archived ones, the recycle bin and time capsules), tags, notebooks, anniversaries, day moods, to-dos, diary templates, comments, drafts, AI chats, reflections and recaps, images, recordings, videos, attachments, covers and background images, plus app settings.

It does not contain the app passcode, cloud backup locations and sign-ins, AI providers and API keys, LAN sync pairings, imported font files, or preferences that belong to this device only, such as mood emojis and mood colors, app lock timing and "Block screenshots", toolbar size and "Always show toolbar", "Show that day's photos automatically", and the Storage page's sorting and compression levels. Set these up again on a new device.

The app lock switch itself is in the backup: if app lock was on when you backed up, it is on again after "Overwrite all data", but the app passcode isn't in the backup, so system verification is used until you set a passcode again.

## Import and restore
1. Tap "Import Data" and choose a backup ZIP or a diary file. Encrypted files ask for the import password.
2. Jotsy reads the file first and shows how many diaries and tags it contains and how many are already on this device.
3. In "How to import", choose one:
- **Merge (recommended)**: keeps everything on this device and only adds diaries it doesn't have (anniversaries, to-dos, templates, notebooks and so on are also only added when missing); existing ones stay as they are.
- **Overwrite existing diaries**: adds new content and replaces the diaries already on this device with the versions in the file; their local edits are lost. Existing anniversaries, to-dos and day moods, and notebooks' names, covers, chapters and other settings, are replaced with the file's versions too; diary templates are only added, never replaced. Only shown when there are duplicates.
- **Overwrite all data**: erases all diaries, tags, media and settings on this device and replaces them with the backup. Only full backups offer this.
4. Overwriting shows a warning listing what will be deleted. Tick "I understand overwritten data can't be recovered" and wait for the countdown before you can confirm.

If an import fails, the data on this device stays as it was. Merging never changes your settings; only "Overwrite all data" brings in the settings from the backup.

## Diary files
- On a diary's preview page, tap More → Export and pick the "Jotsy diary file" format; you can set a password. It is also available after multi-selecting diaries, and in Settings → Data Management → Export diaries.
- It keeps the diaries, their media and comments intact, which suits moving a few diaries to another Jotsy. Import it with "Import Data" as well; it can only merge or overwrite existing diaries and never erases this device.
- Diary files don't include settings, templates or AI records.

## Notes
- Uninstalling the app or clearing its data deletes all diaries, so export backups regularly or use cloud backup.
- A backup password can't be recovered; if you forget it, that backup can't be opened. It is unrelated to the app lock passcode.
- To keep two devices in step all the time, use "LAN sync".
- Only you can back up and restore; the AI assistant can open the Data Management page for you.
