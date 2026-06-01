@echo off
setlocal EnableDelayedExpansion

:: ============================================================
::  javaswitch.cmd - Java Version Switcher  v1.5
::  Place in C:\Windows\System32\
:: ============================================================

title Java Version Switcher

set COUNT=0

:: ------------------------------------------------------------
::  SCAN FOR INSTALLED JDK / JRE
::  Add your own paths at the bottom of this block if needed
:: ------------------------------------------------------------

call :SCAN "C:\Program Files\Java"
call :SCAN "C:\Program Files\Eclipse Adoptium"
call :SCAN "C:\Program Files\Eclipse Foundation"
call :SCAN "C:\Program Files\Microsoft"
call :SCAN "C:\Program Files\Zulu"
call :SCAN "C:\Program Files\BellSoft"
call :SCAN "C:\Program Files\Amazon Corretto"
call :SCAN "C:\Program Files\SapMachine"
call :SCAN "C:\Program Files\Semeru"
call :SCAN "C:\Program Files (x86)\Java"
call :SCAN "C:\Program Files (x86)\Eclipse Adoptium"
call :SCAN "C:\java"
call :SCAN "C:\jdk"
call :SCAN "C:\tools\java"
call :SCAN "C:\tools\jdk"
call :SCAN "D:\Java"
call :SCAN "D:\jdk"

goto :MENU

:SCAN
set "ROOT=%~1"
if not exist "%ROOT%" exit /b
for /d %%D in ("%ROOT%\*") do (
    if exist "%%D\bin\java.exe" (
        set /a COUNT+=1
        set "JAVA_PATH_!COUNT!=%%D"
        "%%D\bin\java.exe" -version 2>"%TEMP%\jver_tmp.txt" >nul
        set /p "JAVA_VER_!COUNT!="<"%TEMP%\jver_tmp.txt"
        del "%TEMP%\jver_tmp.txt" >nul 2>&1
    )
)
exit /b

:: Show the currently active java (called from MENU).
:SHOW_ACTIVE
for /f "tokens=*" %%V in ('java -version 2^>^&1 ^| findstr /i "version"') do echo    %%V
for /f "tokens=*" %%P in ('where java 2^>nul') do echo    Path: %%P
exit /b

:: Returns errorlevel 0 if the given PATH segment looks like a Java install,
:: 1 otherwise. One /c: per findstr at top level -> reliable errorlevel,
:: no fragile multiple-/c: and no pipe-in-block.
:ISJAVABIN
set "_seg=%~1"
echo !_seg!| findstr /i /c:"\java\"     >nul 2>&1 && exit /b 0
echo !_seg!| findstr /i /c:"\jdk"       >nul 2>&1 && exit /b 0
echo !_seg!| findstr /i /c:"\jre"       >nul 2>&1 && exit /b 0
echo !_seg!| findstr /i /c:"adoptium"   >nul 2>&1 && exit /b 0
echo !_seg!| findstr /i /c:"corretto"   >nul 2>&1 && exit /b 0
echo !_seg!| findstr /i /c:"zulu"       >nul 2>&1 && exit /b 0
echo !_seg!| findstr /i /c:"bellsoft"   >nul 2>&1 && exit /b 0
echo !_seg!| findstr /i /c:"semeru"     >nul 2>&1 && exit /b 0
echo !_seg!| findstr /i /c:"sapmachine" >nul 2>&1 && exit /b 0
exit /b 1

:: Notify running processes that the environment changed so new windows
:: pick up the change (reg add, unlike setx, does not broadcast on its own).
:BROADCAST
powershell -NoProfile -Command ^
  "$sig='[DllImport(\"user32.dll\")]public static extern IntPtr SendMessageTimeout(IntPtr h,uint m,UIntPtr w,string l,uint f,uint t,out UIntPtr r);';" ^
  "$t=Add-Type -MemberDefinition $sig -Name WinAPI -Namespace Env -PassThru;" ^
  "$r=[UIntPtr]::Zero;" ^
  "$t::SendMessageTimeout([IntPtr]0xffff,0x001A,[UIntPtr]::Zero,'Environment',2,5000,[ref]$r)|Out-Null" ^
  >nul 2>&1
exit /b

:: ------------------------------------------------------------
::  MAIN MENU
:: ------------------------------------------------------------
:MENU
cls
echo.
echo  +======================================================+
echo  ^|           Java Version Switcher  v1.5               ^|
echo  +======================================================+
echo.

if %COUNT%==0 (
    echo  No JDK/JRE installations found.
    echo  Add custom search paths inside the script ^(SCAN section^).
    echo.
    pause
    exit /b 1
)

echo  Active Java:
where java >nul 2>&1
if errorlevel 1 (
    echo    [not configured]
) else (
    call :SHOW_ACTIVE
)

echo.
echo  ------------------------------------------------------
echo  Found installations: %COUNT%
echo  ------------------------------------------------------
echo.
for /l %%I in (1,1,%COUNT%) do (
    echo   [%%I] !JAVA_VER_%%I!
    echo       !JAVA_PATH_%%I!
    echo.
)
echo  ------------------------------------------------------
echo   [0] Exit
echo  ------------------------------------------------------
echo.

