@echo off
setlocal
set BINDIR=%~dp0%
perl %* %BINDIR%\boot_scripts\testontap-web.pl
