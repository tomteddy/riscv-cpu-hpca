@echo off
REM ============================================================
REM build.bat : compile a bare-metal C test into two hex files.
REM
REM Usage (from project root):
REM     tools\build.bat tests\smoke_add.c
REM
REM Produces (next to the .c file):
REM     <name>.elf             - linked ELF
REM     <name>.instructions.hex - IMEM init ($readmemh)
REM     <name>.data.hex         - DMEM init ($readmemh)
REM     <name>.dis              - disassembly (for debugging)
REM
REM After building, copy or point Vivado sim at the .hex files
REM as "instructions.hex" and "data.hex" in the sim working dir.
REM ============================================================

setlocal
set TOOLCHAIN=C:\riscv\riscv\riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-w64-mingw32\bin
set GCC=%TOOLCHAIN%\riscv64-unknown-elf-gcc.exe
set OBJCOPY=%TOOLCHAIN%\riscv64-unknown-elf-objcopy.exe
set OBJDUMP=%TOOLCHAIN%\riscv64-unknown-elf-objdump.exe

set CFLAGS=-march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -Os -Wall -ffreestanding -fno-builtin
set CUSTOM_OPS=%~dp0custom_ops.S

if "%~1"=="" (
    echo Usage: tools\build.bat ^<source.c^>
    exit /b 1
)

set SRC=%~1
set BASE=%~dpn1
set LINKER=%~dp0link.ld
set STARTUP=%~dp0startup.S

echo [1/4] Compiling %SRC% ...
"%GCC%" %CFLAGS% -T "%LINKER%" "%STARTUP%" "%CUSTOM_OPS%" "%SRC%" -o "%BASE%.elf"
if errorlevel 1 goto :error

echo [2/4] Extracting instruction memory -^> %BASE%.instructions.hex ...
"%OBJCOPY%" -O verilog --only-section=.text "%BASE%.elf" "%BASE%.instructions.hex"
if errorlevel 1 goto :error

echo [3/4] Extracting data memory -^> %BASE%.data.hex ...
REM --change-addresses -65536 strips the 0x10000 LMA offset added by link.ld
REM so that $readmemh sees byte addresses starting from 0 (dmem.mem[0]).
@REM "%OBJCOPY%" -O verilog --only-section=.rodata --only-section=.data --only-section=.sdata --change-addresses -65536 "%BASE%.elf" "%BASE%.data.hex"
"%OBJCOPY%" -O verilog --only-section=.rodata --only-section=.data --only-section=.sdata "%BASE%.elf" "%BASE%.data.hex"
if errorlevel 1 goto :error

echo [4/4] Disassembling -^> %BASE%.dis ...
"%OBJDUMP%" -d "%BASE%.elf" > "%BASE%.dis"
if errorlevel 1 goto :error

echo.
echo BUILD OK.
echo   %BASE%.instructions.hex
echo   %BASE%.data.hex
echo   %BASE%.dis
endlocal
exit /b 0

:error
echo.
echo BUILD FAILED.
endlocal
exit /b 1
