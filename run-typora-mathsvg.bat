@echo off
setlocal EnableExtensions

set "INPUT=%~1"
set "OUTPUT=%~2"

set "FILTER=D:\Projects\pandoc_docx_template\lua\math-to-svg-md.lua"
set "BUILD=D:\Projects\pandoc_docx_template\.math-svg-build"

set "OUTDIR=%~dp2"
set "SVGDIR=%OUTDIR%math-svg"

if exist "%BUILD%" rmdir /S /Q "%BUILD%"
mkdir "%BUILD%" 2>nul

pandoc "%INPUT%" -f markdown+tex_math_dollars+tex_math_single_backslash+latex_macros --lua-filter="%FILTER%" -t gfm --wrap=none -o "%OUTPUT%"

if errorlevel 1 (
  echo.
  echo [ERROR] Pandoc failed. Build directory kept:
  echo %BUILD%
  exit /b 1
)

if not exist "%SVGDIR%" mkdir "%SVGDIR%"

if exist "%BUILD%\*.svg" (
  copy /Y "%BUILD%\*.svg" "%SVGDIR%\" >nul
) else (
  echo.
  echo [ERROR] No SVG files were generated in:
  echo %BUILD%
  echo.
  echo Check whether Pandoc recognized the formulas as math nodes.
  exit /b 2
)

rmdir /S /Q "%BUILD%"

exit /b 0