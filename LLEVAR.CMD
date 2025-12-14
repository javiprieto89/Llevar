@echo off
REM ============================================================
REM  LLEVAR.CMD - Launcher inteligente con auto-elevación
REM  - Verifica y requiere PowerShell 7+
REM  - Eleva permisos automáticamente
REM  - Habilita ExecutionPolicy si es necesario
REM  - Soporta arrastrar carpetas/archivos al icono
REM ============================================================

setlocal EnableDelayedExpansion

REM ============================================================
REM VERIFICAR SI YA ESTÁ EJECUTÁNDOSE COMO ADMINISTRADOR
REM ============================================================

net session >nul 2>&1
if %errorLevel% == 0 (
    REM Ya es administrador, continuar con la ejecución
    goto :IsAdmin
)

REM ============================================================
REM NO ES ADMINISTRADOR - INTENTAR ELEVAR PERMISOS
REM ============================================================

echo Elevando permisos de administrador...

REM Guardar argumentos para pasarlos al proceso elevado
set "ARGS=%*"

REM Re-ejecutar este script con permisos de administrador
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%ARGS%' -Verb RunAs" 2>nul

REM Verificar si la elevación fue exitosa
if %errorLevel% neq 0 (
    REM El usuario canceló o hubo error
    powershell -NoProfile -Command "& {Add-Type -AssemblyName PresentationFramework;[System.Windows.MessageBox]::Show('LLEVAR requiere permisos de administrador.`n`nLa operación fue cancelada.`n`nNo se puede continuar sin permisos de administrador.', 'Permisos de Administrador Requeridos', 'OK', 'Warning')}" 2>nul
    exit /b 1
)

REM Si llegó aquí, se lanzó el proceso elevado correctamente
exit /b 0

:IsAdmin
REM ============================================================
REM EJECUTÁNDOSE COMO ADMINISTRADOR
REM ============================================================

REM Obtener la ruta del script PowerShell
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

REM Buscar pwsh.exe (PowerShell 7+) en ubicaciones comunes
set "PWSH_EXE="

REM Primero buscar en PATH
where pwsh.exe >nul 2>&1
if !ERRORLEVEL! equ 0 (
    set "PWSH_EXE=pwsh.exe"
    goto :FoundPwsh
)

REM Buscar en Program Files
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set "PWSH_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe"
    goto :FoundPwsh
)

REM Buscar en Program Files (x86)
if exist "%ProgramFiles(x86)%\PowerShell\7\pwsh.exe" (
    set "PWSH_EXE=%ProgramFiles(x86)%\PowerShell\7\pwsh.exe"
    goto :FoundPwsh
)

REM No se encontró PowerShell 7+
powershell -NoProfile -Command "& {Add-Type -AssemblyName PresentationFramework;[System.Windows.MessageBox]::Show('LLEVAR requiere PowerShell 7 o superior.`n`nPowerShell 5 no es compatible con este script.`n`nPor favor descargue PowerShell 7+ desde:`nhttps://aka.ms/powershell-release?tag=stable', 'Error - PowerShell 7 Requerido', 'OK', 'Error')}" 2>nul

REM Intentar abrir el navegador con el link de descarga
start https://aka.ms/powershell-release?tag=stable 2>nul

exit /b 1

:FoundPwsh

REM ============================================================
REM VERIFICAR Y HABILITAR EXECUTIONPOLICY
REM ============================================================

echo Verificando ExecutionPolicy...

REM Verificar política actual
for /f "delims=" %%i in ('"%PWSH_EXE%" -NoProfile -Command "Get-ExecutionPolicy -Scope LocalMachine"') do set "CURRENT_POLICY=%%i"

REM Si es Restricted o Undefined, habilitar RemoteSigned
if /i "%CURRENT_POLICY%"=="Restricted" goto :EnablePolicy
if /i "%CURRENT_POLICY%"=="Undefined" goto :EnablePolicy
goto :PolicyOK

:EnablePolicy
echo Habilitando ejecucion de scripts de PowerShell...
"%PWSH_EXE%" -NoProfile -Command "try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force; Write-Host 'ExecutionPolicy configurado correctamente' -ForegroundColor Green } catch { Write-Host 'Error al configurar ExecutionPolicy:' $_.Exception.Message -ForegroundColor Red; exit 1 }"

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

echo Ejecutando Llevar.ps1...
echo.

"%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" !SCRIPT_ARGS!

exit /b !ERRORLEVEL!
