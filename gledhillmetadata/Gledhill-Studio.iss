; Inno Setup script for Gledhill Metadata (Flutter Windows)
; Build the app first with: flutter build windows --release

#define MyAppName "Gledhill Metadata"
#define MyAppVersion "1.6"
#define MyAppPublisher "Gledhill Metadata"
#define MyAppURL "https://nerd-or-geek.github.io/Gledhill-Metadata"
#define MyAppExeName "GledhillMetadata.exe"
#define WebsiteDownloadsDir "..\downloads"
#define WebsiteWindowsInstallerName "Gledhill-Metadata-windows"

[Setup]
AppId={{C614D502-14BD-4276-8841-417CE5D3CB4A}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; Export directly to your GitHub Pages downloads folder.
OutputDir={#WebsiteDownloadsDir}
OutputBaseFilename={#WebsiteWindowsInstallerName}
SetupIconFile=C:\Users\cadet\Documents\GitHub\Gledhill-Studio\gledhillstudio\assets\icons\app_logo.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Package the entire Flutter Windows release bundle.
Source: "C:\Users\cadet\Documents\GitHub\Gledhill-Studio\gledhillstudio\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
