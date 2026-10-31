@echo off
setlocal enabledelayedexpansion
title Disk Setup (DiskPart)

:: ---- Run as administrator (re-launches itself elevated) ----
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "DP=%temp%\dp_script.txt"
set "OUT=%temp%\dp_out.txt"

:: ---- 1. List disks and select one ----
:pick_disk
cls
echo list disk> "%DP%"
diskpart /s "%DP%"
echo.
set "DISK="
set /p DISK=Select a disk by number: 
echo %DISK%| findstr /r "^[0-9][0-9]*$" >nul || (echo Invalid number.& pause & goto pick_disk)

echo.
echo WARNING: ALL DATA on Disk %DISK% will be ERASED!
set "OK="
set /p OK=Continue? (y/n): 
if /i not "%OK%"=="y" exit /b

:: ---- 2. Clean and create primary partition ----
(
echo select disk %DISK%
echo clean
echo create partition primary
) > "%DP%"
diskpart /s "%DP%"

:: ---- 3. List partitions and select one ----
:pick_part
echo.
(
echo select disk %DISK%
echo list partition
) > "%DP%"
diskpart /s "%DP%"
echo.
set "PART="
set /p PART=Select a partition by number: 
echo %PART%| findstr /r "^[0-9][0-9]*$" >nul || (echo Invalid number.& pause & goto pick_part)

:: ---- 4. Ask DiskPart which formats this partition supports (and its default) ----
(
echo select disk %DISK%
echo select partition %PART%
echo filesystems
) > "%DP%"
diskpart /s "%DP%" > "%OUT%"

set /a N=0
set "FLAG=0"
for /f "usebackq tokens=* delims=" %%L in ("%OUT%") do (
    set "LINE=%%L"
    if "!LINE:Supported for Formatting=!" neq "!LINE!" set "FLAG=1"
    if "!FLAG!"=="1" if "!LINE:~0,4!"=="Type" (
        for /f "tokens=1,* delims=:" %%A in ("!LINE!") do (
            set "NAME=%%B"
            set "NAME=!NAME:~1!"
            set "KEEP=0"
            if /i "!NAME:~0,4!"=="NTFS" set "KEEP=1"
            if /i "!NAME:~0,5!"=="exFAT" set "KEEP=1"
            if /i "!NAME:~0,5!"=="FAT32" set "KEEP=1"
            if "!KEEP!"=="1" (
                set /a N+=1
                set "FMT_!N!=!NAME!"
            )
        )
    )
)

:: Fallback if DiskPart gave no list
if %N%==0 (
    set "FMT_1=NTFS (Default)"
    set "FMT_2=exFAT"
    set "FMT_3=FAT32"
    set /a N=3
)

:pick_fmt
echo.
echo Format layouts:
set "DEF=1"
for /l %%I in (1,1,%N%) do (
    echo   %%I. !FMT_%%I!
    set "T=!FMT_%%I!"
    if "!T:Default=!" neq "!T!" set "DEF=%%I"
)
set "FMT="
set /p FMT=Select a format layout by number [%DEF%]: 
if not defined FMT set "FMT=%DEF%"
echo %FMT%| findstr /r "^[0-9][0-9]*$" >nul || (echo Invalid choice.& goto pick_fmt)
if %FMT% lss 1 (echo Invalid choice.& goto pick_fmt)
if %FMT% gtr %N% (echo Invalid choice.& goto pick_fmt)
set "FS=!FMT_%FMT%!"
set "FS=!FS: (Default)=!"

:: ---- 5. Format and set active ----
(
echo select disk %DISK%
echo select partition %PART%
echo format fs=!FS! quick
echo active
) > "%DP%"
diskpart /s "%DP%"

:: ---- 6. Assign a letter? ----
echo.
set "ASG="
set /p ASG=Assign a new drive letter to it? (y/n): 
if /i "%ASG%"=="y" (
    (
    echo select disk %DISK%
    echo select partition %PART%
    echo assign
    ) > "%DP%"
    diskpart /s "%DP%"
)

del "%DP%" "%OUT%" >nul 2>&1
echo.
echo Done.
pause
exit /b
