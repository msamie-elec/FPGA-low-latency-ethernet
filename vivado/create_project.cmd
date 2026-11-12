@echo off
REM SPDX-License-Identifier: MIT
REM Create ONE Vivado GUI .xpr containing BOTH independent FPGA designs.
setlocal
pushd "%~dp0.." || exit /b 1
if defined VIVADO_BIN (
  set "VIVADO_EXE=%VIVADO_BIN%"
) else (
  where vivado.bat >nul 2>&1
  if not errorlevel 1 set "VIVADO_EXE=vivado.bat"
  if not defined VIVADO_EXE if exist "C:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat" set "VIVADO_EXE=C:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat"
)
if not defined VIVADO_EXE (
  echo ERROR: Vivado not found. Use a Vivado command prompt or set VIVADO_BIN.
  popd
  pause
  exit /b 1
)
call "%VIVADO_EXE%" -mode batch -source vivado/create_project.tcl
set "RESULT=%ERRORLEVEL%"
if "%RESULT%"=="0" (
  echo.
  echo Open this ONE Vivado GUI project:
  echo build\vivado_gui\FPGA_Low_Latency_Ethernet\FPGA_Low_Latency_Ethernet.xpr
)
popd
pause
exit /b %RESULT%
