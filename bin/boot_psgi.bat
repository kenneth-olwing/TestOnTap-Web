@echo off
setlocal
set BINDIR=%~dp0%
plackup %* -I %BINDIR%\..\lib -I %BINDIR%\..\local\lib\perl5 %BINDIR%\boot_scripts\testontap-web.psgi
