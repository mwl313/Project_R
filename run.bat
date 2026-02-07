@echo off
title ProjectR
setlocal

set "LOVE_EXE=C:\Program Files\LOVE\love.exe"
set "GAME_DIR=%~dp0"

rem 끝에 붙는 \ 제거 (가끔 파싱 꼬임 방지)
if "%GAME_DIR:~-1%"=="\" set "GAME_DIR=%GAME_DIR:~0,-1%"

"%LOVE_EXE%" "%GAME_DIR%"
