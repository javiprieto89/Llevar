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
echo.

REM Intentar ejecutar pwsh directamente para verificar si está en PATH
pwsh.exe -NoProfile -Command "exit 0" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    set "PWSH_EXE=pwsh.exe"
    goto :FoundPwsh
)

REM Buscar con where (el más confiable si está en PATH)
for /f "delims=" %%i in ('where pwsh.exe 2^>nul') do (
    set "PWSH_EXE=%%i"
    goto :FoundPwsh
)

REM Buscar en Program Files (cualquier versión 7+)
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set "PWSH_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe"
    goto :FoundPwsh
)

REM Buscar en otras versiones de Program Files
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

REM Último intento: usar PowerShell 5 para encontrar pwsh
for /f "delims=" %%i in ('powershell -NoProfile -Command "(Get-Command pwsh -ErrorAction SilentlyContinue).Source" 2^>nul') do (
    set "PWSH_EXE=%%i"
    if exist "!PWSH_EXE!" goto :FoundPwsh
)

REM ============================================================
REM PowerShell 7+ NO ENCONTRADO - OFRECER INSTALACIÓN AUTOMÁTICA
REM ============================================================

echo.
echo ================================================================
echo   PowerShell 7 o superior no encontrado
echo ================================================================
echo.
echo LLEVAR requiere PowerShell 7 o superior.
echo PowerShell 5 no es compatible.
echo.
echo Opciones:
echo   [1] Descargar e instalar PowerShell 7 automaticamente (Recomendado)
echo   [2] Abrir pagina de descarga manual
echo   [3] Cancelar instalacion
echo.

choice /C 123 /N /M "Seleccione una opcion (1/2/3): "
set INSTALL_CHOICE=!ERRORLEVEL!

if !INSTALL_CHOICE! equ 3 (
    echo.
    echo Instalacion cancelada por el usuario.
    pause
    exit /b 1
)

if !INSTALL_CHOICE! equ 2 (
    echo.
    echo Abriendo navegador con el link de descarga...
    start https://aka.ms/powershell-release?tag=stable
    pause
    exit /b 1
)

REM Opción 1: Instalación automática
echo.
echo ================================================================
echo   Instalando PowerShell 7 automaticamente...
echo ================================================================
echo.
echo [*] Descargando PowerShell 7...

REM Crear carpeta temporal
set "TEMP_DIR=%TEMP%\LlevarInstall"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

REM Descargar instalador MSI (x64)
powershell -NoProfile -Command "& {$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi' -OutFile '%TEMP_DIR%\PowerShell-Setup.msi' -UseBasicParsing; Write-Host '[OK] Descarga completada' -ForegroundColor Green; exit 0 } catch { Write-Host '[ERROR] Error en la descarga:' $_.Exception.Message -ForegroundColor Red; exit 1 }}"

if !ERRORLEVEL! neq 0 (
    echo.
    echo Error al descargar PowerShell 7.
    echo Abriendo navegador para descarga manual...
    start https://aka.ms/powershell-release?tag=stable
    pause
    exit /b 1
)

echo.
echo [*] Instalando PowerShell 7 (esto puede tardar un minuto)...
echo.

REM Instalar MSI silenciosamente
msiexec /i "%TEMP_DIR%\PowerShell-Setup.msi" /quiet /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1

if !ERRORLEVEL! neq 0 (
    echo.
    echo [ERROR] Error durante la instalacion.
    pause
    exit /b 1
)

echo.
echo [OK] PowerShell 7 instalado exitosamente
echo.

REM Limpiar archivos temporales
if exist "%TEMP_DIR%\PowerShell-Setup.msi" del /f /q "%TEMP_DIR%\PowerShell-Setup.msi"

REM Buscar nuevamente pwsh.exe después de la instalación
echo [*] Detectando PowerShell 7 recien instalado...

REM Refrescar PATH
set "PATH=%ProgramFiles%\PowerShell\7;%PATH%"

REM Buscar con Get-Command nuevamente
for /f "delims=" %%i in ('powershell -NoProfile -Command "(Get-Command pwsh -ErrorAction SilentlyContinue).Source" 2^>nul') do set "PWSH_EXE=%%i"

if not defined PWSH_EXE (
    REM Buscar en ubicación por defecto
    if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
        set "PWSH_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe"
    )
)

if not defined PWSH_EXE (
    echo.
    echo [ERROR] No se pudo detectar PowerShell 7 despues de la instalacion.
    echo Por favor reinicie el sistema e intente nuevamente.
    pause
    exit /b 1
)

echo [OK] PowerShell 7 detectado en: !PWSH_EXE!
echo.

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
