@echo off

setlocal EnableDelayedExpansion

set NAME=game
set EXE=bin\%NAME%.exe
set PDB=bin\%NAME%.pdb

for %%s in ("*.glsl.*") do (
	call :compile_shader %%s
	if !errorlevel! neq 0 exit /b 1
)

odin build src -debug -out:%EXE% -pdb-name:%PDB% -linker:radlink
if %ERRORLEVEL% neq 0 exit /b 1

if "%~1"=="run" (
	%EXE%
)

exit /b 0

:compile_shader
	set infile=%~1
	set outfile=%infile:.glsl=.spv%
	glslc %infile% -o %outfile% -O -g
	exit /b %errorlevel%