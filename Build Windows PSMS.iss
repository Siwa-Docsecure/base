; PSMS_installer.iss - Installer for PSMS

[Setup]
AppName=Physical Storage Management System
AppVersion=1.0
DefaultDirName={pf}\PSMS
DefaultGroupName=DOCSECURE
OutputDir=C:\Users\ui\Desktop\base\outputs\Installer
OutputBaseFilename=PSMS Installer
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
SetupIconFile=C:\Users\ui\Desktop\base\psms\assets\logo\logo.ico
LicenseFile=C:\Users\ui\Desktop\base\psms\assets\documents\license.txt
AppPublisher=Docsecure Eswatini
AppPublisherURL=https://docsecuresd.com
AppSupportURL=https://docsecuresd.com/support
AppUpdatesURL=https://docsecuresd.com/updates
VersionInfoVersion=1.0.0.0
VersionInfoCompany=DOCSECURE
VersionInfoDescription=Physical Storage Management System
VersionInfoCopyright=Copyright (C) 2026 Docsecure Eswatini
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; Include all compiled Flutter Windows output files
Source: "C:\Users\ui\Desktop\base\psms\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Physical Storage Management System"; Filename: "{app}\psms.exe"
Name: "{commondesktop}\Physical Storage Management System"; Filename: "{app}\psms.exe"; Tasks: desktopicon
Name: "{group}\Uninstall Physical Storage Management System"; Filename: "{uninstallexe}"
Name: "{commonstartup}\Physical Storage Management System"; Filename: "{app}\psms.exe"; Parameters: "--minimized"; Tasks: startupicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"
Name: "startupicon"; Description: "Start with &Windows"; GroupDescription: "Additional options:"

[Registry]
Root: HKLM; Subkey: "Software\DOCSECURE\PSMS"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\DOCSECURE\TDFS"; ValueType: string; ValueName: "Version"; ValueData: "1.0"; Flags: uninsdeletekey

[Run]
Filename: "{app}\psms.exe"; Description: "Launch PSMS"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
procedure InitializeWizard();
begin
  WizardForm.WelcomeLabel1.Caption := 'Welcome toPhysical Storage Management System Setup';
  WizardForm.WelcomeLabel2.Caption := 'This will install Physical Storage Management System on your computer.' + #13#10#13#10 +
    'Physical Storage Management System is a secure, easy to use document Management platform. Build for emaSwati, in eswatini.' + #13#10#13#10 +
    'Click Next to continue, or Cancel to exit Setup.';
end;


[Setup]
