@echo off
REM ============================================================
REM  LLEVAR.CMD - Launcher con manejo de ExecutionPolicy
REM  Detecta errores de política y los soluciona automáticamente
REM ============================================================

setlocal EnableDelayedExpansion

REM Obtener la ruta del script PowerShell
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%Llevar.ps1"

REM Verificar que existe el script
if not exist "%PS_SCRIPT%" (
    echo.
    echo ERROR: No se encuentra Llevar.ps1 en: %SCRIPT_DIR%
    echo.
    pause
    exit /b 1
)

REM Construir argumentos pasados al CMD
set "ARGS=%*"

REM Intentar ejecutar el script de PowerShell
echo Ejecutando Llevar.ps1...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %ARGS%

REM Capturar código de error
set "ERROR_CODE=%ERRORLEVEL%"

REM Si el error es relacionado con ExecutionPolicy (usualmente -196608 o 1)
if !ERROR_CODE! neq 0 (
    echo.
    echo ============================================================
    echo  ERROR DETECTADO - Codigo: !ERROR_CODE!
    echo ============================================================
    echo.
    echo Es posible que la politica de ejecucion este bloqueando
    echo la ejecucion de scripts de PowerShell.
    echo.
    echo Desea habilitar la ejecucion de scripts con permisos de
    echo administrador? ^(Esto configurara ExecutionPolicy a RemoteSigned^)
    echo.
    choice /C SN /M "Presione S para Solucionarlo o N para Cancelar"
    
    if !ERRORLEVEL! equ 1 (
        echo.
        echo Elevando permisos de administrador...
        echo.
        
        REM Crear script temporal para cambiar ExecutionPolicy
        set "TEMP_PS=%TEMP%\fix_execution_policy.ps1"
        
        echo # Script temporal para habilitar ExecutionPolicy > "!TEMP_PS!"
        echo try { >> "!TEMP_PS!"
        echo     Write-Host "Verificando politica actual..." -ForegroundColor Cyan >> "!TEMP_PS!"
        echo     $currentPolicy = Get-ExecutionPolicy -Scope LocalMachine >> "!TEMP_PS!"
        echo     Write-Host "Politica actual: $currentPolicy" -ForegroundColor Yellow >> "!TEMP_PS!"
        echo     Write-Host "" >> "!TEMP_PS!"
        echo     Write-Host "Configurando ExecutionPolicy a RemoteSigned..." -ForegroundColor Cyan >> "!TEMP_PS!"
        echo     Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force >> "!TEMP_PS!"
        echo     Write-Host "" >> "!TEMP_PS!"
        echo     Write-Host "Exito: ExecutionPolicy configurado correctamente" -ForegroundColor Green >> "!TEMP_PS!"
        echo     Write-Host "Ahora puede ejecutar scripts de PowerShell sin problemas." -ForegroundColor Green >> "!TEMP_PS!"
        echo     Write-Host "" >> "!TEMP_PS!"
        echo     $newPolicy = Get-ExecutionPolicy -Scope LocalMachine >> "!TEMP_PS!"
        echo     Write-Host "Nueva politica: $newPolicy" -ForegroundColor Green >> "!TEMP_PS!"
        echo     exit 0 >> "!TEMP_PS!"
        echo } >> "!TEMP_PS!"
        echo catch { >> "!TEMP_PS!"
        echo     Write-Host "" >> "!TEMP_PS!"
        echo     Write-Host "ERROR: No se pudo cambiar la politica de ejecucion" -ForegroundColor Red >> "!TEMP_PS!"
        echo     Write-Host $_.Exception.Message -ForegroundColor Red >> "!TEMP_PS!"
        echo     Write-Host "" >> "!TEMP_PS!"
        echo     Write-Host "Intente ejecutar manualmente como administrador:" -ForegroundColor Yellow >> "!TEMP_PS!"
        echo     Write-Host "  Set-ExecutionPolicy RemoteSigned -Scope LocalMachine" -ForegroundColor White >> "!TEMP_PS!"
        echo     exit 1 >> "!TEMP_PS!"
        echo } >> "!TEMP_PS!"
        
        REM Ejecutar con permisos de administrador
        powershell.exe -NoProfile -Command "Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','\"%TEMP_PS%\"' -Verb RunAs -Wait"
        
        set "FIX_RESULT=!ERRORLEVEL!"
        
        REM Limpiar archivo temporal
        if exist "!TEMP_PS!" del /f /q "!TEMP_PS!" >nul 2>&1
        
        if !FIX_RESULT! equ 0 (
            echo.
            echo ============================================================
            echo  POLITICA CONFIGURADA CORRECTAMENTE
            echo ============================================================
            echo.
            echo Reintentando ejecucion de Llevar.ps1...
            echo.
            
            REM Reintentar ejecución del script original
            powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %ARGS%
            set "RETRY_CODE=!ERRORLEVEL!"
            
            if !RETRY_CODE! equ 0 (
                echo.
                echo Ejecucion completada exitosamente.
                echo.
            ) else (
                echo.
                echo Advertencia: El script se ejecuto pero finalizo con codigo: !RETRY_CODE!
                echo.
            )
        ) else (
            echo.
            echo ============================================================
            echo  NO SE PUDO CONFIGURAR LA POLITICA
            echo ============================================================
            echo.
            echo Puede intentar ejecutar manualmente como administrador:
            echo   Set-ExecutionPolicy RemoteSigned -Scope LocalMachine
            echo.
        )
    ) else (
        echo.
        echo Operacion cancelada por el usuario.
        echo.
    )
)

echo.
echo Presione cualquier tecla para salir...
pause >nul
exit /b 0
