@echo off
REM ============================================================
REM  LLEVAR.CMD - Launcher inteligente para Llevar.ps1
REM  - Instala PowerShell 7 automáticamente si no está presente
REM  - Verifica y requiere PowerShell 7+
REM  - Habilita ExecutionPolicy si es necesario
REM  - Soporta arrastrar carpetas/archivos al icono
REM ============================================================

setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo  LLEVAR - Iniciando launcher...
echo ============================================================
echo.

REM ============================================================
REM OBTENER LA RUTA DEL SCRIPT POWERSHELL
REM ============================================================

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%Llevar.ps1"

echo [1/5] Verificando archivos...
echo       Script dir: %SCRIPT_DIR%
echo       PS Script: %PS_SCRIPT%

REM Verificar que existe el script
if not exist "%PS_SCRIPT%" (
    echo.
    echo [ERROR] No se encuentra Llevar.ps1
    echo.
    echo Presione cualquier tecla para salir...
    pause >nul
    exit /b 1
)
echo       [OK] Llevar.ps1 encontrado
echo.

REM ============================================================
REM VERIFICAR POWERSHELL 7+
REM ============================================================

echo [2/5] Buscando PowerShell 7...

:SearchPowerShell
set "PWSH_EXE="

REM === 1) UBICACION OFICIAL (la correcta) ===
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set "PWSH_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe"
    goto :FoundPwsh
)

REM === 2) OTRAS VERSIONES 7+ (si hubiese varias) ===
for /d %%i in ("%ProgramFiles%\PowerShell\7*") do (
    if exist "%%i\pwsh.exe" (
        set "PWSH_EXE=%%i\pwsh.exe"
        goto :FoundPwsh
    )
)

REM === 3) ULTIMO RECURSO: PATH, PERO FILTRANDO WindowsApps ===
for /f "delims=" %%i in ('where pwsh.exe 2^>nul') do (
    echo %%i | findstr /i "WindowsApps" >nul
    if errorlevel 1 (
        set "PWSH_EXE=%%i"
        goto :FoundPwsh
    )
)

goto :NotFound

:CheckPwsh
REM Verificar que realmente sea PowerShell 7+
set "PWSH_MAJOR="
for /f "delims=" %%v in ('"%PWSH_EXE%" -NoProfile -Command "$PSVersionTable.PSVersion.Major" 2^>nul') do set "PWSH_MAJOR=%%v"

if "%PWSH_MAJOR%"=="" (
    set "PWSH_EXE="
    goto :NotFound
)

if %PWSH_MAJOR% LSS 7 (
    set "PWSH_EXE="
    goto :NotFound
)

echo       [OK] Encontrado: %PWSH_EXE%  (PS %PWSH_MAJOR%)
goto :FoundPwsh

:NotFound
REM ============================================================
REM NO SE ENCONTRÓ - INTENTAR INSTALACIÓN AUTOMÁTICA
REM ============================================================

echo.
echo [AVISO] PowerShell 7 no esta instalado
echo.
echo Intentando instalacion automatica...
echo.

REM Intentar instalar con winget (método recomendado)
echo [Metodo 1/3] Intentando con winget...
winget install --id Microsoft.PowerShell --silent --accept-source-agreements --accept-package-agreements >nul 2>&1

if !ERRORLEVEL! equ 0 (
    echo       [OK] Instalacion con winget exitosa
    echo       Verificando instalacion...
    timeout /t 3 /nobreak >nul
    goto :SearchPowerShell
)

echo       [INFO] winget no disponible o fallo
echo.

REM Intentar con Chocolatey
echo [Metodo 2/3] Intentando con Chocolatey...
where choco >nul 2>&1
if !ERRORLEVEL! equ 0 (
    choco install powershell-core -y >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo       [OK] Instalacion con Chocolatey exitosa
        echo       Verificando instalacion...
        timeout /t 3 /nobreak >nul
        goto :SearchPowerShell
    )
    echo       [INFO] Chocolatey fallo
) else (
    echo       [INFO] Chocolatey no esta instalado
)
echo.

REM Método directo: Descargar e instalar MSI
echo [Metodo 3/3] Descarga directa desde Microsoft...
echo.
echo Este proceso puede tomar varios minutos...
echo.

set "TEMP_DIR=%TEMP%\PowerShell7Install"
set "MSI_FILE=%TEMP_DIR%\PowerShell-7-win-x64.msi"

REM Crear directorio temporal
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

REM Descargar PowerShell 7 usando PowerShell 5
echo Descargando PowerShell 7...
powershell -NoProfile -Command "try { $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri 'https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7-win-x64.msi' -OutFile '%MSI_FILE%' -UseBasicParsing; exit 0 } catch { exit 1 }" 2>nul

if !ERRORLEVEL! neq 0 (
    echo       [ERROR] No se pudo descargar PowerShell 7
    goto :InstallFailed
)

if not exist "%MSI_FILE%" (
    echo       [ERROR] El archivo MSI no se descargo correctamente
    goto :InstallFailed
)

echo       [OK] Descarga completada
echo.
echo Instalando PowerShell 7...
echo (Esto puede requerir permisos de administrador)
echo.

REM Instalar MSI silenciosamente
msiexec /i "%MSI_FILE%" /quiet /norestart

if !ERRORLEVEL! neq 0 (
    echo       [ERROR] La instalacion fallo
    goto :InstallFailed
)

echo       [OK] Instalacion completada
echo       Limpiando archivos temporales...

REM Limpiar
if exist "%MSI_FILE%" del /f /q "%MSI_FILE%" >nul 2>&1
if exist "%TEMP_DIR%" rmdir /q "%TEMP_DIR%" >nul 2>&1

