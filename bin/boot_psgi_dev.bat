@echo off
setlocal
set BINDIR=%~dp0%
call %BINDIR%/_boot/_boot_psgi.bat -E development