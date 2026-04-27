@echo off
REM ============================================================
REM build_all.bat : build every Phase 4 benchmark.
REM Run from project root:  tools\build_all.bat
REM ============================================================
setlocal
set BUILD=%~dp0build.bat
set TESTS=%~dp0..\tests

for %%B in (
    fib_20
    dotprod_16
    dotprod_16_nocustom
    matmul_8x8
    matmul_8x8_nocustom
    relu_32
    relu_32_nocustom
    grad_descent
    grad_descent_nocustom
) do (
    echo ============================================================
    echo Building %%B
    echo ============================================================
    call "%BUILD%" "%TESTS%\%%B.c"
    if errorlevel 1 (
        echo BUILD FAILED for %%B
        endlocal
        exit /b 1
    )
)
echo.
echo ALL BUILDS OK.
endlocal
exit /b 0
