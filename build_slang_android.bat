@echo off
setlocal

:: Configuration
set "VS_PATH=C:\Program Files\Microsoft Visual Studio\18\Community"
set "VCVARS=%VS_PATH%\VC\Auxiliary\Build\vcvars64.bat"
set "NDK_PATH=%~dp0..\Tools\android-ndk-r27d"
set "SLANG_ROOT=%~dp0"
set "DEST_DIR=%~dp0..\HereticalEngineAndroid\app\src\main\jniLibs\arm64-v8a"

echo [INFO] Initializing Visual Studio 2026 Environment...
if not exist "%VCVARS%" (
    echo [ERROR] Could not find vcvars64.bat at "%VCVARS%"
    pause
    exit /b 1
)

:: Step 1: Build Generators for Host (Windows x64)
echo [INFO] Step 1: Building Slang Generators for Host...
call "%VCVARS%"
cd /d "%SLANG_ROOT%"

if not exist "build-generators" mkdir build-generators
cmake -B build-generators -G "Ninja" ^
    -DSLANG_SLANG_LLVM_FLAVOR=DISABLE ^
    -DSLANG_ENABLE_SLANG_RHI=FALSE ^
    -DSLANG_ENABLE_TESTS=FALSE ^
    -DCMAKE_BUILD_TYPE=Release

cmake --build build-generators --config Release --target all-generators

if %errorlevel% neq 0 (
    echo [ERROR] Host generator build failed.
    pause
    exit /b 1
)

:: Step 2: Cross-compile for Android (ARM64)
echo [INFO] Step 2: Cross-compiling Slang for Android (ARM64)...

if not exist "build-android" mkdir build-android
cmake -B build-android -G "Ninja" ^
    -DCMAKE_TOOLCHAIN_FILE="%NDK_PATH%\build\cmake\android.toolchain.cmake" ^
    -DANDROID_ABI=arm64-v8a ^
    -DANDROID_PLATFORM=android-29 ^
    -DSLANG_GENERATORS_PATH="build-generators/generators/Release/bin" ^
    -DSLANG_SLANG_LLVM_FLAVOR=DISABLE ^
    -DSLANG_ENABLE_SLANG_RHI=FALSE ^
    -DSLANG_ENABLE_TESTS=FALSE ^
    -DCMAKE_BUILD_TYPE=Release

:: We ignore the symlink error at the end
cmake --build build-android --config Release

if exist "build-android\Release\lib\libslang-compiler.so" (
    echo [SUCCESS] libslang-compiler.so built successfully!
    echo [INFO] Copying artifacts to HereticalEngineAndroid...
    
    if not exist "%DEST_DIR%" mkdir "%DEST_DIR%"
    
    :: Copy and rename to libslang.so for compatibility with existing P/Invokes
    copy /Y "build-android\Release\lib\libslang-compiler.so" "%DEST_DIR%\libslang.so"
    
    :: Copy standard modules
    for /d %%D in (build-android\Release\lib\slang-standard-module-*) do (
        echo [INFO] Copying standard module: %%D
        xcopy /E /I /Y "%%D" "%DEST_DIR%\%%~nxD"
    )
    
    echo [SUCCESS] Artifacts copied to "%DEST_DIR%"
) else (
    echo [ERROR] Android build failed to produce library.
    pause
    exit /b 1
)

pause
