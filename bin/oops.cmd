@echo off
REM Windows shim for `oops`, so cmd.exe and PowerShell can run it without
REM entering Git Bash first. The real script is `bin/oops` beside this file and
REM this only finds a bash to hand it to - there is no second implementation to
REM drift out of step.
setlocal
set "OOPS_SH=%~dp0oops"

REM Git Bash is looked for FIRST and PATH only after. The bash on a default
REM Windows PATH is C:\Windows\System32\bash.exe, which is the WSL launcher: it
REM takes Linux paths, so handing it "C:\...\bin\oops" fails with a confusing
REM "No such file or directory" for a file that plainly exists.
set "BASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
if not defined BASH for %%B in (bash.exe) do if /i not "%%~dpB"=="%SystemRoot%\System32\" set "BASH=%%~$PATH:B"

if not defined BASH (
    echo error: oops needs bash, and none was found. 1>&2
    echo Install Git for Windows, which provides it: https://git-scm.com/download/win 1>&2
    exit /b 1
)

"%BASH%" "%OOPS_SH%" %*
exit /b %ERRORLEVEL%
