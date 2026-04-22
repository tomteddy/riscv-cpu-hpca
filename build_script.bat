@echo off
setlocal enabledelayedexpansion

REM Check if parameter is provided
if "%~1"=="" (
    echo Usage: %0 path\filename.c
    echo Example: %0 tests\matmul_8x8.c
    exit /b 1
)

REM Extract directory and filename without extension
for %%A in ("%~1") do (
    set "filename=%%~nA"
    set "inputdir=%%~dpA"
)

REM Run build.bat with the input file
call tools\build.bat %~1

REM Copy hex files using the extracted filename
copy "%inputdir%%filename%.instructions.hex" ..\..\..\instr\instructions.hex
copy "%inputdir%%filename%.data.hex" ..\..\..\instr\data.hex

echo.
echo Build and copy complete for %filename%