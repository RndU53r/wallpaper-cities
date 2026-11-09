; Inno Setup script for World Time Screensaver.
;
; A Windows screensaver has to actually live in %WINDIR%\System32 (or the
; matching WOW64 path) with a .scr extension for Control Panel's "Screen
; Saver" dropdown to list it at all -- that's a directory scan, not a
; registry lookup -- so this installer copies the whole publish output
; (the renamed .scr, its .exe, supporting DLLs, and the bundled web\ assets
; it loads at runtime) into {sys} rather than Program Files. Same thing the
; README already describes as the manual "copy into System32" step; this
; just automates it.
;
; Unsigned, per the project's current signing status (see README) --
; installing/running it will trigger a SmartScreen warning until it's
; signed with a real certificate.
;
; Build first:
;   dotnet publish windows\WorldTimeScreensaver\WorldTimeScreensaver\WorldTimeScreensaver.csproj ^
;     -c Release -r win-x64 --self-contained -o windows\installer\publish
; Then compile this script with the Inno Setup Compiler (iscc.exe), or via
; the windows CI workflow, which does both steps.

#define MyAppName "World Time Screensaver"
#define MyAppVersion "1.0"
#define PublishDir "publish"

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=World Time
DefaultDirName={sys}
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
UsePreviousAppDir=no
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=output
OutputBaseFilename=WorldTimeScreensaverSetup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Files]
; Everything the publish step produced -- exe, the renamed .scr, DLLs,
; the WebView2 loader, and the web\ folder the app loads at runtime --
; goes into System32 as one unit so the .scr can find its own assets via
; AppContext.BaseDirectory.
Source: "{#PublishDir}\*"; DestDir: "{sys}"; Flags: ignoreversion recursesubdirs createallsubdirs

[UninstallDelete]
Type: filesandordirs; Name: "{sys}\web"

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    { Let the user know it installed and how to select it -- this installer
      places the .scr so it's listed, but doesn't silently change the
      user's active screensaver. }
    MsgBox('World Time Screensaver installed.' + #13#10 + #13#10 +
      'Open Settings -> Personalization -> Lock screen -> Screen saver settings, ' +
      'and choose "WorldTimeScreensaver" from the dropdown.',
      mbInformation, MB_OK);
  end;
end;
