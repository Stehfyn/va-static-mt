# libva static MSVC runtime build

This repository builds the Windows libva client libraries statically with the
MSVC `/MT` runtime and builds Mesa's VA-on-12 driver as the single required
runtime DLL. Sources are reproducibly pinned in `scripts/versions.bat`; Python
build tools and their complete Python dependency closure are version- and
artifact-pinned in `scripts/python-requirements.lock`.

## Prerequisites

- Visual Studio with the C++ workload and a Windows SDK
- Vulkan SDK 1.4.335.0, with `VULKAN_SDK` set by its installer
- Git, curl, tar, certutil, and the Python 3.12 launcher on `PATH`
- Network access to the official source repositories on each clean build

No other caller-defined build variables are read. The build discovers Visual
Studio through `vswhere`, initializes the x64 compiler environment, and checks
every prerequisite before fetching sources.

## Build

Run from a normal Command Prompt:

```bat
build.bat
```

`build-libva.bat` is an equivalent compatibility entry point. Like the
`ffmpeg-static-mt` build, each invocation recreates `sources`, `build`, and
`installed` while retaining downloaded/bootstrap tools under `external`.

The consumable package is written to `installed`:

- `include\va`: libva headers
- `lib\va.lib` and `lib\va_win32.lib`: static libraries using `/MT`; `/Z7`
  embeds debug information in their object files
- `bin\vaon12_drv_video.dll` and `bin\vaon12_drv_video.pdb`: Mesa's VA-on-12
  runtime driver and matching symbols

The driver build contains D3D12 VA H.264 encoding only. OpenGL, EGL, GLES, GBM,
GLX, LLVM, Vulkan drivers, zlib, zstd, tests, and unrelated Gallium drivers are
disabled. Verification rejects non-static CRT directives, missing symbols, or
any driver import outside the four expected Windows system DLLs.

The libva patch passes only `vaon12_drv_video.dll` to `LoadLibrary`. A consuming
application can place the DLL beside its executable; it does not need
`LIBVA_DRIVERS_PATH`, a hard-coded driver directory, or a particular working
directory.
