@echo off
setlocal
set "DEST=%LOCALAPPDATA%\TimeBuddy"
if not exist "%DEST%" mkdir "%DEST%"
copy /Y "%~dp0Guard.ps1" "%DEST%\Guard.ps1" >nul
if errorlevel 1 exit /b 1
copy /Y "%~dp0Uninstall.ps1" "%DEST%\Uninstall.ps1" >nul
if errorlevel 1 exit /b 1
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop';$d=Join-Path $env:LOCALAPPDATA 'TimeBuddy';$exe=Join-Path $PSHOME 'powershell.exe';$q=[char]34;$w=New-Object -ComObject WScript.Shell;$g=Join-Path $d 'Guard.ps1';$u=Join-Path $d 'Uninstall.ps1';Unblock-File -LiteralPath $g,$u;$s=$w.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Startup')) 'TimeBuddy.lnk'));$s.TargetPath=$exe;$s.Arguments='-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File '+$q+$g+$q;$s.Save();$p=Join-Path ([Environment]::GetFolderPath('Programs')) 'TimeBuddy';New-Item -ItemType Directory -Path $p -Force|Out-Null;$s=$w.CreateShortcut((Join-Path $p 'TimeBuddy Uninstall.lnk'));$s.TargetPath=$exe;$s.Arguments='-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File '+$q+$u+$q;$s.Save();$k='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TimeBuddy';New-Item -Path $k -Force|Out-Null;New-ItemProperty -Path $k -Name DisplayName -Value 'TimeBuddy' -Force|Out-Null;New-ItemProperty -Path $k -Name DisplayVersion -Value '0.1.2' -Force|Out-Null;New-ItemProperty -Path $k -Name InstallLocation -Value $d -Force|Out-Null;New-ItemProperty -Path $k -Name UninstallString -Value ($q+$exe+$q+' '+$s.Arguments) -Force|Out-Null"
if errorlevel 1 exit /b 1
start "" powershell.exe -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File "%DEST%\Guard.ps1"
