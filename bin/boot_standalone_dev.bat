@echo off
setlocal
set DANCER_ENVIRONMENT=development
set BINDIR=%~dp0%
call %BINDIR%/_boot/_boot_standalone.bat