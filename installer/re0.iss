#ifndef AppVersion
  #error AppVersion must be supplied by the build script
#endif
#define AppName "RE0"

[Setup]
AppId={{BEEA9A55-B350-43A3-8884-6A723A7B8870}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=dq52099
AppPublisherURL=https://image.6688667.xyz/
DefaultDirName={localappdata}\Programs\RE0
DefaultGroupName=RE0
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\build\release
OutputBaseFilename=RE0-{#AppVersion}-windows-x64-setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\RE0.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
SetupLogging=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\RE0"; Filename: "{app}\RE0.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\RE0"; Filename: "{app}\RE0.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\RE0.exe"; Description: "Launch RE0"; Flags: nowait postinstall skipifsilent
