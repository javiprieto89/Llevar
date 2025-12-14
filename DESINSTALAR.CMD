@echo off
REM ============================================================
REM  DESINSTALAR.CMD - Desinstalador de Llevar con auto-elevación
REM  - Eleva permisos automáticamente
REM  - Ejecuta Llevar.ps1 -Desinstalar
REM  - Elimina completamente Llevar del sistema
REM ============================================================

setlocal EnableDelayedExpansion

echo.
echo ================================================================
echo   DESINSTALADOR DE LLEVAR - Sistema de Transferencia de Archivos
echo ================================================================
echo.

REM ============================================================
REM VERIFICAR SI YA ESTÁ EJECUTÁNDOSE COMO ADMINISTRADOR
REM ============================================================

net session >nul 2>&1
if %errorLevel% == 0 (
    REM Ya es administrador, continuar con la desinstalación
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
    echo La desinstalacion de Llevar requiere permisos de administrador.
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
    echo   ADVERTENCIA: No se encuentra Llevar.ps1
    echo ================================================================
    echo.
    echo No se encuentra el archivo: %PS_SCRIPT%
    echo.
    echo Se intentara desinstalar desde C:\Llevar...
    echo.
    
    REM Intentar desde C:\Llevar
    set "PS_SCRIPT=C:\Llevar\Llevar.ps1"
    if not exist "!PS_SCRIPT!" (
        echo.
        echo Tampoco se encuentra en C:\Llevar\Llevar.ps1
        echo.
        echo Se procedera con la desinstalacion manual...
        goto :ManualUninstall
    )
)

echo [OK] Script encontrado: !PS_SCRIPT!
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
echo   ADVERTENCIA: PowerShell 7 no encontrado
echo ================================================================
echo.
echo Se procedera con la desinstalacion manual...
goto :ManualUninstall

:FoundPwsh

echo [OK] PowerShell 7+ encontrado: !PWSH_EXE!
echo.

REM ============================================================
REM EJECUTAR DESINSTALACIÓN
REM ============================================================

echo ================================================================
echo   Iniciando desinstalacion de Llevar...
echo ================================================================
echo.

"%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" -Desinstalar

set "UNINSTALL_RESULT=!ERRORLEVEL!"

echo.

if !UNINSTALL_RESULT! equ 0 (
    echo ================================================================
    echo   DESINSTALACION COMPLETADA EXITOSAMENTE
    echo ================================================================
    echo.
    echo Llevar ha sido desinstalado correctamente del sistema.
    echo.
) else if !UNINSTALL_RESULT! equ 99 (
    echo ================================================================
    echo   DESINSTALACION CANCELADA POR EL USUARIO
    echo ================================================================
    echo.
    echo No se realizaron cambios en el sistema.
    echo.
) else (
    echo ================================================================
    echo   ADVERTENCIA: La desinstalacion finalizo con errores
    echo ================================================================
    echo.
    echo Codigo de salida: !UNINSTALL_RESULT!
    echo.
    echo Revise los mensajes anteriores para mas detalles.
    echo.
)

pause
exit /b !UNINSTALL_RESULT!

:ManualUninstall
REM ============================================================
REM DESINSTALACIÓN MANUAL (Fallback)
REM ============================================================

echo.
echo ================================================================
echo   DESINSTALACION MANUAL
echo ================================================================
echo.
echo Se eliminaran manualmente:
echo   - Entradas del registro (menu contextual)
echo   - Carpeta C:\Llevar
echo   - Acceso directo del escritorio
echo   - Entrada del PATH del sistema
echo.
echo �Desea continuar? (S/N)
echo.

set /p "CONFIRM=>"

if /i not "!CONFIRM!"=="S" (
    echo.
    echo Desinstalacion cancelada.
    echo.
    pause
    exit /b 99
)

echo.
echo [*] Eliminando entradas del registro...

REM Eliminar menú contextual de carpetas
reg delete "HKCR\Directory\shell\Llevar" /f >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo   [OK] Menu contextual de carpetas eliminado
) else (
    echo   [!] No se encontro menu contextual de carpetas
)

REM Eliminar menú contextual de unidades
reg delete "HKCR\Drive\shell\Llevar" /f >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo   [OK] Menu contextual de unidades eliminado
) else (
    echo   [!] No se encontro menu contextual de unidades
)

REM Eliminar entrada de desinstalación
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Llevar" /f >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo   [OK] Entrada del Panel de Control eliminada
) else (
    echo   [!] No se encontro entrada del Panel de Control
)

echo.
echo [*] Eliminando carpeta C:\Llevar...

if exist "C:\Llevar" (
    rd /s /q "C:\Llevar" >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo   [OK] Carpeta C:\Llevar eliminada
    ) else (
        echo   [ERROR] No se pudo eliminar C:\Llevar
        echo   Puede eliminarla manualmente despues de cerrar esta ventana
    )
) else (
    echo   [!] Carpeta C:\Llevar no existe
)

echo.
echo [*] Eliminando acceso directo del escritorio...

set "DESKTOP=%USERPROFILE%\Desktop\Llevar.lnk"
if exist "!DESKTOP!" (
    del /f /q "!DESKTOP!" >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo   [OK] Acceso directo eliminado
    ) else (
        echo   [!] No se pudo eliminar el acceso directo
    )
) else (
    echo   [!] No se encontro acceso directo en el escritorio
)

echo.
echo [*] Eliminando C:\Llevar del PATH del sistema...

REM Nota: Esto es complejo en batch, se recomienda hacerlo manualmente o con PowerShell
echo   [!] Se recomienda eliminar C:\Llevar del PATH manualmente desde:
echo       Panel de Control ^> Sistema ^> Configuracion avanzada del sistema ^> Variables de entorno
echo.

echo ================================================================
echo   DESINSTALACION MANUAL COMPLETADA
echo ================================================================
echo.
echo Puede ser necesario reiniciar el sistema para que todos los
echo cambios surtan efecto.
echo.

pause
exit /b 0
