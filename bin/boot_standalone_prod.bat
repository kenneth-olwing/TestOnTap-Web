@echo off
setlocal
set DANCER_ENVIRONMENT=production
set BINDIR=%~dp0%
call %BINDIR%/_boot/_boot_standalone.bat