@echo off
REM SPDX-License-Identifier: MIT
REM Double-click to create BOTH source-managed Vivado GUI .xpr projects.
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
call "%VIVADO_EXE%" -mode batch -source vivado/create_gui_projects.tcl -tclargs both
set "RESULT=%ERRORLEVEL%"
if "%RESULT%"=="0" (
  echo.
  echo Open: build\vivado_gui\board_a_generator\board_a_generator.xpr
  echo Open: build\vivado_gui\board_b_endpoint\board_b_endpoint.xpr
)
popd
pause
exit /b %RESULT%
