@echo off
REM ============================================================
REM  ACTUALIZA.CMD - Actualiza C:\Llevar desde la carpeta actual
REM  - Copia solo archivos/dir usados en la instalacion
REM  - Solo reemplaza si el origen es mas nuevo
REM  - Usa Robocopy portable + MUI en-US asegurado
REM ============================================================

setlocal EnableExtensions EnableDelayedExpansion
goto :Main

REM ============================================================
REM MOSTRAR RESUMEN
REM ============================================================
:ShowSummary
set "HAS_LINES="
set "DEST_PREFIX=%DEST_DIR%\"

REM Leer log (robocopy puede escribir en Unicode)
for /f "usebackq tokens=1* delims=:" %%A in (`findstr /n "^" "%LOG_FILE%"`) do (
    set "HAS_LINES=1"
    set "LINE=%%B"
    call :TrimLine
    if defined LINE (
        call :EmitLineSegments
    )
)

if not defined HAS_LINES (
    echo [OK] Actualizacion completada. Sin cambios.
)

echo   Log: %LOG_FILE%
exit /b 0

REM ============================================================
REM EMITIR LINEAS (SOPORTA LINEAS CONCATENADAS)
REM ============================================================
:EmitLineSegments
set "REST=!LINE:%SOURCE_DIR%=|%SOURCE_DIR%!"
if "!REST:~0,1!"=="|" set "REST=!REST:~1!"
:EmitLoop
if not defined REST exit /b 0
for /f "tokens=1* delims=|" %%P in ("!REST!") do (
    set "PART=%%P"
    set "REST=%%Q"
)
if defined PART (
    set "PART=!PART:%SOURCE_DIR%=%DEST_PREFIX%!"
    if not defined PRINTED (
        echo [OK] Archivos actualizados:
        set "PRINTED=1"
    )
    echo * !PART!
)
goto :EmitLoop

REM ============================================================
REM TRIM DE LINEA
REM ============================================================
:TrimLine
if not defined LINE exit /b 0
:TrimLoop
set "FIRST=!LINE:~0,1!"
if "%FIRST%"==" " (
    set "LINE=!LINE:~1!"
    goto :TrimLoop
)
if "%FIRST%"=="	" (
    set "LINE=!LINE:~1!"
    goto :TrimLoop
)
exit /b 0

REM ============================================================
REM COPIAR ARCHIVO
REM ============================================================
:CopyFile
set "FILE=%~1"
if exist "%SOURCE_DIR%%FILE%" (
    "%ROBOCOPY%" "%SOURCE_DIR%" "%DEST_DIR%" "%FILE%" %RC_OPTS% /LOG+:"%LOG_FILE%" >nul
    >>"%LOG_FILE%" echo.
    if %errorlevel% GEQ 8 (
        set "HAD_ERROR=1"
        exit /b 1
    )
) else (
    echo [!] No encontrado: %FILE%
    exit /b 1
)
exit /b 0

REM ============================================================
REM COPIAR DIRECTORIO
REM ============================================================
:CopyDir
set "DIR=%~1"
set "DIR_OPTS=%RC_DIR_OPTS%"
if not "%~2"=="" set "DIR_OPTS=%~2"
if exist "%SOURCE_DIR%%DIR%\" (
    "%ROBOCOPY%" "%SOURCE_DIR%%DIR%" "%DEST_DIR%\%DIR%" *.* %DIR_OPTS% /LOG+:"%LOG_FILE%" >nul
    >>"%LOG_FILE%" echo.
    if %errorlevel% GEQ 8 (
        set "HAD_ERROR=1"
        exit /b 1
    )
) else (
    echo [!] No encontrado: %DIR%\
    exit /b 1
)
exit /b 0

REM ============================================================
REM LIMPIAR DIRECTORIO EN DESTINO
REM ============================================================
:CleanDir
set "DIR=%~1"
if exist "%DEST_DIR%\%DIR%\" (
    rd /s /q "%DEST_DIR%\%DIR%" >nul 2>&1
)
exit /b 0

REM ============================================================
REM ASEGURAR ROBOCOPY + MUI (EN-US)
REM ============================================================
:EnsureRobocopy
set "ROBO_DIR=%DEST_DIR%\robocopy"
set "ROBOCOPY=%ROBO_DIR%\robocopy.exe"
set "MUI_LANG=en-US"
set "MUI_SRC=%WINDIR%\System32\%MUI_LANG%\robocopy.exe.mui"
set "MUI_DST=%ROBO_DIR%\%MUI_LANG%"

set "SRC_ROBO_DIR=%SOURCE_DIR%Robocopy"
if not exist "%SRC_ROBO_DIR%\" set "SRC_ROBO_DIR=%SOURCE_DIR%robocopy"