:ASK_JAVA
set /p "CHOICE= Select Java [0-%COUNT%]: "

if "%CHOICE%"=="0" ( echo. & echo  Bye. & exit /b 0 )

set VALID=0
for /l %%I in (1,1,%COUNT%) do if "%CHOICE%"=="%%I" set VALID=1
if "%VALID%"=="0" ( echo  [X] Enter a number from 0 to %COUNT%. & goto ASK_JAVA )

set "NEW_JAVA_HOME=!JAVA_PATH_%CHOICE%!"
set "NEW_JAVA_BIN=!NEW_JAVA_HOME!\bin"

:: ------------------------------------------------------------
::  SELECT SCOPE
:: ------------------------------------------------------------
echo.
echo  +------------------------------------------------------+
echo  ^|  Apply change to:                                    ^|
echo  ^|                                                      ^|
echo  ^|   [1] This window  - instant, command copied to     ^|
echo  ^|       clipboard ^(just paste and press Enter^)         ^|
echo  ^|   [2] System-wide  - new windows, admin required    ^|
echo  ^|   [0] Cancel                                        ^|
echo  +------------------------------------------------------+
echo.

:ASK_SCOPE
set /p "SCOPE= Your choice [0-2]: "

if "%SCOPE%"=="0" ( echo. & echo  Cancelled. & exit /b 0 )
if "%SCOPE%"=="1" goto APPLY_WINDOW
if "%SCOPE%"=="2" goto APPLY_SYSTEM
echo  [X] Enter 0, 1 or 2.
goto ASK_SCOPE

:: ------------------------------------------------------------
::  [1] THIS WINDOW - writes a helper .bat, copies the command
::      to the clipboard. Why a helper: `set` in a child process
::      cannot modify the parent CMD; the helper run with `call`
::      shares the parent environment.
:: ------------------------------------------------------------
:APPLY_WINDOW
set "HELPER=%TEMP%\javaswitch_env.bat"

:: Build clean PATH (strip old java entries from current PATH)
set "CLEAN_PATH="
for %%S in ("!PATH:;=" "!") do (
    set "SEG=%%~S"
    if defined SEG (
        call :ISJAVABIN "!SEG!"
        if errorlevel 1 (
            if defined CLEAN_PATH (set "CLEAN_PATH=!CLEAN_PATH!;!SEG!") else (set "CLEAN_PATH=!SEG!")
        )
    )
)

:: Write helper script
(
    echo @echo off
    echo set "JAVA_HOME=!NEW_JAVA_HOME!"
    echo set "PATH=!NEW_JAVA_BIN!;!CLEAN_PATH!"
    echo echo JAVA_HOME = !NEW_JAVA_HOME!
    echo echo PATH updated for this window.
    echo echo.
    echo java -version
) > "!HELPER!"

:: Copy the ready-to-run command to the clipboard
echo call "!HELPER!"| clip 2>nul

echo.
echo  Helper script written and the command is now in your clipboard:
echo.
echo    call "%HELPER%"
echo.
echo  Switch to your CMD window, paste ^(Ctrl+V^) and press Enter.
echo  The change is instant and limited to that window.
echo.
pause & exit /b 0

:: ------------------------------------------------------------
::  [2] SYSTEM-WIDE - registry HKLM, admin required
::      Takes effect in all NEW CMD/PowerShell windows.
:: ------------------------------------------------------------
:APPLY_SYSTEM
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo  [ERROR] Administrator rights required for system-wide changes.
    echo  Re-run javaswitch as Administrator.
    echo.
    pause & exit /b 1
)

echo.
echo  Applying [system-wide]:
echo    !JAVA_VER_%CHOICE%!
echo    !NEW_JAVA_HOME!
echo.

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" ^
    /v "JAVA_HOME" /t REG_EXPAND_SZ /d "!NEW_JAVA_HOME!" /f >nul

set "SYS_PATH="
for /f "skip=2 tokens=2*" %%A in (
    'reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul'
) do set "SYS_PATH=%%B"

set "CLEAN_PATH="
for %%S in ("!SYS_PATH:;=" "!") do (
    set "SEG=%%~S"
    if defined SEG (
        call :ISJAVABIN "!SEG!"
        if errorlevel 1 (
            if defined CLEAN_PATH (set "CLEAN_PATH=!CLEAN_PATH!;!SEG!") else (set "CLEAN_PATH=!SEG!")
        )
    )
)

if defined CLEAN_PATH (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" ^
        /v "Path" /t REG_EXPAND_SZ /d "!NEW_JAVA_BIN!;!CLEAN_PATH!" /f >nul
) else (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" ^
        /v "Path" /t REG_EXPAND_SZ /d "!NEW_JAVA_BIN!" /f >nul
)

call :BROADCAST

echo  JAVA_HOME = !NEW_JAVA_HOME!
echo.
echo  Done. Open a NEW CMD window and verify with: java -version
echo.
pause & exit /b 0