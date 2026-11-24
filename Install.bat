@echo off
setlocal
set "DEST=%LOCALAPPDATA%\TimeBuddy"
if not exist "%DEST%" mkdir "%DEST%"
copy /Y "%~dp0Guard.ps1" "%DEST%\Guard.ps1" >nul
if errorlevel 1 exit /b 1
powershell.exe -NoProfile -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut([IO.Path]::Combine([Environment]::GetFolderPath('Startup'),'TimeBuddy.lnk'));$s.TargetPath='powershell.exe';$s.Arguments='-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File '+[char]34+$env:LOCALAPPDATA+'\TimeBuddy\Guard.ps1'+[char]34;$s.Save();Unblock-File -LiteralPath ($env:LOCALAPPDATA+'\TimeBuddy\Guard.ps1')"
if errorlevel 1 exit /b 1
start "" powershell.exe -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File "%DEST%\Guard.ps1"
