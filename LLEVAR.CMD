@echo off
REM ============================================================
REM  LLEVAR.CMD - Lanzador adaptado para Modo Interactivo
REM  - Paso 0: Auto-elevación a Administrador
REM  - Paso 4: Captura inteligente de Origen (Drag & Drop / Enviar a) 
REM  - Paso 5: Ejecución coordinada con Llevar.ps1
REM ============================================================

setlocal EnableExtensions

:: [AYUDA] Mostrar ayuda si se pasa /? -h --help
if /I "%~1"=="/?" goto :ShowHelp
if /I "%~1"=="-h" goto :ShowHelp
if /I "%~1"=="--help" goto :ShowHelp
if "%~1"=="" goto :NoArgs

:: [PASO 0] AUTO-ELEVACIÓN
:CheckPrivileges
NET FILE >NUL 2>&1
if %errorlevel% EQU 0 ( goto :GotPrivileges ) else ( goto :GetPrivileges )

:GetPrivileges
echo [SISTEMA] Solicitando permisos de administrador...

set "VBS=%temp%\llevar_elevate.vbs"

if exist "%VBS%" del "%VBS%"
if exist "%VBS%" (
    echo [ERROR] No se pudo eliminar el script VBS existente
    pause & exit /b 1
)

(
  echo Set UAC = CreateObject^("Shell.Application"^)
  echo q = Chr^(34^)
  echo cmd_line = "/c " ^& q ^& q ^& "%~f0" ^& q ^& " " ^& q ^& "%~1" ^& q ^& q
  echo UAC.ShellExecute "cmd.exe", cmd_line, "", "runas", 1
) > "%VBS%"

if not exist "%VBS%" (
    echo [ERROR] No se pudo crear el script VBS para elevación
    pause & exit /b 1
)

cscript //nologo "%VBS%"
del "%VBS%"
exit /b

:GotPrivileges
pushd "%~dp0"

:: [1/4] VERIFICACIÓN DE ARCHIVOS
set "PS_SCRIPT=%~dp0Llevar.ps1"
if not exist "%PS_SCRIPT%" (
    echo [ERROR] No se encuentra Llevar.ps1 en %~dp0
    pause & exit /b 1
)

:: [2/4] BUSCAR / INSTALAR POWERSHELL 7
:SearchPowerShell
set "PWSH_EXE="
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set "PWSH_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe"
) else if exist "%LocalAppData%\Microsoft\PowerShell\7\pwsh.exe" (
    set "PWSH_EXE=%LocalAppData%\Microsoft\PowerShell\7\pwsh.exe"
) else (
    for /f "delims=" %%i in ('where pwsh.exe 2^>nul') do set "PWSH_EXE=%%i"
)

if "%PWSH_EXE%"=="" (
    echo [AVISO] PowerShell 7 no detectado. Intentando instalacion...
    where winget >nul 2>&1 && (
        winget install --id Microsoft.PowerShell --silent --accept-source-agreements
        timeout /t 5 >nul & goto :SearchPowerShell
    )
    echo [ERROR] No se pudo instalar PowerShell 7.
    pause & exit /b 1
)
:: [3/4] PROCESAR ARGUMENTOS (ORIGEN)
set "ORIGEN=%~1"

if not "%ORIGEN%"=="" (
    if not exist "%ORIGEN%" (        
        echo [ERROR] El origen no existe: %ORIGEN%
        pause & exit /b 1
    )
)

:: [4/4] EJECUCIÓN DEL SCRIPT 
"%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Origen "%ORIGEN%"
exit /b

:NoArgs
echo [ERROR] Debes indicar un origen. Usa /? para ayuda.
pause
exit /b 1

:ShowHelp
echo ============================================================
echo  LLEVAR.CMD - Lanzador para Llevar.ps1
echo ============================================================
echo Uso:
echo   Llevar.cmd "RUTA_ORIGEN"
echo.
echo Parametros:
echo   RUTA_ORIGEN  Carpeta o archivo de origen (puede tener espacios).
echo   /? -h --help Muestra esta ayuda.
echo.
echo Descripcion:
echo   Lanza Llevar.ps1 en modo interactivo y bloquea el origen si se pasa.
echo ============================================================
exit /b 0
