---
id: faq
title: FAQ
summary: Where data lives, uploads, new phones, forgotten passcodes, missing features, private entries, desktop gaps and what Jotsy can't do.
features: []
platforms: []
destinations: [data_management, settings_features, app_lock, settings_notebooks, about]
keywords: [FAQ, questions, data security, upload, online, privacy, web images, new phone, migrate, forgot passcode, cannot find feature, feature missing, private entries, desktop, computer, uninstall, data folder, iOS, not supported, share to Jotsy, widget, shortcut, daily reminder, writing reminder, notification]
---
## Where is my data? Is it uploaded?
Diaries, media and settings are stored only on this device. Jotsy has no accounts and no server of its own. It goes online only for: getting location and weather automatically (Android), backing up to a cloud location you set up, checking for updates (automatic checks can be turned off in Settings → About → Check for updates), signing in to the official site when importing phone cloud notes, sending requests to the AI service you configured when you use the AI assistant, and LAN sync (encrypted, within your local network). Also, web images in an entry (image links brought in by pasting web content or Markdown, or by some imports) load from their web address when shown.

On a phone, uninstalling the app or clearing its data deletes all diaries. On a computer, data lives in the app data folder (~/.local/share/com.jotsy.diary on Linux, %APPDATA%\CikeSeven\Jotsy on Windows), not the install folder, so updating or uninstalling never deletes it; see "Desktop on Windows and Linux". Back up regularly; see "Backup and restore".

## How do I move to a new phone?
On the old device, go to Settings → Data Management → Export Data, move the ZIP to the new device and restore it with "Import Data"; if the new device has no diaries yet, choose "Overwrite all data" to bring your settings along too. You can also go through "Cloud backup", or use "LAN sync" on the same Wi-Fi. The app passcode, cloud sign-ins and AI keys aren't in backups, so set them up again on the new device.

## I forgot my app passcode. What now?
The app passcode is kept only on this device, isn't included in backups or sync, and can't be recovered. On a phone, the only way back in is to clear the app's data or uninstall and reinstall it (which deletes everything on this device); on a computer, reinstalling doesn't reset it, so you have to delete the app data folder mentioned above (which also deletes everything on this device). Then restore your diaries from a backup. So export a backup before setting a passcode; see "App lock and passcode". A forgotten backup password or incremental cloud backup password likewise means that backup can't be opened.

## I can't find a feature.
It is most likely turned off in Settings → Features. To-dos, anniversaries, comments and the AI assistant are off by default, and the calendar, Explore, notebooks, diary templates, time capsules and swipe to archive can be turned off too. Anniversaries only appear once the calendar is on. Turning something off only hides it; your data stays and comes back when you turn it on again; see "Turning features on or off". After turning on the AI assistant you also need to add a provider before its entry points appear; see "AI assistant". Some features exist only on phones; see the next question.

## Why is a feature missing on my computer?
These are phone (Android) only: sharing straight to WeChat, QQ and other apps, importing phone and WPS cloud notes, "Photos from this day" when writing about a past day, getting location and weather automatically, taking photos and videos, scanning QR codes to pair, compressing photos and videos, installing updates in the app, locking when the screen locks, and blocking screenshots. Computers have alternatives: share through the system share sheet or save to a file, type the location and weather by hand, use "Lock when idle" for app lock, and pair for LAN sync by showing a QR code for the phone to scan. On Linux, recording isn't available (playback works) and there is no system verification, so app lock needs an app passcode. On Windows and Linux, videos in entries open in the system player. On computers, diary cards can't be swiped to archive; use the right-click menu instead.

## What can't Jotsy do?
- **Sharing into Jotsy from other apps**: not supported; Jotsy isn't in the system share sheet. Copy the content and paste it into an entry; for images, use "Insert image" in the editor, or copy and paste them directly.
- **Home screen widgets and app icon shortcuts** (long-pressing the app icon): there are none.
- **A daily reminder to write**: there isn't one. Turn on To-dos (Settings → Features → To-dos) and create a to-do that repeats "Daily" with a reminder; see "To-dos". On computers, reminders only appear while Jotsy is open.
- **Time capsule notifications**: nothing is sent when a capsule unlocks, and anniversaries don't send reminders either. To be reminded, create a to-do with a reminder on that day; the "Time capsules" card on Explore shows how many days are left.

## What are private entries?
Entries in a notebook set to "Hide from All entries" or "Lock". They show up only inside that notebook, never in All entries, search, the calendar or Explore, and by default the AI assistant never sends them (turning on "Allow AI on private entries" under the AI's "Privacy" lets the writing assistant, smart fill, reflections and "Describe with AI" use them). A locked notebook asks you to verify your identity each time you open it, the same way as app lock. Both options are on the notebook's edit page (open the notebook and tap ⋮ in its header → Edit); see "Notebooks".

## Is there an iOS version?
Jotsy is currently released for Android, Windows and Linux; there is no iOS version yet.
