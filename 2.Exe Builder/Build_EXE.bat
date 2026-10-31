@echo off
title Building DiskFormatter.exe
cd /d "%~dp0"
set "CSC=%windir%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%windir%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" (
    echo Could not find csc.exe ^(.NET Framework 4^). Please tell Claude.
    pause
    exit /b 1
)
if exist DiskFormatter.exe del /f /q DiskFormatter.exe
echo Building DiskFormatter.exe ...
"%CSC%" /nologo /target:winexe /platform:anycpu /out:DiskFormatter.exe /win32manifest:app.manifest /win32icon:DiskFormatter.ico /reference:System.Windows.Forms.dll /resource:DiskFormatter.ps1,DiskFormatter.ps1 Launcher.cs
if %errorlevel% neq 0 (
    echo.
    echo Build FAILED. Copy the message above and send it to Claude.
    pause
    exit /b 1
)
echo.
echo Done! DiskFormatter.exe ^(v3.5^) is ready in this folder.
echo Double-click it to run ^(it will ask for administrator rights^).
pause
