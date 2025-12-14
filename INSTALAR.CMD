@echo off
REM ============================================================
REM  INSTALAR.CMD - Instalador de Llevar con auto-elevación
REM  - No requiere ExecutionPolicy configurado previamente
REM  - Eleva permisos automáticamente
REM  - Habilita ExecutionPolicy si es necesario
REM  - Ejecuta Llevar.ps1 -Instalar
REM ============================================================

setlocal EnableDelayedExpansion

echo.
echo ================================================================
echo   INSTALADOR DE LLEVAR - Sistema de Transferencia de Archivos
echo ================================================================
echo.

REM ============================================================
REM VERIFICAR SI YA ESTÁ EJECUTÁNDOSE COMO ADMINISTRADOR
REM ============================================================

net session >nul 2>&1
if %errorLevel% == 0 (
    REM Ya es administrador, continuar con la instalación
    goto :IsAdmin
)

REM ============================================================
REM NO ES ADMINISTRADOR - INTENTAR ELEVAR PERMISOS
REM ============================================================

echo [*] Elevando permisos de administrador...
echo.

REM Re-ejecutar este script con permisos de administrador
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" 2>nul

REM Verificar si la elevación fue exitosa
if %errorLevel% neq 0 (
    REM El usuario canceló o hubo error
    echo.
    echo ================================================================
    echo   ERROR: Se requieren permisos de administrador
    echo ================================================================
    echo.
    echo La instalacion de Llevar requiere permisos de administrador.
    echo.
    echo La operacion fue cancelada por el usuario.
    echo.
    echo Por favor ejecute este script como administrador.
    echo.
    pause
    exit /b 1
)

REM Si llegó aquí, se lanzó el proceso elevado correctamente
exit /b 0

:IsAdmin
REM ============================================================
REM EJECUTÁNDOSE COMO ADMINISTRADOR
REM ============================================================

echo [OK] Ejecutando como administrador
echo.

REM Obtener la ruta del script PowerShell
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%Llevar.ps1"

REM Verificar que existe el script
if not exist "%PS_SCRIPT%" (
    echo.
    echo ================================================================
    echo   ERROR: No se encuentra Llevar.ps1
    echo ================================================================
    echo.
    echo No se encuentra el archivo: %PS_SCRIPT%
    echo.
    echo Asegurese de ejecutar INSTALAR.CMD desde la carpeta de Llevar.
    echo.
    pause
    exit /b 1
)

echo [OK] Script encontrado: Llevar.ps1
echo.

REM ============================================================
REM VERIFICAR POWERSHELL 7+
REM ============================================================

echo [*] Verificando PowerShell 7+...

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

REM Versiones más recientes en AppData Local
if exist "%LocalAppData%\Microsoft\PowerShell\7\pwsh.exe" (
    set "PWSH_EXE=%LocalAppData%\Microsoft\PowerShell\7\pwsh.exe"
    goto :FoundPwsh
)

REM No se encontró PowerShell 7+
echo.
echo ================================================================
echo   ERROR: PowerShell 7 o superior no encontrado
echo ================================================================
echo.
echo LLEVAR requiere PowerShell 7 o superior.
echo PowerShell 5 no es compatible.
echo.
echo Por favor descargue e instale PowerShell 7+ desde:
echo https://aka.ms/powershell-release?tag=stable
echo.
echo Abriendo navegador con el link de descarga...
start https://aka.ms/powershell-release?tag=stable 2>nul
echo.
pause
exit /b 1

:FoundPwsh

echo [OK] PowerShell 7+ encontrado: !PWSH_EXE!
echo.

REM ============================================================
REM VERIFICAR Y HABILITAR EXECUTIONPOLICY
REM ============================================================

echo [*] Verificando ExecutionPolicy...

REM Verificar política actual
for /f "delims=" %%i in ('"%PWSH_EXE%" -NoProfile -Command "Get-ExecutionPolicy -Scope LocalMachine" 2^>nul') do set "CURRENT_POLICY=%%i"

echo     Politica actual: !CURRENT_POLICY!

REM Si es Restricted o Undefined, habilitar RemoteSigned
if /i "!CURRENT_POLICY!"=="Restricted" goto :EnablePolicy
if /i "!CURRENT_POLICY!"=="Undefined" goto :EnablePolicy
if /i "!CURRENT_POLICY!"=="" goto :EnablePolicy

echo [OK] ExecutionPolicy ya configurado
echo.
goto :PolicyOK

:EnablePolicy
echo [*] Habilitando ejecucion de scripts de PowerShell...
echo.

"%PWSH_EXE%" -NoProfile -Command "try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force; Write-Host '[OK] ExecutionPolicy configurado a RemoteSigned' -ForegroundColor Green } catch { Write-Host '[ERROR] No se pudo configurar ExecutionPolicy:' $_.Exception.Message -ForegroundColor Red; exit 1 }" 2>nul

if !ERRORLEVEL! neq 0 (
    echo.
    echo ================================================================
    echo   ERROR: No se pudo habilitar ExecutionPolicy
    echo ================================================================
    echo.
    echo No se pudo configurar la politica de ejecucion de scripts.
    echo.
    echo Por favor ejecute manualmente en PowerShell como administrador:
    echo   Set-ExecutionPolicy RemoteSigned -Scope LocalMachine
    echo.
    pause
    exit /b 1
)

echo.

:PolicyOK

REM ============================================================
REM EJECUTAR INSTALACIÓN
REM ============================================================

echo ================================================================
echo   Iniciando instalacion de Llevar...
echo ================================================================
echo.

"%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Instalar

set "INSTALL_RESULT=!ERRORLEVEL!"

echo.

if !INSTALL_RESULT! equ 0 (
    echo ================================================================
    echo   INSTALACION COMPLETADA EXITOSAMENTE
    echo ================================================================
    echo.
    echo Llevar ha sido instalado correctamente.
    echo.
    echo Puede:
    echo   - Hacer clic derecho en carpetas y seleccionar "Llevar A..."
    echo   - Arrastrar carpetas al icono "Llevar" del escritorio
    echo   - Ejecutar C:\Llevar\LLEVAR.CMD desde cualquier ubicacion
    echo.
) else (
    echo ================================================================
    echo   ADVERTENCIA: La instalacion finalizo con errores
    echo ================================================================
    echo.
    echo Codigo de salida: !INSTALL_RESULT!
    echo.
    echo Revise los mensajes anteriores para mas detalles.
    echo.
)

pause
exit /b !INSTALL_RESULT!
