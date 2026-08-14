@echo off
REM Bugaoshan release pre-check wrapper.
REM Usage: _release_check.bat 2.3.0
python "%~dp0tool\pre_release_check.py" %*
