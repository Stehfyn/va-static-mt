@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
call "%ROOT%\scripts\versions.bat" || exit /b 1
set "MESA=%ROOT%\sources\mesa"
set "LIBVA=%MESA%\subprojects\libva-%LIBVA_VERSION%"
set "DIRECTX_HEADERS=%MESA%\subprojects\DirectX-Headers-1.0"
set "BUILD=%ROOT%\build\vaon12"
set "RAW_INSTALL=%ROOT%\build\install"
set "INSTALLED=%ROOT%\installed"

meson.exe setup "%BUILD%" "%MESA%" --backend=ninja ^
    --prefix="%RAW_INSTALL%" --default-library=static ^
    --buildtype=debugoptimized --wrap-mode=nodownload ^
    -Db_vscrt=mt -Dc_args=/Z7 -Dcpp_args=/Z7 ^
    -Dauto_features=disabled -Dallow-fallback-for=libva ^
    -Dplatforms=windows -Dgallium-drivers=d3d12 ^
    -Dgallium-va=enabled -Dgallium-d3d12-video=enabled ^
    -Dgallium-d3d12-graphics=disabled -Dvideo-codecs=h264enc ^
    -Dvulkan-drivers= -Dllvm=disabled -Dopengl=false ^
    -Degl=disabled -Dgles1=disabled -Dgles2=disabled ^
    -Dgbm=disabled -Dglx=disabled -Dzlib=disabled -Dzstd=disabled ^
    -Dbuild-tests=false
if errorlevel 1 exit /b 1
meson.exe compile -C "%BUILD%" || exit /b 1
meson.exe install -C "%BUILD%" || exit /b 1

mkdir "%INSTALLED%\include\va" "%INSTALLED%\lib" "%INSTALLED%\bin" "%INSTALLED%\licenses" 2>nul
xcopy "%RAW_INSTALL%\include\va\*" "%INSTALLED%\include\va\" /E /I /Y >nul || exit /b 1
copy /y "%RAW_INSTALL%\lib\libva.a" "%INSTALLED%\lib\va.lib" >nul || exit /b 1
copy /y "%RAW_INSTALL%\lib\libva_win32.a" "%INSTALLED%\lib\va_win32.lib" >nul || exit /b 1
copy /y "%RAW_INSTALL%\bin\vaon12_drv_video.dll" "%INSTALLED%\bin\" >nul || exit /b 1
copy /y "%RAW_INSTALL%\bin\vaon12_drv_video.pdb" "%INSTALLED%\bin\" >nul || exit /b 1
copy /y "%LIBVA%\COPYING" "%INSTALLED%\licenses\libva-COPYING" >nul || exit /b 1
copy /y "%DIRECTX_HEADERS%\LICENSE" "%INSTALLED%\licenses\DirectX-Headers-LICENSE" >nul || exit /b 1
(
    echo libva %LIBVA_VERSION% %LIBVA_COMMIT%
    echo Mesa %MESA_VERSION% %MESA_COMMIT%
    echo DirectX-Headers %DIRECTX_HEADERS_VERSION% %DIRECTX_HEADERS_COMMIT%
    echo WinFlexBison %WINFLEXBISON_VERSION% sha256:%WINFLEXBISON_SHA256%
) > "%INSTALLED%\SOURCES.txt"
exit /b 0
