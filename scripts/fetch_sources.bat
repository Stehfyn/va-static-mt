@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
call "%ROOT%\scripts\versions.bat" || exit /b 1
set "MESA=%ROOT%\sources\mesa"
set "LIBVA=%MESA%\subprojects\libva-%LIBVA_VERSION%"
set "DIRECTX_HEADERS=%MESA%\subprojects\DirectX-Headers-1.0"

mkdir "%MESA%" 2>nul
git.exe -C "%MESA%" init || exit /b 1
git.exe -C "%MESA%" remote add origin "%MESA_REPOSITORY%" || exit /b 1
git.exe -C "%MESA%" fetch --depth=1 origin "%MESA_REF%" || exit /b 1
git.exe -C "%MESA%" switch --detach FETCH_HEAD || exit /b 1
call :require_commit "%MESA%" "%MESA_COMMIT%" "Mesa" || exit /b 1

git.exe clone --depth=1 --branch "%LIBVA_VERSION%" "%LIBVA_REPOSITORY%" "%LIBVA%" || exit /b 1
call :require_commit "%LIBVA%" "%LIBVA_COMMIT%" "libva" || exit /b 1

git.exe clone --depth=1 --branch "v%DIRECTX_HEADERS_VERSION%" "%DIRECTX_HEADERS_REPOSITORY%" "%DIRECTX_HEADERS%" || exit /b 1
call :require_commit "%DIRECTX_HEADERS%" "%DIRECTX_HEADERS_COMMIT%" "DirectX-Headers" || exit /b 1

git.exe -C "%MESA%" apply "%ROOT%\patches\windows-va-static-loader.patch" || exit /b 1
echo Fetched and verified libva, Mesa, and DirectX-Headers.
exit /b 0

:require_commit
set "ACTUAL_COMMIT="
for /f "delims=" %%I in ('git.exe -C "%~1" rev-parse HEAD') do set "ACTUAL_COMMIT=%%I"
if /i not "%ACTUAL_COMMIT%"=="%~2" (
    echo %~3 resolved to %ACTUAL_COMMIT%; expected %~2.>&2
    exit /b 1
)
exit /b 0
