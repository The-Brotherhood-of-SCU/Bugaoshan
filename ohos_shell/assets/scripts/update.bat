@echo off
timeout /t 3 /nobreak >nul
xcopy /s /y "%~dp0*" "{EXE_DIR}" >nul 2>&1
start "" "{EXE_PATH}"
ping localhost -n 2 >nul
del "%~f0"