echo       Verificando instalacion...
timeout /t 3 /nobreak >nul
goto :SearchPowerShell

:InstallFailed
echo.
echo ============================================================
echo  NO SE PUDO INSTALAR POWERSHELL 7 AUTOMATICAMENTE
echo ============================================================
echo.
echo LLEVAR requiere PowerShell 7 o superior para funcionar.
echo PowerShell 5 (incluido en Windows) no es compatible.
echo.
echo Link directo:
echo   https://github.com/PowerShell/PowerShell/releases/latest
echo.
echo Comando alternativo (como admin):
echo   winget install Microsoft.PowerShell
echo.
echo Despues de instalar, ejecute LLEVAR.CMD nuevamente.
echo.
echo ============================================================
echo.
echo Presione cualquier tecla para salir...
pause >nul
exit /b 1

:FoundPwsh
echo.

REM ============================================================
REM VERIFICAR Y HABILITAR EXECUTIONPOLICY
REM ============================================================

echo [3/5] Verificando ExecutionPolicy...

REM Verificar política actual
for /f "delims=" %%i in ('"%PWSH_EXE%" -NoProfile -Command "Get-ExecutionPolicy -Scope LocalMachine" 2^>nul') do set "CURRENT_POLICY=%%i"

echo       Policy actual: %CURRENT_POLICY%

REM Si es Restricted o Undefined, habilitar RemoteSigned
if /i "%CURRENT_POLICY%"=="Restricted" goto :EnablePolicy
if /i "%CURRENT_POLICY%"=="Undefined" goto :EnablePolicy
goto :PolicyOK

:EnablePolicy
echo       Habilitando ExecutionPolicy...
echo       (Esto puede requerir permisos de administrador)

REM Intentar habilitar sin elevar primero
"%PWSH_EXE%" -NoProfile -Command "try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force; exit 0 } catch { exit 1 }" >nul 2>&1

if !ERRORLEVEL! equ 0 (
    echo       [OK] ExecutionPolicy habilitado
    goto :PolicyOK
)

REM Si falla, elevar EXPLICITAMENTE con pwsh.exe (no powershell.exe)
echo       Requiere permisos de administrador, elevando con PowerShell 7...
"%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath '%PWSH_EXE%' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command','Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force' -Verb RunAs -Wait" 2>nul

REM Verificar si se aplicó correctamente
for /f "delims=" %%i in ('"%PWSH_EXE%" -NoProfile -Command "Get-ExecutionPolicy -Scope LocalMachine" 2^>nul') do set "NEW_POLICY=%%i"

if /i "%NEW_POLICY%"=="RemoteSigned" (
    echo       [OK] ExecutionPolicy habilitado con permisos de administrador
    goto :PolicyOK
)

if /i "%NEW_POLICY%"=="Unrestricted" (
    echo       [OK] ExecutionPolicy ya estaba configurado (Unrestricted)
    goto :PolicyOK
)

if /i "%NEW_POLICY%"=="Bypass" (
    echo       [OK] ExecutionPolicy ya estaba configurado (Bypass)
    goto :PolicyOK
)

echo.
echo [ERROR] No se pudo habilitar ExecutionPolicy
echo.
echo Ejecute manualmente como administrador en PowerShell 7:
echo Set-ExecutionPolicy RemoteSigned -Scope LocalMachine
echo.
echo Presione cualquier tecla para salir...
pause >nul
exit /b 1

:PolicyOK
echo       [OK] ExecutionPolicy configurado
echo.

REM ============================================================
REM PROCESAR ARGUMENTOS
REM ============================================================

echo [4/5] Procesando argumentos...

set "FIRST_ARG=%~1"
set "SCRIPT_ARGS="
set "HAS_ARGS="

echo       Args recibidos: %*
echo       Primer arg: "%FIRST_ARG%"

REM Validar si el primer argumento es un archivo/carpeta (fuera de bloques peligrosos)
set "IS_VALID_PATH="
if defined FIRST_ARG (
    if exist "%FIRST_ARG%" set "IS_VALID_PATH=1"
)

if defined IS_VALID_PATH (
    echo       [OK] Argumento valido (archivo/carpeta existe)
    set "HAS_ARGS=1"
    set "SCRIPT_ARGS=-Origen ""%FIRST_ARG%"""

    shift
    :ArgLoop
    if "%~1"=="" goto :ArgEnd
    set "SCRIPT_ARGS=!SCRIPT_ARGS! ""%~1"""
    shift
    goto :ArgLoop
    :ArgEnd
) else (
    if defined FIRST_ARG (
        echo       [INFO] Argumento no es archivo/carpeta, pasando tal cual
        set "SCRIPT_ARGS=%*"
    ) else (
        echo       [INFO] Sin argumentos (ejecucion directa)
    )
)

echo       Args finales: !SCRIPT_ARGS!
echo.

REM ============================================================
REM EJECUTAR LLEVAR.PS1 CON POWERSHELL 7
REM ============================================================

echo [5/5] Ejecutando Llevar.ps1...
echo ============================================================
echo.

if defined HAS_ARGS (
    echo [Modo: Con argumentos - ventana persistente]
    echo.
    "%PWSH_EXE%" -NoExit -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" !SCRIPT_ARGS!
) else (
    echo [Modo: Sin argumentos]
    echo.
    "%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" !SCRIPT_ARGS!
)

echo.
echo ============================================================
echo  Script finalizado con codigo: !ERRORLEVEL!
echo ============================================================
echo.
echo Presione cualquier tecla para salir...
pause >nul
exit /b !ERRORLEVEL!
