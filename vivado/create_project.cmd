@echo off
REM SPDX-License-Identifier: MIT
REM Build ONE Vivado .xpr with both FPGA tops; open it only after validation.
setlocal
pushd "%~dp0.." || exit /b 1
set "XPR=%CD%\build\v\EthAB\EthAB.xpr"
set "MARKER=%CD%\build\v\project_ok.txt"
if defined VIVADO_BIN (
  set "VIVADO_EXE=%VIVADO_BIN%"
) else (
  where vivado.bat >nul 2>&1
  if not errorlevel 1 set "VIVADO_EXE=vivado.bat"
  if not defined VIVADO_EXE if exist "C:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat" set "VIVADO_EXE=C:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat"
)
if not defined VIVADO_EXE (
  echo ERROR: Vivado not found. Open a Vivado command prompt or set VIVADO_BIN.
  goto :fail
)
REM Remove any prior success token so a failed run can never be reported as PASS.
if exist "%MARKER%" del /q "%MARKER%"
echo Creating and verifying the single Vivado project...
call "%VIVADO_EXE%" -mode batch -source vivado/create_project.tcl
if errorlevel 1 (
  echo ERROR: Vivado project generator reported a failure.
  goto :fail
)
if not exist "%MARKER%" (
  echo ERROR: Vivado did not finish XPR reopen verification; inspect messages above.
  goto :fail
)
if not exist "%XPR%" (
  echo ERROR: Project file does not exist: %XPR%
  goto :fail
)
echo.
echo SUCCESS: Vivado project created and validated:
echo %XPR%
echo Opening Vivado GUI with the project...
REM Vivado on Windows is a .bat wrapper. CALL avoids START command parsing
REM failures ("filename, directory name, or volume label syntax incorrect").
REM The console remains attached to Vivado until the GUI is closed.
call "%VIVADO_EXE%" -mode gui "%XPR%"
if errorlevel 1 (
  echo NOTE: Automatic GUI launch exited unsuccessfully. Open the XPR directly in Vivado.
)
popd
pause
exit /b 0

:fail
echo No valid project creation is claimed. Fix the ERROR above before continuing.
popd
pause
exit /b 1
