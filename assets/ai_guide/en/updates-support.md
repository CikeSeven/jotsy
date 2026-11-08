---
id: updates-support
title: Updates and support
summary: Check for and install updates, read the changelog, report problems, the QQ group, tipping, and privacy notes
features: []
platforms: []
destinations: [about, app_update, changelog]
keywords: [update, upgrade, new version, check for updates, automatic updates, download route, skip this version, changelog, release notes, feedback, bug, issue, QQ group, community, tip, support the developer, donate, privacy, data security, open source, about, version]
---
The About page brings together app updates, feedback and support, and privacy and open-source information.

## Where
- Settings → About (the last row of the Settings home page). The app version is at the top, followed by three cards: Check for updates and Changelog; Submit issue, QQ feedback group and Support the developer; Open-source repository, Privacy & data security and Third-party open-source licenses.
- When a new version is out, the About row on the Settings home page and the Check for updates row show a "New" badge.

## Checking for and installing updates
- Tap **Check for updates** to open the App updates page. It shows the current version and the result of the check, and lists "What's new" when there's a new version.
- Android: tap **Download and install**. The download shows its progress and can be cancelled; tap **Resume download** later to continue where it stopped. When it finishes, tap **Install** to hand it to the system installer. The first time you may need to allow Jotsy to install apps; tap **Open settings** to do so. The file's checksum and the app signature are verified before installing; if they don't match, the file is deleted and you're told why.
- Computers (Windows / Linux): Jotsy only checks; it doesn't install inside the app. **Download** fetches the new package in your browser: on Windows an installer you run to update in place, on Linux a .tar.gz archive you extract and then run install.sh from. Your diaries are kept.
- **Skip this version**: you won't be reminded about that version at startup, but you can still check by hand.

## Update settings
- Update settings, below "What's new" on the App updates page:
  - **Check automatically** (on by default): checks when you open or return to the app, at most every 2 hours, and only reads public release info. When a new version is found a prompt offers **Update now** (**Download** on computers), **Skip this version** or **Later**.
  - **Download route**: Automatic (recommended in mainland China), several built-in mirrors, GitHub direct, or a custom mirror you enter. Switch routes if a download is slow or fails.

## Changelog
- Settings → About → **Changelog**: versions are listed newest first, and the version installed on this device is marked "Current". Each card shows the version's highlights; tap **Show all** for the full notes.
- The changelog is bundled with the app and needs no internet. It exists only in Chinese and English; Japanese and Russian show the English version.

## Feedback and community
- **Submit issue**: opens the project's GitHub issues page in your browser, where you can report bugs or suggest ideas.
- **QQ feedback group**: group number 678136434; tap to copy it to the clipboard.

## Support the developer
- Tap **Support the developer** to open the tip panel and switch between **WeChat** and **Alipay**. With Alipay you can tap **Pay in Alipay** to pay directly. With WeChat, save the code first (**Save to photos** on phones, **Save as…** on computers), then open Scan in WeChat and pick the image from your album.
- Jotsy is free, open source and ad-free. Tips are entirely voluntary and don't unlock anything.

## Privacy & data security
- Jotsy has no accounts and no server of its own. Your diaries, tags and media files are stored only on this device and aren't uploaded to the cloud by default.
- Jotsy only goes online in these cases: fetching location and weather automatically (Android only; you can type them in instead), cloud backup and restore (to the server or drive you set up), checking for and downloading updates (no diary data is sent), importing cloud notes (you sign in on the vendor's website), and using the AI assistant (off by default; when on, it sends only what a feature needs, directly to the AI service you configured, and your key stays on this device). LAN sync only transfers data between devices on the same local network.
- Because your data lives only on this device, uninstalling the app or clearing its data deletes your diaries too, so back up regularly.
- **Open-source repository** opens the project's GitHub page; **Third-party open-source licenses** lists the licenses of the open-source components Jotsy uses.

## Notes
- The AI assistant can open About, App updates or Changelog for you, but it can't download or install updates or leave a tip for you.
