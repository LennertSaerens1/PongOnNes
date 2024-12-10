@echo off

REM Create the build directory if it doesn't exist
if not exist build mkdir build

REM Remove old build files
@del build/%1.o
@del build/%1.nes
@del build/%1.map.txt
@del build/%1.labels.txt
@del build/%1.nes.ram.nl
@del build/%1.nes.0.nl
@del build/%1.nes.1.nl
@del build/%1.nes.dbg

@echo.
@echo Compiling...
\cc65\bin\ca65 src\%1.s -g -o build/%1.o
@IF ERRORLEVEL 1 GOTO failure

@echo.
@echo Linking...
\cc65\bin\ld65 -o build/%1.nes -C config/%1.cfg build/%1.o -m build/%1.map.txt -Ln build/%1.labels.txt --dbgfile build/%1.nes.dbg
@IF ERRORLEVEL 1 GOTO failure

@echo.
@echo Success!
@GOTO endbuild

:failure
@echo.
@echo Build error!
:endbuild