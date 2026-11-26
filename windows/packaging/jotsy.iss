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
; - Diaries live in the user's chosen data folder (default %APPDATA%\CikeSeven\Jotsy),
;   not in {app}: updating or uninstalling never removes them.
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

[CustomMessages]
english.DataDirPageCaption=Select Data Storage Location
english.DataDirPageDescription=Where should Jotsy store your diaries, media files, and local database?
english.DataDirPageSubCaption=Choose an empty folder (for example D:\JotsyData) or keep the default app data folder. Updates and uninstalling will never remove your data.
english.DataDirResetButton=Reset to Default
english.DataDirExistingNote=Existing diary data was detected at the current location (%1). Selecting a different folder will migrate your data automatically the next time Jotsy starts.
english.DataDirInvalidEmpty=Please select a valid data storage folder.
english.DataDirInvalidRelative=Please enter a full folder path (for example D:\JotsyData).
english.DataDirInvalidDriveRoot=Please do not select a drive root directly. Choose or create a subfolder (for example D:\JotsyData).
english.DataDirInvalidInsideApp=The data folder cannot be inside the program installation folder, because updates replace files there.
english.DataDirInvalidNotEmpty=Please choose an empty folder or an existing Jotsy data folder so your diaries stay separate from other files.
english.DataDirConfirmSwitchExisting=The selected folder already contains Jotsy diary data. Switch to use the data in that folder instead of migrating your current data? (Your current data folder will not be deleted.)
english.DataDirReadyHeader=Data storage location:
english.DataDirReadyMigrateSuffix=(existing data will migrate on next launch)
#if FileExists(AddBackslash(CompilerPath) + "Languages\ChineseSimplified.isl")
chinesesimplified.DataDirPageCaption=选择数据存储位置
chinesesimplified.DataDirPageDescription=设置 Jotsy 存放日记、媒体文件与本地数据库的位置
chinesesimplified.DataDirPageSubCaption=请选择空文件夹（如 D:\JotsyData）或保留默认位置。更新或卸载应用不会删除这里的数据。
chinesesimplified.DataDirResetButton=恢复默认位置
chinesesimplified.DataDirExistingNote=检测到当前位置（%1）已有日记数据。如果更换为其他空文件夹，Jotsy 将在下次启动时自动迁移数据。
chinesesimplified.DataDirInvalidEmpty=请选择有效的数据存储文件夹。
chinesesimplified.DataDirInvalidRelative=请输入完整的目录路径（例如 D:\JotsyData）。
chinesesimplified.DataDirInvalidDriveRoot=请勿直接选择磁盘根目录，请新建或选择子文件夹（例如 D:\JotsyData）。
chinesesimplified.DataDirInvalidInsideApp=数据目录不能位于程序安装目录内，以免更新或卸载时受到影响。
chinesesimplified.DataDirInvalidNotEmpty=请选择空文件夹，或已包含 Jotsy 数据的文件夹。
chinesesimplified.DataDirConfirmSwitchExisting=所选文件夹中已有 Jotsy 日记数据。是否直接切换使用该文件夹的数据（不迁移、也不删除当前位置的数据）？
chinesesimplified.DataDirReadyHeader=数据存储位置：
chinesesimplified.DataDirReadyMigrateSuffix=（将在下次启动时自动迁移现有数据）
#endif

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; The Flutter bundle (app.so, flutter_assets, icudtl.dat) is replaced as a
; whole, so assets dropped from a new version do not linger. No user data here.
Type: filesandordirs; Name: "{app}\data"

[UninstallDelete]
Type: files; Name: "{app}\jotsy_data_location.json"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Jotsy"; Filename: "{app}\jotsy.exe"
Name: "{autodesktop}\Jotsy"; Filename: "{app}\jotsy.exe"; Tasks: desktopicon

