@echo off
REM ============================================================
REM run_all.bat : headless Vivado sweep of all benchmarks × configs.
REM
REM Prerequisites:
REM   1. tools\build_all.bat   (builds all 9 benchmarks)
REM   2. Vivado on PATH        (or edit VIVADO= below)
REM
REM Run from project root:  tools\run_all.bat
REM Output: <project>.sim\sim_1\behav\xsim\results.csv
REM ============================================================
setlocal
set VIVADO=C:\Xilinx\Vivado\2020.2\bin\vivado.bat
set PROJ=hpca_riscv.xpr
set TCL=%~dp0run_all.tcl

if not exist "%PROJ%" (
    echo ERROR: %PROJ% not found in current directory.
    echo Run this script from the project root.
    exit /b 1
)

%VIVADO% -mode batch -source "%TCL%" "%PROJ%"
endlocal