REM Crear carpeta Robocopy
if not exist "%ROBO_DIR%" mkdir "%ROBO_DIR%" >nul 2>&1

REM Copiar Robocopy portable desde el origen si existe
if exist "%SRC_ROBO_DIR%\" (
    if exist "%ROBO_DIR%\" rd /s /q "%ROBO_DIR%" >nul 2>&1
    xcopy "%SRC_ROBO_DIR%" "%ROBO_DIR%\" /E /I /Y >nul
)

REM Copiar robocopy.exe del sistema si falta
if not exist "%ROBOCOPY%" (
    if exist "%WINDIR%\System32\robocopy.exe" (
        copy /b /y "%WINDIR%\System32\robocopy.exe" "%ROBO_DIR%\robocopy.exe" >nul
        set "ROBOCOPY=%ROBO_DIR%\robocopy.exe"
    ) else (
        echo [WARN] robocopy.exe no encontrado en el sistema. Usando robocopy del PATH.
        set "ROBOCOPY=robocopy.exe"
        exit /b 0
    )
)

REM Probar ejecucion; si falla, usar robocopy del sistema
ver >nul
"%ROBOCOPY%" /? 2>nul | findstr /I /C:"ROBOCOPY" >nul
if errorlevel 1 (
    echo [WARN] Robocopy portable fallo en prueba. Usando robocopy del sistema.
    set "ROBOCOPY=robocopy.exe"
)

REM Asegurar MUI si existe en el sistema (sin instalar)
if not exist "%MUI_SRC%" (
    echo [WARN] robocopy.exe.mui en-US no encontrado. Continuando sin forzar idioma.
    exit /b 0
)

if not exist "%MUI_DST%" mkdir "%MUI_DST%" >nul 2>&1
copy /b /y "%MUI_SRC%" "%MUI_DST%\robocopy.exe.mui" >nul

exit /b 0

REM ============================================================
REM MAIN
REM ============================================================
:Main
set "SOURCE_DIR=%~dp0"
set "DEST_DIR=C:\Llevar"

if not exist "%DEST_DIR%\" (
    echo [ERROR] No existe C:\Llevar. Instale primero Llevar.
    pause
    exit /b 1
)

for /f "tokens=2 delims==" %%i in (
  'wmic os get LocalDateTime /value ^| find "="'
) do set "TS=%%i"
set "TS=%TS:~0,14%"
set "LOG_FILE=%TEMP%\LLEVAR_Actualiza_%TS%.log"

set "RC_OPTS=/XO /R:1 /W:1 /NP /FP /NDL /NJH /NJS /NS /NC /XD .git .vscode .cursor"
set "RC_DIR_OPTS=%RC_OPTS% /E"
set "HAD_ERROR=0"

REM === Asegurar Robocopy ===
call :EnsureRobocopy
if errorlevel 1 (
    echo [FATAL] Actualizacion cancelada
    pause
    exit /b 1
)

REM === Copias ===
call :CopyFile "Llevar.ps1"
if errorlevel 1 goto :Fail
call :CopyFile "LLEVAR.CMD"
if errorlevel 1 goto :Fail
call :CopyFile "DESINSTALAR.CMD"
if errorlevel 1 goto :Fail
call :CopyFile "Llevar.inf"
if errorlevel 1 goto :Fail
call :CopyFile "7za.exe"
if errorlevel 1 goto :Fail

call :CopyDir "Modules"
if errorlevel 1 goto :Fail
call :CopyDir "Data"
if errorlevel 1 goto :Fail
call :CopyDir "Scripts" "%RC_DIR_OPTS% /XF Update-GitHubWiki.ps1 Publish-DocsToWiki.ps1"
if errorlevel 1 goto :Fail
set "ROBO_SRC_DIR="
if exist "%SOURCE_DIR%Robocopy\" set "ROBO_SRC_DIR=Robocopy"
if not defined ROBO_SRC_DIR if exist "%SOURCE_DIR%robocopy\" set "ROBO_SRC_DIR=robocopy"
if defined ROBO_SRC_DIR (
    call :CopyDir "%ROBO_SRC_DIR%"
    if errorlevel 1 goto :Fail
) else (
    echo [WARN] No se encontró carpeta Robocopy/robocopy en el origen.
)
call :CleanDir ".git"
call :CleanDir ".vscode"
call :CleanDir ".cursor"

if not exist "%DEST_DIR%\Logs\" mkdir "%DEST_DIR%\Logs" >nul 2>&1

if "%HAD_ERROR%"=="1" goto :Fail

if exist "%LOG_FILE%" (
    call :ShowSummary
) else (
    echo [OK] Actualizacion completada
)

pause
exit /b 0

:Fail
echo [ERROR] Actualizacion abortada por error.
pause
exit /b 1
