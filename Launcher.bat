@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0v2.2d.ps1""' -Verb RunAs"
