; Inno Setup 6 script for Markdown Editor.
; Build with installer\build.ps1 (publishes the app, then compiles this script).
; PublishDir can be overridden: ISCC.exe /DPublishDir=<path> MarkdownEditor.iss

#define AppName "Markdown Editor"
#define AppPublisher "Kalisen"
#define AppExeName "MarkdownEditor.exe"
#define AppId "{{6F2C4E0B-8C1E-4B7A-9A53-2D7E5B8F1C34}"
; ProgID registered for the optional file association.
#define ProgId "MarkdownEditor.Document"
#define ProgIdDescription "Markdown Document"

#ifndef PublishDir
  #define PublishDir "..\artifacts\publish"
#endif
; AppVersion can be passed (/DAppVersion=1.2.0-beta.1) to keep a pre-release label; defaults to the exe's version.
#ifndef AppVersion
  #define AppVersion GetVersionNumbersString(AddBackslash(PublishDir) + AppExeName)
#endif

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#AppExeName}
; Per-user install by default (no admin prompt); the user may choose an all-users install instead.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
; Notifies Explorer so the file association takes effect without a sign-out.
ChangesAssociations=yes
OutputDir=..\artifacts\installer
OutputBaseFilename=MarkdownEditor-{#AppVersion}-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "associate"; Description: "Open Markdown files (.md, .markdown) with {#AppName}"; GroupDescription: "File associations:"
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Registry]
; Always: make the app known to Windows' "Open with" list, without claiming any extension.
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExeName}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#AppName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExeName}\SupportedTypes"; ValueType: string; ValueName: ".md"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExeName}\SupportedTypes"; ValueType: string; ValueName: ".markdown"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExeName}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""

; "associate" task: the ProgID and the OpenWithProgids entries. Making the ProgID the extensions' default
; handler is done in [Code], which backs up the previous handler and restores it on uninstall.
Root: HKA; Subkey: "Software\Classes\{#ProgId}"; ValueType: string; ValueName: ""; ValueData: "{#ProgIdDescription}"; Flags: uninsdeletekey; Tasks: associate
Root: HKA; Subkey: "Software\Classes\{#ProgId}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName},0"; Tasks: associate
Root: HKA; Subkey: "Software\Classes\{#ProgId}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""; Tasks: associate
Root: HKA; Subkey: "Software\Classes\.md\OpenWithProgids"; ValueType: string; ValueName: "{#ProgId}"; ValueData: ""; Flags: uninsdeletevalue; Tasks: associate
Root: HKA; Subkey: "Software\Classes\.markdown\OpenWithProgids"; ValueType: string; ValueName: "{#ProgId}"; ValueData: ""; Flags: uninsdeletevalue; Tasks: associate

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
const
  ProgId = '{#ProgId}';
  // Value, on each extension key, holding the handler that was the default before this app took over.
  BackupValueName = '{#ProgId}.backup';

function ExtensionKey(const Ext: String): String;
begin
  Result := 'Software\Classes\' + Ext;
end;

procedure ClaimExtension(const Ext: String);
var
  Previous: String;
begin
  if not RegQueryStringValue(HKA, ExtensionKey(Ext), '', Previous) then
    Previous := '';
  // On a reinstall the default is already ours; keep the original backup.
  if CompareText(Previous, ProgId) <> 0 then
  begin
    if Previous <> '' then
      RegWriteStringValue(HKA, ExtensionKey(Ext), BackupValueName, Previous);
    RegWriteStringValue(HKA, ExtensionKey(Ext), '', ProgId);
  end;
end;

procedure ReleaseExtension(const Ext: String);
var
  Current, Previous: String;
begin
  // Only undo the default if the user has not since picked another handler.
  if RegQueryStringValue(HKA, ExtensionKey(Ext), '', Current) and (CompareText(Current, ProgId) = 0) then
  begin
    if RegQueryStringValue(HKA, ExtensionKey(Ext), BackupValueName, Previous) then
      RegWriteStringValue(HKA, ExtensionKey(Ext), '', Previous)
    else
      RegDeleteValue(HKA, ExtensionKey(Ext), '');
  end;
  RegDeleteValue(HKA, ExtensionKey(Ext), BackupValueName);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssPostInstall) and WizardIsTaskSelected('associate') then
  begin
    ClaimExtension('.md');
    ClaimExtension('.markdown');
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    ReleaseExtension('.md');
    ReleaseExtension('.markdown');
  end;
end;
