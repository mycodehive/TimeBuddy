@echo off
setlocal
cd /d "%~dp0"
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" (echo .NET Framework compiler not found. & pause & exit /b 1)
"%CSC%" /nologo /target:winexe /codepage:65001 /reference:System.Windows.Forms.dll /out:TimeBuddy_Setup.exe /resource:Guard.ps1,Guard.ps1 /resource:Install.bat,Install.bat /resource:Uninstall.ps1,Uninstall.ps1 Installer.cs
if errorlevel 1 (pause & exit /b 1)
echo Created TimeBuddy_Setup.exe
pause
