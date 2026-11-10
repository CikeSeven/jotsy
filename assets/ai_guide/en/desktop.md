---
id: desktop
title: Desktop on Windows and Linux
summary: Install, data location, two-pane layout, shortcuts and right-click menus on computers, and what differs from the phone app
features: []
platforms: [windows, linux]
destinations: [tab_diaries, search, app_update]
keywords: [desktop, computer, PC, Windows, Linux, install, uninstall, portable, install.sh, data folder, where is my data, keyboard shortcuts, keyboard, mouse, right-click menu, context menu, two panes, wide window, navigation rail, drag and drop, save as, multi-select, Ctrl, reminders]
---
Jotsy has desktop versions for Windows and Linux. They use the same interface as the phone app, with layouts that adapt to the window width and added keyboard and mouse controls.

## Wide window layout
- In a wider window, the home bottom bar becomes a navigation rail on the left, with the New button at the top and the pages below it. Settings is in the More menu at the top right of the Diaries page.
- When the window is wide enough, the Diaries tab splits into two panes: the diary list on the left, and the entry you click opens for reading on the right. The card you're reading has a thin ring around it. In a narrower window, clicking a card opens the preview page as usual.
- In a very wide window the calendar splits into two columns (the month on the left, the selected day on the right); Settings, search, notebooks and other pages are centered instead of stretching across the window.

## Keyboard shortcuts
- Home: **Ctrl + N** new diary (a new to-do on the To-dos tab), **Ctrl + F** search diaries, **Ctrl + 1–5** switch to that tab.
- Two-pane reading: **↑ / ←** previous entry, **↓ / →** next entry, **Enter** edit, **Delete** delete (with confirmation and undo), **Esc** clear the selection.
- Preview page and image viewer: hover over the page to show paging buttons at the left and right edges; **← / →** or **PageUp / PageDown** to turn pages, **Esc** to go back. For long images the mouse wheel scrolls and **Ctrl + wheel** zooms.
- While reading, select text and press **Ctrl + C** to copy or **Ctrl + A** to select all.
- While editing: **Ctrl + K** insert or edit a link, **Ctrl + Shift + H** highlight, **Ctrl + .** superscript, **Ctrl + ,** subscript, **Ctrl + Shift + V** paste as plain text, **Esc** go back.

## Mouse
- **Right-click menu**: right-click a card in the diary list, search or archive to Edit, Pin / Unpin, Add to notebook or Move to notebook, Archive / Unarchive, or Delete. The keyboard's menu key or Shift + F10 opens it too. To-dos also use a right-click menu instead of swiping on computers.
- **Multi-select**: Ctrl + click cards to tick them one by one, Shift + click to select a range. In the home tag bar, Ctrl + click a tag to select several tags (the same as a long-press on phones).
- Right-click while editing text for copy, paste and similar commands. Drag images or files from your file manager into the text; when "Drop to insert" appears, release to insert them at the cursor.
- Horizontally scrolling strips can be dragged with the mouse, or scrolled with Shift + wheel.

## Differences from the phone app
- No swipe to archive (use the right-click menu); the editor toolbar is always shown; double-clicking text on the preview page selects a word instead of opening the editor.
- No taking photos or videos, so the image and video buttons open a file picker directly; no "that day's photos" when backfilling; location and weather can't be fetched automatically but can be typed in.
- To-do reminders only appear while Jotsy is open; reminders that come due while it's closed won't pop up.
- Saving images, videos and exported files opens the system "Save as…" dialog. Videos in an entry don't play inline; click **Open in system player**.
- No sharing straight to specific apps such as WeChat or QQ, and on Linux the share panel offers copying the text and saving the image instead. Cloud notes from phone makers and WPS can't be imported.
- Linux can't record audio yet (playback works), and its app lock only works with an app password. Computers have no fingerprint or face quick unlock, no "Lock when the screen locks" and no "Block screenshots"; there's an optional "Lock when idle" instead.
- When pairing for LAN sync, the computer only shows a QR code for the phone to scan. Storage management has no image or video compression.

## Installing, data and uninstalling
- Download from the website (jotsy.sisct.xyz) or the GitHub releases page. Windows 10 or later (x64) has an installer (setup.exe) and a portable version (.zip; unzip and run); Linux (x64, GTK 3) has a .tar.gz archive.
- The Windows installer installs to Program Files by default, or just for you if you choose; it can also add a desktop icon. The installed version adds firewall rules for LAN sync (private networks only); the portable version leaves the firewall alone.
- Linux: unpack the archive and run **./install.sh** in the jotsy folder. It installs to ~/.local (no root needed), and you then open Jotsy from the app menu. You can also skip installing and run jotsy in that folder directly.
- Your diaries aren't in the install folder but in the app data folder: ~/.local/share/com.jotsy.diary on Linux, %APPDATA%\CikeSeven\Jotsy on Windows (the same for the installed and portable versions). Updating, reinstalling and uninstalling never delete it.
- Uninstalling: on Windows, uninstall Jotsy under Apps in system settings, or just delete the portable folder; on Linux, run **./install.sh --uninstall** in the unpacked jotsy folder. Your diaries stay; to really remove them, back up first, then delete the data folder above by hand.

## Starting, closing and updating
- Launching Jotsy again brings the open window to the front and keeps what you were editing. Closing the window first saves changes to entries, drafts and the publish panel; if saving fails you're told and the window stays open.
- New versions are announced on computers too. **Download** fetches the new package in your browser (the installer on Windows, an archive on Linux); install it over the old one and your diaries are kept. See "Updates and support".
