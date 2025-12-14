@echo off
REM ============================================================
REM  LLEVAR.CMD - Launcher inteligente para Llevar.ps1
REM  - Verifica y requiere PowerShell 7+
REM  - Elevación de permisos CONDICIONAL (solo cuando se necesita)
REM  - Habilita ExecutionPolicy si es necesario
REM  - Soporta arrastrar carpetas/archivos al icono
REM ============================================================

setlocal EnableDelayedExpansion

REM ============================================================
REM OBTENER LA RUTA DEL SCRIPT POWERSHELL
REM ============================================================

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%Llevar.ps1"

REM Verificar que existe el script
if not exist "%PS_SCRIPT%" (
    powershell -NoProfile -Command "& {Add-Type -AssemblyName PresentationFramework;[System.Windows.MessageBox]::Show('No se encuentra Llevar.ps1 en: %SCRIPT_DIR%', 'Error - Llevar', 'OK', 'Error')}" 2>nul
    exit /b 1
)

REM ============================================================
REM VERIFICAR POWERSHELL 7+
REM ============================================================

REM Usar PowerShell para detectar pwsh.exe
for /f "delims=" %%i in ('powershell -NoProfile -Command "(Get-Command pwsh -ErrorAction SilentlyContinue).Source" 2^>nul') do set "PWSH_EXE=%%i"

REM Si se encontró, verificar que sea válido
if defined PWSH_EXE (
    if exist "%PWSH_EXE%" (
        goto :FoundPwsh
    )
)

REM Fallback: Buscar en ubicaciones comunes
set "PWSH_EXE="

REM Buscar en PATH con where
for /f "delims=" %%i in ('where pwsh.exe 2^>nul') do (
    set "PWSH_EXE=%%i"
    goto :FoundPwsh
)

REM Buscar en Program Files (cualquier versión 7+)
for /d %%i in ("%ProgramFiles%\PowerShell\*") do (
    if exist "%%i\pwsh.exe" (
        set "PWSH_EXE=%%i\pwsh.exe"
        goto :FoundPwsh
    )
)

REM Buscar en WindowsApps (Microsoft Store / Winget)
if exist "%LocalAppData%\Microsoft\WindowsApps\pwsh.exe" (
    set "PWSH_EXE=%LocalAppData%\Microsoft\WindowsApps\pwsh.exe"
    goto :FoundPwsh
)

REM No se encontró PowerShell 7+
powershell -NoProfile -Command "& {Add-Type -AssemblyName PresentationFramework;[System.Windows.MessageBox]::Show('LLEVAR requiere PowerShell 7 o superior.`n`nPowerShell 5 no es compatible con este script.`n`nPor favor ejecute INSTALAR.CMD para instalar PowerShell 7 automaticamente.', 'Error - PowerShell 7 Requerido', 'OK', 'Error')}" 2>nul

exit /b 1

:FoundPwsh

REM ============================================================
REM VERIFICAR Y HABILITAR EXECUTIONPOLICY (silenciosamente)
REM ============================================================

REM Verificar política actual
for /f "delims=" %%i in ('"%PWSH_EXE%" -NoProfile -Command "Get-ExecutionPolicy -Scope LocalMachine" 2^>nul') do set "CURRENT_POLICY=%%i"

REM Si es Restricted o Undefined, habilitar RemoteSigned
if /i "%CURRENT_POLICY%"=="Restricted" goto :EnablePolicy
if /i "%CURRENT_POLICY%"=="Undefined" goto :EnablePolicy
goto :PolicyOK

:EnablePolicy
"%PWSH_EXE%" -NoProfile -Command "try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force } catch { exit 1 }" >nul 2>&1

if !ERRORLEVEL! neq 0 (
    powershell -NoProfile -Command "& {Add-Type -AssemblyName PresentationFramework;[System.Windows.MessageBox]::Show('No se pudo habilitar la ejecución de scripts de PowerShell.`n`nPor favor ejecute manualmente:`nSet-ExecutionPolicy RemoteSigned -Scope LocalMachine', 'Error - ExecutionPolicy', 'OK', 'Error')}" 2>nul
    exit /b 1
)

:PolicyOK

REM ============================================================
REM PROCESAR ARGUMENTOS
REM ============================================================

set "FIRST_ARG=%~1"
set "SCRIPT_ARGS="

if exist "%FIRST_ARG%" (
    REM El primer argumento es un archivo o carpeta válido - usarlo como origen
    set "SCRIPT_ARGS=-Origen ""%FIRST_ARG%"""
    
    REM Agregar el resto de argumentos (si los hay)
    shift
    :ArgLoop
    if "%~1"=="" goto ArgEnd
    set "SCRIPT_ARGS=!SCRIPT_ARGS! %1"
    shift
    goto ArgLoop
    :ArgEnd
) else (
    REM No se detectó archivo/carpeta como primer arg - pasar todos los argumentos tal cual
    set "SCRIPT_ARGS=%*"
)

REM ============================================================
REM EJECUTAR LLEVAR.PS1 CON POWERSHELL 7
REM ============================================================

REM Si hay argumentos (ejecutado desde menú contextual o arrastrando archivos),
REM usar -NoExit para mantener la ventana abierta durante la interacción
if "%~1" neq "" (
    "%PWSH_EXE%" -NoExit -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" !SCRIPT_ARGS!
) else (
    "%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" !SCRIPT_ARGS!
)

exit /b !ERRORLEVEL!
