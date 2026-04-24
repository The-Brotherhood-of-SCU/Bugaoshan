@echo off
timeout /t 2 /nobreak >nul
xcopy /s /y "%~dp0*" "{EXE_DIR}"
start "" "{EXE_PATH}"
del "%~f0"
