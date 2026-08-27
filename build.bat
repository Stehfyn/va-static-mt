@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "HERE=%~dp0"
pushd "%HERE%" || exit /b 1
call "scripts\versions.bat" || goto :failure

rem Host contract: no caller-defined build options are consumed. Visual Studio
rem is found by vswhere.
for %%T in (git.exe curl.exe tar.exe certutil.exe py.exe) do (
    where.exe %%T >nul 2>&1 || (
        echo Required command is not on PATH: %%T.>&2
        goto :failure
    )
)

if not defined VSCMD_VER (
    set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
    if not exist "!VSWHERE!" (
        echo Visual Studio Installer's vswhere.exe was not found.>&2
        goto :failure
    )
    for /f "usebackq tokens=*" %%I in (`"!VSWHERE!" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%I"
    if not defined VSINSTALL (
        echo Visual Studio with the MSVC x64 tools was not found.>&2
        goto :failure
    )
    call "!VSINSTALL!\VC\Auxiliary\Build\vcvarsall.bat" amd64
    if errorlevel 1 goto :failure
)
for %%T in (cl.exe link.exe lib.exe dumpbin.exe) do (
    where.exe %%T >nul 2>&1 || (
        echo Required build command is not on PATH: %%T.>&2
        goto :failure
    )
)
if not exist "%WindowsSdkDir%Lib\%WindowsSDKVersion%um\x64\d3d12.lib" (
    echo The selected Windows SDK does not provide x64 d3d12.lib.>&2
    goto :failure
)

if exist "installed" rmdir /s /q "installed"
if exist "build" rmdir /s /q "build"
if exist "sources" rmdir /s /q "sources"
mkdir "build" "installed" "sources" "external\cache" 2>nul

set "FLEX_ARCHIVE=external\cache\win_flex_bison-%WINFLEXBISON_VERSION%.zip"
set "FLEX_ROOT=external\win_flex_bison-%WINFLEXBISON_VERSION%"
if not exist "!FLEX_ARCHIVE!" (
    curl.exe --fail --location --show-error ^
        "https://github.com/lexxmark/winflexbison/releases/download/v%WINFLEXBISON_VERSION%/win_flex_bison-%WINFLEXBISON_VERSION%.zip" ^
        --output "!FLEX_ARCHIVE!.partial"
    if errorlevel 1 goto :failure
    move /y "!FLEX_ARCHIVE!.partial" "!FLEX_ARCHIVE!" >nul
)
certutil.exe -hashfile "!FLEX_ARCHIVE!" SHA256 | findstr /i /c:"%WINFLEXBISON_SHA256%" >nul
if errorlevel 1 (
    echo WinFlexBison SHA-256 verification failed.>&2
    goto :failure
)
if not exist "!FLEX_ROOT!\win_flex.exe" (
    mkdir "!FLEX_ROOT!" 2>nul
    tar.exe -xf "!FLEX_ARCHIVE!" -C "!FLEX_ROOT!"
    if errorlevel 1 goto :failure
)

set "VENV=external\python-3.12"
if not exist "!VENV!\Scripts\python.exe" (
    py.exe -3.12 -m venv "!VENV!"
    if errorlevel 1 goto :failure
)
"!VENV!\Scripts\python.exe" -m pip install --disable-pip-version-check ^
    --only-binary=:all: --require-hashes --no-deps ^
    -r "scripts\python-requirements.lock"
if errorlevel 1 goto :failure
set "PATH=%CD%\!VENV!\Scripts;%CD%\!FLEX_ROOT!;%PATH%"

call "scripts\fetch_sources.bat" || goto :failure
call "scripts\build_va.bat" || goto :failure
call "scripts\verify.bat" || goto :failure

popd
endlocal
exit /b 0

:failure
set "BUILD_EXIT=%ERRORLEVEL%"
if "%BUILD_EXIT%"=="0" set "BUILD_EXIT=1"
echo Build failed with exit code %BUILD_EXIT%.>&2
popd
endlocal & exit /b %BUILD_EXIT%
