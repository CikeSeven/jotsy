---
id: lan-sync
title: LAN sync
summary: Pair a phone and a computer on the same Wi-Fi and sync diaries both ways; what syncs, QR pairing and conflicts.
features: []
platforms: [android, windows, linux, macos]
destinations: [lan_sync]
keywords: [LAN sync, sync, multiple devices, pair, scan, QR code, Wi-Fi, phone and computer, auto sync, conflict copy, cannot find device, firewall]
---
LAN sync lets two copies of Jotsy on the same Wi-Fi (for example a phone and a computer) pair and then merge their data both ways. Data goes straight between the devices, encrypted all the way and never through a server.

## Where
Settings → LAN sync (in the "Data & security" group). It is available on Android and the desktop apps (Windows, Linux); iOS isn't supported.

## Pair
1. Connect both devices to the same Wi-Fi and open the LAN sync page on both.
2. Under "Nearby devices", find the other device and tap "Pair".
3. Both devices show the same 6-digit number. If they match, tap "Matches, pair"; it cancels automatically if not confirmed within 60 seconds.
4. Or use a QR code: tap "Show QR code" on one device and "Scan QR code" on an Android phone. Scanning is Android-only; computers only show the code. Each code works once and is replaced automatically when it runs out.
5. If the other device doesn't show up, tap "Enter address" and type the address and port shown on its sync page.

If this device uses app lock or has locked notebooks, you verify your identity before confirming the pairing, the same way as for app lock.

## Sync
- After pairing, tap "Sync now"; later, tap "Sync" on the device's row under "My devices".
- "Auto sync" is on by default: while Jotsy is open it syncs with paired devices that are online; it doesn't sync in the background. You can turn off auto sync for one device in "Device details".
- What syncs: diaries (including the recycle bin), tags, notebooks (with members, order and nesting), comments, diary templates, anniversaries, day moods, to-dos and lists, plus images, recordings, videos and attachments.
- Appearance, editor and other settings sync only when both devices turn on "Sync settings" (off by default). Tag order and turning on features such as comments or notebooks always sync.
- Not synced: drafts, imported font files, mood options, cloud backup settings, app lock and the app passcode, AI providers and keys, AI usage, and AI chats, reflections and recaps.

## Conflicts and deletions
- If both devices changed the text of the same diary, both versions are kept: the newer one stays in the diary and the other is saved as a conflict copy.
- On the first sync, or after an overwrite restore, differences prompt "Which version wins?": Keep both (recommended), Use this device's version, or Use the other device's version. None of them deletes any diary.
- If a sync would delete diaries for good, you're asked first, with "Keep, and restore on the other device" selected by default.

## Notes
- After pairing, both devices merge all their diaries, including private notebooks and the recycle bin. Export a full backup before the first pairing.
- If devices can't find each other, tap "Can't find a device?". Guest networks, routers with AP isolation, VPNs and proxies block discovery; on Windows allow Jotsy on private networks the first time; on Linux let UDP 24561 and the sync port (TCP, 24562 by default) through the firewall.
- Nothing syncs while an editing page is open. Both devices need compatible versions of Jotsy, otherwise you're asked to update the older one.
- "Unpair" at the bottom of "Device details" removes the pairing without deleting any diary on either device.
- Only you can pair and sync; the AI assistant can open the LAN sync page for you.