[Run]
; LAN sync needs inbound UDP discovery and inbound TCP sessions. Restrict the
; exception to private networks and this executable; TCP uses any local port
; because the service falls back to a random port when 24562 is occupied.
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Jotsy LAN Sync UDP"""; Flags: runhidden
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Jotsy LAN Sync TCP"""; Flags: runhidden
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""Jotsy LAN Sync UDP"" dir=in action=allow program=""{app}\jotsy.exe"" enable=yes profile=private protocol=UDP localport=24561"; Flags: runhidden
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""Jotsy LAN Sync TCP"" dir=in action=allow program=""{app}\jotsy.exe"" enable=yes profile=private protocol=TCP localport=any"; Flags: runhidden
Filename: "{app}\jotsy.exe"; Description: "{cm:LaunchProgram,Jotsy}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Jotsy LAN Sync UDP"""; Flags: runhidden
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Jotsy LAN Sync TCP"""; Flags: runhidden

[Code]
var
  DataDirPage: TInputDirWizardPage;
  ResetDataDirButton: TNewButton;
  ExistingDataLabel: TNewStaticText;
  DefaultDataDir: String;
  OriginalDataDir: String;
  HasExistingDatabase: Boolean;

function NormalizeWindowsPath(const Raw: String): String;
begin
  Result := Trim(Raw);
  StringChangeEx(Result, '/', '\', True);
  Result := RemoveBackslashUnlessRoot(Result);
end;

function EscapeJsonString(const Value: String): String;
var
  I: Integer;
  Ch: Char;
begin
  Result := '';
  for I := 1 to Length(Value) do
  begin
    Ch := Value[I];
    if Ch = '\' then
      Result := Result + '\\'
    else if Ch = '"' then
      Result := Result + '\"'
    else if Ch = #10 then
      Result := Result + '\n'
    else if Ch = #13 then
      Result := Result + '\r'
    else if Ch = #9 then
      Result := Result + '\t'
    else
      Result := Result + Ch;
  end;
end;

function ReadJsonStringField(const JsonText, FieldName: String): String;
var
  Pattern: String;
  Idx: Integer;
  Ch: Char;
begin
  Result := '';
  Pattern := '"' + FieldName + '"';
  Idx := Pos(Pattern, JsonText);
  if Idx = 0 then Exit;
  Idx := Idx + Length(Pattern);
  while (Idx <= Length(JsonText)) and
        ((JsonText[Idx] = ' ') or (JsonText[Idx] = #9) or (JsonText[Idx] = ':') or
         (JsonText[Idx] = #13) or (JsonText[Idx] = #10)) do
    Idx := Idx + 1;
  if (Idx > Length(JsonText)) or (JsonText[Idx] <> '"') then Exit;
  Idx := Idx + 1;
  while Idx <= Length(JsonText) do
  begin
    Ch := JsonText[Idx];
    if Ch = '"' then Exit;
    if Ch = '\' then
    begin
      Idx := Idx + 1;
      if Idx > Length(JsonText) then Exit;
      Ch := JsonText[Idx];
      if Ch = 'n' then Result := Result + #10
      else if Ch = 'r' then Result := Result + #13
      else if Ch = 't' then Result := Result + #9
      else Result := Result + Ch;
    end
    else
      Result := Result + Ch;
    Idx := Idx + 1;
  end;
end;

function ReadConfiguredPathFromFile(const FilePath, FieldName: String): String;
var
  Lines: TArrayOfString;
  Joined: String;
  I: Integer;
begin
  Result := '';
  if not FileExists(FilePath) then Exit;
  if not LoadStringsFromFile(FilePath, Lines) then Exit;
  Joined := '';
  for I := 0 to GetArrayLength(Lines) - 1 do
    Joined := Joined + Lines[I];
  Result := NormalizeWindowsPath(ReadJsonStringField(Joined, FieldName));
end;

function IsAbsoluteWindowsPath(const Path: String): Boolean;
begin
  Result := False;
  if Length(Path) >= 3 then
  begin
    if (((Path[1] >= 'A') and (Path[1] <= 'Z')) or
        ((Path[1] >= 'a') and (Path[1] <= 'z'))) and
       (Path[2] = ':') and (Path[3] = '\') then
      Result := True
    else if (Path[1] = '\') and (Path[2] = '\') then
      Result := True;
  end;
end;

function IsDriveRootPath(const Path: String): Boolean;
var
  Clean: String;
begin
  Clean := NormalizeWindowsPath(Path);
  Result := (Length(Clean) = 3) and (Clean[2] = ':') and (Clean[3] = '\');
end;

function IsInsideAppDirectory(const CandidatePath: String): Boolean;
var
  AppDir, CleanCandidate: String;
begin
  AppDir := Lowercase(NormalizeWindowsPath(ExpandConstant('{app}')));
  CleanCandidate := Lowercase(NormalizeWindowsPath(CandidatePath));
  Result := (CleanCandidate = AppDir) or
    (Pos(AddBackslash(AppDir), AddBackslash(CleanCandidate)) = 1);
end;

function DirHasBlockingEntries(const DirPath: String; const IsDefaultDir: Boolean): Boolean;
var
  FindRec: TFindRec;
  LowerName: String;
begin
  Result := False;
  if not DirExists(DirPath) then Exit;
  if FindFirst(AddBackslash(DirPath) + '*', FindRec) then
  begin
    try
      repeat
        if (FindRec.Name = '.') or (FindRec.Name = '..') then
          Continue;
        LowerName := Lowercase(FindRec.Name);
        if (LowerName = 'desktop.ini') or (LowerName = 'thumbs.db') or
           (LowerName = '.ds_store') then
          Continue;
        if IsDefaultDir and
           ((LowerName = 'shared_preferences.json') or
            (LowerName = 'data_location.json') or
            (LowerName = '.jotsy_data_root.json')) then
          Continue;
        Result := True;
        Break;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
end;

procedure OnResetDataDirClick(Sender: TObject);
begin
  DataDirPage.Values[0] := DefaultDataDir;
end;

procedure InitializeWizard;
var
  UserConfigPath, ParamDir, SavedDir: String;
begin
  DefaultDataDir := NormalizeWindowsPath(ExpandConstant('{userappdata}\CikeSeven\Jotsy'));
  UserConfigPath := AddBackslash(DefaultDataDir) + 'data_location.json';
  SavedDir := ReadConfiguredPathFromFile(UserConfigPath, 'path');
  if SavedDir = '' then
    OriginalDataDir := DefaultDataDir
  else
    OriginalDataDir := SavedDir;

  HasExistingDatabase := FileExists(AddBackslash(OriginalDataDir) + 'node_diary.sqlite');

  DataDirPage := CreateInputDirPage(
    wpSelectDir,
    CustomMessage('DataDirPageCaption'),
    CustomMessage('DataDirPageDescription'),
    CustomMessage('DataDirPageSubCaption'),
    False,
    ''
  );
  DataDirPage.Add('');

  ParamDir := NormalizeWindowsPath(ExpandConstant('{param:DATADIR|}'));
  if ParamDir <> '' then
    DataDirPage.Values[0] := ParamDir
  else if SavedDir <> '' then
    DataDirPage.Values[0] := SavedDir
  else
    DataDirPage.Values[0] := NormalizeWindowsPath(GetPreviousData('DataDir', DefaultDataDir));

  ResetDataDirButton := TNewButton.Create(DataDirPage);
  ResetDataDirButton.Parent := DataDirPage.Surface;
  ResetDataDirButton.Caption := CustomMessage('DataDirResetButton');
  ResetDataDirButton.Width := ScaleX(140);
  ResetDataDirButton.Height := ScaleY(26);
  ResetDataDirButton.Left := DataDirPage.Edits[0].Left;
  ResetDataDirButton.Top := DataDirPage.Edits[0].Top + DataDirPage.Edits[0].Height + ScaleY(10);
  ResetDataDirButton.OnClick := @OnResetDataDirClick;

  if HasExistingDatabase then
  begin
    ExistingDataLabel := TNewStaticText.Create(DataDirPage);
    ExistingDataLabel.Parent := DataDirPage.Surface;
    ExistingDataLabel.WordWrap := True;
    ExistingDataLabel.Width := DataDirPage.SurfaceWidth;
    ExistingDataLabel.Left := DataDirPage.Edits[0].Left;
    ExistingDataLabel.Top := ResetDataDirButton.Top + ResetDataDirButton.Height + ScaleY(12);
    ExistingDataLabel.Caption := FmtMessage(
      CustomMessage('DataDirExistingNote'),
      [OriginalDataDir]
    );
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Target: String;
  ErrorText: String;
begin
  Result := True;
  if CurPageID <> DataDirPage.ID then Exit;

  Target := NormalizeWindowsPath(DataDirPage.Values[0]);
  DataDirPage.Values[0] := Target;

  if Target = '' then
    ErrorText := CustomMessage('DataDirInvalidEmpty')
  else if not IsAbsoluteWindowsPath(Target) then
    ErrorText := CustomMessage('DataDirInvalidRelative')
  else if IsDriveRootPath(Target) then
    ErrorText := CustomMessage('DataDirInvalidDriveRoot')
  else if IsInsideAppDirectory(Target) then
    ErrorText := CustomMessage('DataDirInvalidInsideApp')
  else
    ErrorText := '';

  if ErrorText <> '' then
  begin
    if not WizardSilent then
      MsgBox(ErrorText, mbError, MB_OK);
    Result := False;
    Exit;
  end;

  if CompareText(Target, OriginalDataDir) <> 0 then
  begin
    if FileExists(AddBackslash(Target) + 'node_diary.sqlite') then
    begin
      if HasExistingDatabase and (not WizardSilent) then
      begin
        if MsgBox(
          CustomMessage('DataDirConfirmSwitchExisting'),
          mbConfirmation,
          MB_YESNO
        ) <> IDYES then
        begin
          Result := False;
          Exit;
        end;
      end;
    end
    else if DirHasBlockingEntries(Target, CompareText(Target, DefaultDataDir) = 0) then
    begin
      if not WizardSilent then
        MsgBox(CustomMessage('DataDirInvalidNotEmpty'), mbError, MB_OK);
      Result := False;
      Exit;
    end;
  end;
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
var
  Target: String;
  Line: String;
begin
  Result := '';
  if MemoUserInfoInfo <> '' then
    Result := Result + MemoUserInfoInfo + NewLine + NewLine;
  if MemoDirInfo <> '' then
    Result := Result + MemoDirInfo + NewLine + NewLine;

  Target := NormalizeWindowsPath(DataDirPage.Values[0]);
  Line := CustomMessage('DataDirReadyHeader') + NewLine + Space + Target;
  if HasExistingDatabase and (CompareText(Target, OriginalDataDir) <> 0) and
     (not FileExists(AddBackslash(Target) + 'node_diary.sqlite')) then
    Line := Line + ' ' + CustomMessage('DataDirReadyMigrateSuffix');
  Result := Result + Line + NewLine + NewLine;

  if MemoTypeInfo <> '' then
    Result := Result + MemoTypeInfo + NewLine + NewLine;
  if MemoComponentsInfo <> '' then
    Result := Result + MemoComponentsInfo + NewLine + NewLine;
  if MemoGroupInfo <> '' then
    Result := Result + MemoGroupInfo + NewLine + NewLine;
  if MemoTasksInfo <> '' then
    Result := Result + MemoTasksInfo + NewLine;
end;

procedure RegisterPreviousData(PreviousDataKey: Integer);
begin
  SetPreviousData(PreviousDataKey, 'DataDir', NormalizeWindowsPath(DataDirPage.Values[0]));
end;

procedure WriteUtf8TextFile(const FilePath, Content: String);
var
  Lines: TArrayOfString;
begin
  ForceDirectories(ExtractFileDir(FilePath));
  SetArrayLength(Lines, 1);
  Lines[0] := Content;
  SaveStringsToUTF8File(FilePath, Lines, False);
end;

procedure WriteUserLocationJson(const ConfigFile, ActivePath, PendingTargetPath: String; const UseDefault: Boolean);
var
  Json: String;
begin
  Json := '{"version":1';
  if UseDefault then
    Json := Json + ',"path":null,"useDefault":true'
  else
    Json := Json + ',"path":"' + EscapeJsonString(ActivePath) + '"';
  if PendingTargetPath <> '' then
    Json := Json + ',"pendingTargetPath":"' + EscapeJsonString(PendingTargetPath) + '"';
  Json := Json + '}';
  WriteUtf8TextFile(ConfigFile, Json);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Target: String;
  ConfigFile, AppSeedFile: String;
  IsTargetDefault, IsOriginalDefault: Boolean;
begin
  if CurStep <> ssPostInstall then Exit;

  Target := NormalizeWindowsPath(DataDirPage.Values[0]);
  ConfigFile := AddBackslash(DefaultDataDir) + 'data_location.json';
  AppSeedFile := ExpandConstant('{app}\jotsy_data_location.json');
  ForceDirectories(Target);

  IsTargetDefault := CompareText(Target, DefaultDataDir) = 0;
  IsOriginalDefault := CompareText(OriginalDataDir, DefaultDataDir) = 0;

  if HasExistingDatabase and (CompareText(Target, OriginalDataDir) <> 0) then
  begin
    if FileExists(AddBackslash(Target) + 'node_diary.sqlite') then
      WriteUserLocationJson(ConfigFile, Target, '', IsTargetDefault)
    else
      WriteUserLocationJson(ConfigFile, OriginalDataDir, Target, IsOriginalDefault);
    Exit;
  end;

  if IsTargetDefault then
  begin
    if FileExists(ConfigFile) then
      WriteUserLocationJson(ConfigFile, '', '', True);
    if FileExists(AppSeedFile) then
      DeleteFile(AppSeedFile);
  end
  else
  begin
    WriteUserLocationJson(ConfigFile, Target, '', False);
    WriteUtf8TextFile(
      AppSeedFile,
      '{"version":1,"defaultPath":"' + EscapeJsonString(Target) + '"}'
    );
  end;
end;
