; ----------------------------------------------------------------------------
; Inno Setup Script for PSMS Application (Flutter Windows Build)
; Publisher: Docsecure Eswatini
; ----------------------------------------------------------------------------

[Setup]
; Basic installer metadata
AppName=PSMS
AppVersion=1.0.0
AppPublisher=Docsecure Eswatini
AppPublisherURL=https://www.docsecuresd.com
AppSupportURL=https://www.docsecuresd.com/support
AppUpdatesURL=https://www.docsecuresd.com/updates
DefaultDirName={autopf}\PSMS
DefaultGroupName=PSMS
AllowNoIcons=yes

; --- IMPORTANT: Point to your actual built .exe for the uninstall icon ---
UninstallDisplayIcon={app}\psms.exe

; Output (installer) settings
OutputDir=C:\Users\ui\Desktop\base\psms\installer
OutputBaseFilename=PSMS_Setup
Compression=lzma2
SolidCompression=yes

; Setup icon (uses your logo.ico)
SetupIconFile=C:\Users\ui\Desktop\base\psms\assets\logo\logo.ico

; Administrator privileges are required for installation
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; --- UPDATED: Copy everything from your Flutter build output folder ---
Source: "C:\Users\ui\Desktop\base\psms\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Include the logo JPEG (optional, but keeps it in the app folder)
Source: "C:\Users\ui\Desktop\base\psms\assets\logo\logo.jpeg"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; Start Menu shortcut (points to psms.exe)
Name: "{group}\PSMS"; Filename: "{app}\psms.exe"; WorkingDir: "{app}"; IconFilename: "{app}\psms.exe"

; Desktop shortcut
Name: "{commondesktop}\PSMS"; Filename: "{app}\psms.exe"; WorkingDir: "{app}"; IconFilename: "{app}\psms.exe"

[Run]
; Optional: launch the application after installation
Filename: "{app}\psms.exe"; Description: "{cm:LaunchProgram,PSMS}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Remove the application directory upon uninstallation
Type: filesandordirs; Name: "{app}"