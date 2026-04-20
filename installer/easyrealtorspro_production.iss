; EasyRealtorsPro - Production Installer Script
; Generated for Windows deployment with all dependencies
; Version: 1.0.0
; Date: April 2025

#define MyAppName "EasyRealtorsPro"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Real Estate Management Solutions"
#define MyAppURL "https://easyrealtorspro.com"
#define MyAppExeName "easyrealtorspro.exe"
#define MyAppAssocName "EasyRealtorsPro Real Estate Management"
#define MyAppAssocExt ".erp"
#define MyAppAssocDesc "EasyRealtorsPro Project File"

; Source directory (where your Flutter build output is located)
#define MySourceDir "build\windows\x64\runner\Release"

; Include necessary libraries
#include "Messages.iss"
#include "Sections.iss"
#include "Tasks.iss"
#include "Icons.iss"

[Setup]
; Application identification
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppCopyright={#MyAppPublisher} © 2025

; Installation settings
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=LICENSE.txt
InfoBeforeFile=README.txt
OutputDir=installer_output
OutputBaseFilename=EasyRealtorsPro_Setup_{#MyAppVersion}_Production
SetupIconFile=assets\icons\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
InternalCompressLevel=ultra
ShowLanguageDialog=yes
Languages=en
LanguageDetectionMethod=locale

; Modern UI settings
WizardStyle=modern
WizardImageFile=installer_assets\wizard_image.bmp
WizardSmallImageFile=installer_assets\wizard_small.bmp
SetupLogging=yes

; Privileges and compatibility
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline
MinVersion=6.1sp1
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

; Windows version requirements
; Requires Windows 10 version 1903 (Build 18362) or later
MinWindowsVersion=10.0.18362

; Additional system requirements
Requires64Bit=yes
RequiresWindowsVersion=10

[Types]
Name: "full"; Description: "Full installation"; Flags: iscustom
Name: "compact"; Description: "Compact installation"; Flags: iscustom
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
Name: "main"; Description: "Main Application"; Types: full compact custom; Flags: fixed
Name: "data"; Description: "Sample Data & Templates"; Types: full
Name: "docs"; Description: "Documentation"; Types: full
Name: "desktop"; Description: "Desktop Shortcut"; Types: full compact custom

[Dirs]
Name: "{app}\data"
Name: "{app}\logs"
Name: "{app}\backup"
Name: "{app}\temp"
Name: "{app}\assets"
Name: "{app}\assets\fonts"
Name: "{app}\assets\images"
Name: "{app}\assets\icons"

[Files]
; Main application files
Source: "{#MySourceDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion; Components: main
Source: "{#MySourceDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion; Components: main
Source: "{#MySourceDir}\*.json"; DestDir: "{app}"; Flags: ignoreversion; Components: main

; Flutter runtime dependencies
Source: "{#MySourceDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion; Components: main
Source: "{#MySourceDir}\vulkan-1.dll"; DestDir: "{app}"; Flags: ignoreversion; Components: main
Source: "{#MySourceDir}\vulkan-1-*.dll"; DestDir: "{app}"; Flags: ignoreversion; Components: main

; Visual C++ Redistributable (if not bundled)
Source: "redistributables\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall; Components: main; Check: VCRedistNeedsInstall

; Application assets
Source: "assets\*"; DestDir: "{app}\assets"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: main
Source: "assets\fonts\*.ttf"; DestDir: "{app}\assets\fonts"; Flags: ignoreversion; Components: main
Source: "assets\images\*"; DestDir: "{app}\assets\images"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: main
Source: "assets\icons\*"; DestDir: "{app}\assets\icons"; Flags: ignoreversion; Components: main

; Sample data and templates (optional)
Source: "sample_data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: data

; Documentation (optional)
Source: "docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: docs

; License and documentation files
Source: "LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion; Components: main
Source: "README.txt"; DestDir: "{app}"; Flags: ignoreversion; Components: main
Source: "CHANGELOG.txt"; DestDir: "{app}"; Flags: ignoreversion; Components: docs

; Configuration files
Source: "config\*"; DestDir: "{app}\config"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: main

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Components: desktop
Name: "quicklaunchicon"; Description: "Create a Quick Launch shortcut"; GroupDescription: "Additional icons:"; Components: desktop
Name: "startup"; Description: "Run application at Windows startup"; GroupDescription: "Startup:"; Flags: unchecked

[Icons]
; Main application shortcuts
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\assets\icons\app_icon.ico"; Comment: "Real Estate Management System"; Components: main
Name: "{group}\{#MyAppName} (Safe Mode)"; Filename: "{app}\{#MyAppExeName}"; Parameters: "--safe-mode"; IconFilename: "{app}\assets\icons\app_icon_safe.ico"; Comment: "Start in Safe Mode"; Components: main
Name: "{group}\{#MyAppName} Configuration"; Filename: "{app}\config\settings.json"; IconFilename: "{app}\assets\icons\config.ico"; Comment: "Application Configuration"; Components: main

; Documentation shortcuts
Name: "{group}\Documentation\User Manual"; Filename: "{app}\docs\user_manual.pdf"; Components: docs
Name: "{group}\Documentation\API Reference"; Filename: "{app}\docs\api_reference.html"; Components: docs
Name: "{group}\Documentation\Release Notes"; Filename: "{app}\CHANGELOG.txt"; Components: docs

; Utility shortcuts
Name: "{group}\Utilities\Backup Data"; Filename: "{app}\backup_tool.exe"; WorkingDir: "{app}"; Components: main
Name: "{group}\Utilities\Restore Data"; Filename: "{app}\restore_tool.exe"; WorkingDir: "{app}"; Components: main
Name: "{group}\Utilities\Database Maintenance"; Filename: "{app}\db_maintenance.exe"; WorkingDir: "{app}"; Components: main

; System shortcuts
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"; Comment: "Remove {#MyAppName} from your computer"

; Desktop shortcuts
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\assets\icons\app_icon.ico"; Tasks: desktopicon; Comment: "Real Estate Management System"; Components: desktop
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\assets\icons\app_icon.ico"; Tasks: quicklaunchicon; Components: desktop

[Run]
; Main application
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent; Components: main

; Visual C++ Redistributable installation
Filename: "{tmp}\vc_redist.x64.exe"; Description: "Installing Visual C++ Redistributable..."; Parameters: "/quiet /norestart"; StatusMsg: "Installing required runtime components..."; Flags: runhidden waituntilterminated; Check: VCRedistNeedsInstall

; Database initialization (first run)
Filename: "{app}\{#MyAppExeName}"; Description: "Initializing database..."; Parameters: "--init-db"; Flags: runhidden waituntilterminated; Components: main

; Configuration setup (first run)
Filename: "{app}\config_tool.exe"; Description: "Setting up configuration..."; Parameters: "--first-run"; Flags: runhidden waituntilterminated; Components: main

[Registry]
; Application registration
Root: HKLM; Subkey: "Software\{#MyAppPublisher}\{#MyAppName}"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\{#MyAppPublisher}\{#MyAppName}"; ValueType: string; ValueName: "Version"; ValueData: "{#MyAppVersion}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\{#MyAppPublisher}\{#MyAppName}"; ValueType: string; ValueName: "InstallDate"; ValueData: "{code:GetDateTime}"; Flags: uninsdeletekey

; File association
Root: HKLM; Subkey: "Software\Classes\{#MyAppAssocExt}"; ValueType: string; ValueName: ""; ValueData: "{#MyAppAssocName}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Classes\{#MyAppAssocExt}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Classes\{#MyAppAssocExt}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Flags: uninsdeletekey

; Windows 10/11 App Registration (for modern Windows features)
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\{#MyAppExeName}"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\{#MyAppExeName}"; ValueType: string; ValueName: "Path"; ValueData: "{app}"; Flags: uninsdeletekey

[UninstallDelete]
; Remove application directories
Type: filesandordirs; Name: "{app}\data"
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\backup"
Type: filesandordirs; Name: "{app}\temp"
Type: filesandordirs; Name: "{app}\assets"

; Remove user data (optional - uncomment if you want to preserve user data)
; Type: filesandordirs; Name: "{app}\user_data"

[Code]
// Custom code functions

// Function to check if Visual C++ Redistributable needs to be installed
function VCRedistNeedsInstall: Boolean;
var
  Version: String;
begin
  // Check if VC++ 2019-2022 Redistributable is installed
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version) then
  begin
    Result := True;
  end
  else
  begin
    // Check if version is less than required (minimum v14.28.29333.0)
    Result := (CompareStr(Version, '14.28.29333.0') < 0);
  end;
end;

// Function to get current date/time
function GetDateTime: String;
var
  Year, Month, Day, Hour, Min, Sec: Word;
begin
  DecodeDate(Now, Year, Month, Day);
  DecodeTime(Now, Hour, Min, Sec, 0);
  Result := Format('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', [Year, Month, Day, Hour, Min, Sec]);
end;

// Function to validate Windows version
function InitializeSetup(): Boolean;
var
  Version: TWindowsVersion;
begin
  GetWindowsVersionEx(Version);
  
  // Check if Windows 10 version 1903 (Build 18362) or later
  if (Version.Major < 10) or ((Version.Major = 10) and (Version.Build < 18362)) then
  begin
    MsgBox('EasyRealtorsPro requires Windows 10 version 1903 (Build 18362) or later.' + #13#10 +
           'Your Windows version: ' + IntToStr(Version.Major) + '.' + IntToStr(Version.Minor) + ' (Build ' + IntToStr(Version.Build) + ')' + #13#10 +
           'Please upgrade your Windows version and try again.', mbError, MB_OK);
    Result := False;
  end
  else
  begin
    Result := True;
  end;
end;

// Function to create backup before uninstallation
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  BackupDir: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    // Create backup directory with timestamp
    BackupDir := ExpandConstant('{app}\backup\uninstall_' + FormatDateTime('yyyymmdd_hhnnss', Now));
    
    // Create backup directory if it doesn't exist
    if not DirExists(BackupDir) then
      CreateDir(BackupDir);
    
    // Backup important data files
    if FileExists(ExpandConstant('{app}\data\database.db')) then
      FileCopy(ExpandConstant('{app}\data\database.db'), BackupDir + '\database.db', False);
      
    if FileExists(ExpandConstant('{app}\config\settings.json')) then
      FileCopy(ExpandConstant('{app}\config\settings.json'), BackupDir + '\settings.json', False);
      
    if DirExists(ExpandConstant('{app}\user_data')) then
      CopyDir(ExpandConstant('{app}\user_data'), BackupDir + '\user_data');
      
    MsgBox('A backup of your important data has been created in:' + #13#10 +
           BackupDir + #13#10#13#10 +
           'Please save this backup before proceeding with uninstallation.', mbInformation, MB_OK);
  end;
end;

// Function to validate installation directory
function NextButtonClick(CurPageID: Integer): Boolean;
var
  InstallDir: String;
begin
  Result := True;
  
  if CurPageID = wpSelectDir then
  begin
    InstallDir := ExpandConstant('{app}');
    
    // Check if directory exists and contains files
    if DirExists(InstallDir) and (FileExists(InstallDir + '\' + #MyAppExeName) or DirExists(InstallDir + '\data')) then
    begin
      if MsgBox('The selected directory already contains an installation of EasyRealtorsPro.' + #13#10 +
                'Do you want to overwrite the existing installation?' + #13#10#13#10 +
                'Click Yes to overwrite, No to choose a different directory.', mbConfirmation, MB_YESNO) = IDNO then
      begin
        Result := False;
      end;
    end;
  end;
  
  // Validate disk space (minimum 500MB required)
  if CurPageID = wpReady then
  begin
    if not HasDiskSpace(ExpandConstant('{app}'), 500 * 1024 * 1024) then
    begin
      MsgBox('Insufficient disk space. EasyRealtorsPro requires at least 500 MB of free disk space.', mbError, MB_OK);
      Result := False;
    end;
  end;
end;

// Function to handle setup completion
procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpFinished then
  begin
    // Set default checkboxes
    WizardForm.RunList.Checked[0] := True; // Launch application
    WizardForm.RunList.Checked[1] := False; // View README
  end;
end;

// Function to register for automatic updates (placeholder)
function RegisterForUpdates: Boolean;
begin
  // This would typically connect to your update server
  // For now, just return True to indicate success
  Result := True;
  
  // You could add code here to:
  // 1. Register the installation with your update server
  // 2. Store installation GUID for future updates
  // 3. Configure update check frequency
end;

// Function to validate license key (if using license-based distribution)
function ValidateLicenseKey(const LicenseKey: String): Boolean;
begin
  // Add your license validation logic here
  // For now, accept any non-empty key
  Result := (LicenseKey <> '');
  
  // You could implement:
  // 1. Online license validation
  // 2. Local license file verification
  // 3. Hardware fingerprinting
  // 4. Trial period enforcement
end;

// Function to create desktop shortcut with proper permissions
procedure CreateDesktopShortcut;
var
  ShortcutPath: String;
begin
  ShortcutPath := ExpandConstant('{autodesktop}\{#MyAppName}.lnk');
  
  // Create shortcut with elevated permissions if needed
  if not FileExists(ShortcutPath) then
  begin
    CreateShellLink(
      ShortcutPath,
      '{#MyAppName}',
      ExpandConstant('{app}\{#MyAppExeName}'),
      '',
      ExpandConstant('{app}\assets\icons\app_icon.ico'),
      '',
      SW_SHOWNORMAL,
      ExpandConstant('{app}')
    );
  end;
end;

// Function to configure firewall exception
procedure ConfigureFirewall;
begin
  // Add Windows Firewall exception for the application
  // This is optional and requires admin privileges
  try
    Exec('netsh', 'advfirewall firewall add rule name="{#MyAppName}" dir=in program="' + ExpandConstant('{app}\{#MyAppExeName}') + '" action=allow', '', SW_HIDE, ewWaitUntilTerminated, 0);
  except
    // Firewall configuration failed, but installation should continue
  end;
end;

// Function to set up automatic startup
procedure SetupStartup;
begin
  if WizardIsTaskSelected('startup') then
  begin
    // Add to Windows startup programs
    RegWriteStringValue(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\Run', '{#MyAppName}', '"' + ExpandConstant('{app}\{#MyAppExeName}') + '"');
  end;
end;

// Function to perform post-installation tasks
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Create desktop shortcut
    if WizardIsTaskSelected('desktopicon') then
      CreateDesktopShortcut;
      
    // Configure firewall
    ConfigureFirewall;
    
    // Set up startup
    SetupStartup;
    
    // Register for updates
    RegisterForUpdates;
    
    // Create initial directories
    if not DirExists(ExpandConstant('{app}\logs')) then
      CreateDir(ExpandConstant('{app}\logs'));
      
    if not DirExists(ExpandConstant('{app}\backup')) then
      CreateDir(ExpandConstant('{app}\backup'));
      
    if not DirExists(ExpandConstant('{app}\temp')) then
      CreateDir(ExpandConstant('{app}\temp'));
  end;
end;

// Function to handle installation errors
procedure DeinitializeSetup();
begin
  // Log installation completion
  Log('EasyRealtorsPro installation completed successfully at ' + GetDateTime);
  
  // Clean up temporary files
  DeleteFile(ExpandConstant('{tmp}\vc_redist.x64.exe'));
end;

// Function to validate system requirements
function CheckSystemRequirements: Boolean;
var
  Memory: DWORD;
  DiskSpace: Int64;
begin
  Result := True;
  
  // Check minimum RAM (4GB recommended)
  Memory := GetSystemMemoryDisplay;
  if Memory < 2048 then // Less than 2GB
  begin
    if MsgBox('EasyRealtorsPro requires at least 4GB of RAM for optimal performance.' + #13#10 +
              'Your system has ' + IntToStr(Memory) + 'MB of RAM.' + #13#10#13#10 +
              'The application may run slowly. Continue with installation?', mbConfirmation, MB_YESNO) = IDNO then
    begin
      Result := False;
    end;
  end;
  
  // Check available disk space (minimum 1GB free)
  DiskSpace := GetDiskFreeSpaceMB(ExpandConstant('{app}'));
  if DiskSpace < 1024 then
  begin
    MsgBox('Insufficient disk space. EasyRealtorsPro requires at least 1GB of free disk space.' + #13#10 +
           'Available space: ' + IntToStr(DiskSpace) + 'MB', mbError, MB_OK);
    Result := False;
  end;
end;

// Function to create user data directory on first run
procedure CreateUserDataDirectory;
var
  UserDataDir: String;
begin
  UserDataDir := ExpandConstant('{localappdata}\{#MyAppName}');
  
  if not DirExists(UserDataDir) then
  begin
    CreateDir(UserDataDir);
    CreateDir(UserDataDir + '\data');
    CreateDir(UserDataDir + '\logs');
    CreateDir(UserDataDir + '\backup');
    CreateDir(UserDataDir + '\temp');
  end;
end;

// Function to migrate data from previous version
procedure MigratePreviousVersionData;
var
  OldAppDir, NewAppDir: String;
begin
  // Check for previous installation in default location
  OldAppDir := ExpandConstant('{pf}\EasyRealtorsPro');
  NewAppDir := ExpandConstant('{app}');
  
  if DirExists(OldAppDir) and (OldAppDir <> NewAppDir) then
  begin
    if MsgBox('A previous installation of EasyRealtorsPro was detected.' + #13#10 +
              'Do you want to migrate your existing data to the new installation?' + #13#10#13#10 +
              'This will copy your database, settings, and user data.', mbConfirmation, MB_YESNO) = IDYES then
    begin
      // Migrate data files
      if DirExists(OldAppDir + '\data') then
        CopyDir(OldAppDir + '\data', NewAppDir + '\data');
        
      if FileExists(OldAppDir + '\config\settings.json') then
        FileCopy(OldAppDir + '\config\settings.json', NewAppDir + '\config\settings.json', False);
        
      MsgBox('Data migration completed successfully.', mbInformation, MB_OK);
    end;
  end;
end;

// Additional validation for custom installation
function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  
  // Skip components page if doing compact installation
  if (PageID = wpSelectComponents) and (WizardForm.TypesCombo.ItemIndex = 1) then
    Result := True;
    
  // Skip tasks page if no tasks are available
  if (PageID = wpSelectTasks) and (WizardForm.TypesCombo.ItemIndex = 1) then
    Result := True;
end;
