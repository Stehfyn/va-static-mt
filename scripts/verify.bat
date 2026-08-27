@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "INSTALLED=%ROOT%\installed"
for %%F in (
    "include\va\va.h"
    "include\va\va_win32.h"
    "lib\va.lib"
    "lib\va_win32.lib"
    "bin\vaon12_drv_video.dll"
    "bin\vaon12_drv_video.pdb"
) do if not exist "%INSTALLED%\%%~F" (
    echo Missing installed file: %%~F.>&2
    exit /b 1
)
if exist "%INSTALLED%\bin\va.dll" exit /b 1
if exist "%INSTALLED%\bin\va_win32.dll" exit /b 1

for %%L in (va.lib va_win32.lib) do (
    dumpbin.exe /nologo /directives "%INSTALLED%\lib\%%L" | findstr /c:"/DEFAULTLIB:LIBCMT" >nul || (
        echo %%L does not use the static MSVC runtime.>&2
        exit /b 1
    )
)
dumpbin.exe /nologo /headers "%INSTALLED%\bin\vaon12_drv_video.dll" | findstr /i /c:"vaon12_drv_video.pdb" >nul || (
    echo vaon12_drv_video.dll does not reference its matching PDB.>&2
    exit /b 1
)

set "BAD_DEPENDENCY="
set "HAVE_SYNCH="
set "HAVE_GDI32="
set "HAVE_KERNEL32="
set "HAVE_SHELL32="
for /f "tokens=*" %%D in ('dumpbin.exe /nologo /dependents "%INSTALLED%\bin\vaon12_drv_video.dll" ^| findstr /r /i /c:"^[ ]*[A-Z0-9.-][A-Z0-9.-]*\.dll[ ]*$"') do call :record_dependency "%%D"
if defined BAD_DEPENDENCY (
    echo Unexpected runtime dependency: %BAD_DEPENDENCY%.>&2
    exit /b 1
)
if not defined HAVE_SYNCH exit /b 1
if not defined HAVE_GDI32 exit /b 1
if not defined HAVE_KERNEL32 exit /b 1
if not defined HAVE_SHELL32 exit /b 1

findstr /c:"search_path = driver_name;" "%ROOT%\sources\mesa\subprojects\libva-2.24.1\va\va.c" >nul || (
    echo The basename-only Windows driver loader patch is absent.>&2
    exit /b 1
)
echo Verification passed: static CRT, matching PDB, and four system DLL imports.
exit /b 0

:record_dependency
if /i "%~1"=="api-ms-win-core-synch-l1-2-0.dll" set "HAVE_SYNCH=1"& exit /b 0
if /i "%~1"=="GDI32.dll" set "HAVE_GDI32=1"& exit /b 0
if /i "%~1"=="KERNEL32.dll" set "HAVE_KERNEL32=1"& exit /b 0
if /i "%~1"=="SHELL32.dll" set "HAVE_SHELL32=1"& exit /b 0
set "BAD_DEPENDENCY=%~1"
exit /b 0
