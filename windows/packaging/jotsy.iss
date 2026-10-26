; Jotsy for Windows: Inno Setup 6 script for the x64 installer.
;
; Built by .github/workflows/release-apk.yml after `flutter build windows --release`:
;   ISCC.exe /DAppVersion=0.6.1+18 /DVersionInfo=0.6.1 ^
;     /DOutputBaseFilename=jotsy-v0.6.1-windows-x64-setup /O<out dir> windows\packaging\jotsy.iss
; Relative paths are resolved against this file's folder.
;
; - AppId identifies the app across versions: never change it, or updates
;   install side by side instead of replacing the old version.
; - Installs per machine by default; the privileges dialog lets users without
;   admin rights install for themselves ({autopf} then maps to their
;   %LOCALAPPDATA%\Programs).
; - Diaries live in the user's app data folder, not in {app}: updating or
;   uninstalling never removes them.
; - ChineseSimplified.isl is not an official Inno Setup translation, so it is
;   only used when the compiler happens to ship it; otherwise English only.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef VersionInfo
  #define VersionInfo "0.0.0"
#endif
#ifndef OutputBaseFilename
  #define OutputBaseFilename "jotsy-windows-x64-setup"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif

#if !FileExists(AddBackslash(SourcePath) + SourceDir + "\jotsy.exe") && !FileExists(SourceDir + "\jotsy.exe")
  #error "jotsy.exe not found; run flutter build windows --release first or pass /DSourceDir=..."
#endif

[Setup]
AppId={{CB55EA62-A38B-43DC-BB3B-E83A26046A36}
AppName=Jotsy
AppVersion={#AppVersion}
AppVerName=Jotsy {#AppVersion}
AppPublisher=CikeSeven
AppPublisherURL=https://github.com/CikeSeven/jotsy
AppSupportURL=https://github.com/CikeSeven/jotsy/issues
AppUpdatesURL=https://github.com/CikeSeven/jotsy/releases
VersionInfoVersion={#VersionInfo}
VersionInfoCompany=CikeSeven
VersionInfoProductName=Jotsy
VersionInfoDescription=Jotsy Setup
DefaultDirName={autopf}\Jotsy
DefaultGroupName=Jotsy
DisableProgramGroupPage=yes
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\..\build\windows\installer
OutputBaseFilename={#OutputBaseFilename}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\jotsy.exe
UninstallDisplayName=Jotsy
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Close a running Jotsy before replacing its files; do not restart it.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
#if FileExists(AddBackslash(CompilerPath) + "Languages\ChineseSimplified.isl")
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
#endif

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; The Flutter bundle (app.so, flutter_assets, icudtl.dat) is replaced as a
; whole, so assets dropped from a new version do not linger. No user data here.
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Jotsy"; Filename: "{app}\jotsy.exe"
Name: "{autodesktop}\Jotsy"; Filename: "{app}\jotsy.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\jotsy.exe"; Description: "{cm:LaunchProgram,Jotsy}"; Flags: nowait postinstall skipifsilent
