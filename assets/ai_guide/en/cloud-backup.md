---
id: cloud-backup
title: Cloud backup
summary: Back up to WebDAV, object storage or cloud drives incrementally, keep copies, back up automatically and restore.
features: []
platforms: []
destinations: [cloud_backup, data_management]
keywords: [cloud backup, cloud, WebDAV, Nutstore, NAS, Alist, S3, object storage, Google Drive, OneDrive, Dropbox, Baidu Netdisk, Alipan, incremental backup, automatic backup, keep, restore from cloud]
---
Cloud backup saves your data to your own cloud drive, WebDAV server or object storage, so you can restore straight from there after switching devices or reinstalling. Jotsy has no server of its own; backups go only to the location you enter or authorize.

## Where
Settings → Data Management → Cloud backup. You can add several backup locations, each with its own settings.

## Add a backup location
Tap "Add backup location" and pick one from three groups:
- **Cloud drives (sign in)**: Google Drive, OneDrive, Dropbox, Baidu Netdisk, Alipan (whatever the sheet actually lists). You authorize on the drive's official page, and the app can only access its own backup folder. Depending on the drive, a system account picker appears, a code is shown for you to enter on the authorization page, or you authorize in the browser and paste a code back.
- **WebDAV**: Nutstore, 123pan, Synology and QNAP NAS, Nextcloud, Alist / OpenList and more, or "Other WebDAV". Enter the server URL, username, password or token and remote directory; each service shows its own tips. Drives such as Quark or 115 can be mounted through Alist / OpenList and used as WebDAV.
- **Object storage (S3-compatible)**: Alibaba Cloud OSS, Tencent Cloud COS, Cloudflare R2, MinIO and more, or "Other S3-compatible". Enter the endpoint, region, bucket and access keys.

Then tap "Test connection" and "Save". Addresses, passwords and sign-ins stay on this device and are never written into backups.

## Back up
The location page has three buttons at the top:
- **Back up**: an incremental backup that uploads only what is new or changed. Photos and other media are de-duplicated by content, so each is stored on the drive only once; nothing is uploaded if nothing changed. The first backup asks you to set a password (leave it empty for no encryption); it is remembered on this device and used for every later backup.
- **Upload full ZIP**: uploads a complete backup file, optionally encrypted, which you can also download and restore from Data Management → Import Data.
- **Refresh**: reloads the "Remote backups" list below.

The "Incremental backup" group also has:
- **Keep**: 10 / 30 / 100 / All, 30 by default. Older incremental backups are deleted automatically, along with photos and media used only by them. Full ZIPs are never deleted automatically.
- **Automatic backup**: available after one successful manual backup; the frequency is Daily or Weekly. Jotsy checks when you open or leave the app and every hour while you use it, and backs up quietly once it is due. If more than 50 MB is new it waits and shows "Back up manually". Results appear in the location list and on the location page.
- **Reset password**: makes this device forget the current incremental backup password; automatic backup pauses until you choose again at the next backup.

## Restore from the cloud
"Remote backups" lists full ZIPs and incremental backups together by time. Tap "Restore" on one; it is checked first, then you choose to merge with or overwrite the data on this device, just like a local import (see "Backup and restore"). Restoring an incremental backup reuses photos already on this device and downloads only what is missing. Restoring an encrypted incremental backup on another device asks for its password.

## Notes
- Remember your incremental backup password; you need it to restore on a new device.
- Drives such as Nutstore limit traffic and request counts, and incremental backups use far less. Rate limits and dropped connections are retried automatically, and the next backup picks up where it stopped.
- "Remove this location" only clears the connection details and sign-in saved on this device; backup files on the drive are kept. Deleting a remote backup can't be undone.
- Only you can work with cloud backups; the AI assistant can open the Cloud backup page for you.
