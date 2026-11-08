---
id: app-lock
title: App lock and passcode
summary: App lock and when it locks, system verification or an app passcode, fingerprint or face, and blocking screenshots.
features: []
platforms: []
destinations: [app_lock, settings_notebooks]
keywords: [app lock, password, passcode, PIN, pattern, fingerprint, face, biometrics, block screenshots, screenshot, lock, unlock, screen lock, forgot passcode, privacy]
---
App lock asks you to verify your identity when Jotsy opens. You can verify with your phone's system verification or with an app passcode that belongs to Jotsy alone.

## Where
Settings → App lock & passcode (in the "Data & security" group).

## Turn on app lock
1. Turn on the "App Lock" switch. While it is on, opening the app always needs verification.
2. Below the switch you can choose when it locks:
- **Lock after leaving**: Immediately, after 1 / 5 / 15 / 30 minutes, after 1 hour, or "Never (only when the app opens)" (the default). Switching to another app, going to the home screen or minimizing the window counts as leaving; picking photos, taking pictures, choosing files or sharing from inside the app doesn't.
- **Lock when the screen locks** (Android only): after the phone locks or the screen turns off, coming back needs verification.
- **Lock when idle** (computers only): locks when the window stays open but the mouse, touchpad and keyboard go unused for a while.
- **Ask right away**: shows fingerprint, face or system verification as soon as the lock screen appears; when off, tap to verify.

## Verification method
Under "Verification method", choose one:
- **System verification**: fingerprint, face or your phone's screen lock. Not available if the device has no screen lock.
- **App passcode**: a 6-digit PIN, a 4-digit PIN or a pattern (at least 4 dots in one stroke), separate from your screen lock. Digits are entered on Jotsy's own keypad and checked as soon as they are complete; on a computer you can type them on the keyboard.

With an app passcode you also get "Change app passcode" and "Fingerprint / face quick unlock", which lets you unlock with your fingerprint or face instead of the passcode; turning off app lock or changing the passcode still needs the passcode. Quick unlock isn't available on Windows or Linux.

## Block screenshots
"Block screenshots" in the "Privacy" group (Android only) makes screenshots, screen recordings and the recent apps view show nothing. It works independently of the app lock switch.

## Notes
- App lock, locked notebooks and LAN sync pairing confirmation all use the same verification method.
- Turning off app lock, switching the method and changing the passcode all need verification first; while app lock is on, relaxing when it locks or turning off screenshot blocking does too.
- From the 5th wrong passcode on you have to wait: 30 seconds, 1 minute, 5 minutes, then 15 minutes each time.
- **The app passcode is stored only on this device, isn't included in backups or sync, and can't be recovered if you forget it.** The only way back in is to clear the app's data or reinstall it, then restore your diaries from a backup. Export a backup before setting a passcode.
- Linux has no system verification, so set an app passcode first to use app lock or lock notebooks.
- Only you can set up app lock and passcodes; the AI assistant can open this page for you.
