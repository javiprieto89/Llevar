# ============================================================================
# Instalar-MenuContextual.ps1
# Instala el menú contextual "Llevar A..." en Windows 10/11
# Ejecutar como ADMINISTRADOR
# ============================================================================

#Requires -RunAsAdministrator

param(
    [Alias("Desinstalar")]
    [switch]$Uninstall,
    [switch]$SkipPause
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  INSTALAR MENÚ CONTEXTUAL - LLEVAR.PS1" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$llevarPath = "C:\Llevar\Llevar.ps1"
$llevarCmd = "C:\Llevar\LLEVAR.CMD"

# Buscar icono en múltiples ubicaciones
$iconPath = $null
$iconLocations = @(
    "C:\Llevar\Data\Llevar_AlexSoft.ico",
    "C:\Llevar\Data\Llevar_ContextMenu.ico",
    "C:\Llevar\Data\Llevar.ico"
)

foreach ($loc in $iconLocations) {
    if (Test-Path $loc) {
        $iconPath = "`"$loc`""
        Write-Host "✓ Icono encontrado: $loc" -ForegroundColor Green
        break
    }
}

# Fallback a icono del sistema si no existe ningún personalizado
if (-not $iconPath) {
    $iconPath = "%SystemRoot%\System32\shell32.dll,16"
    Write-Host "⚠ Icono personalizado no encontrado, usando icono del sistema (carpeta)" -ForegroundColor Yellow
}

if ($Uninstall) {
    Write-Host "MODO: Desinstalación" -ForegroundColor Red
    Write-Host ""
    
    try {
        # Eliminar entradas de carpetas
        if (Test-Path "HKCR:\Directory\shell\Llevar") {
            Remove-Item "HKCR:\Directory\shell\Llevar" -Recurse -Force
            Write-Host "✓ Entrada de carpetas eliminada" -ForegroundColor Green
        }
        
        # Eliminar entradas de unidades
        if (Test-Path "HKCR:\Drive\shell\Llevar") {
            Remove-Item "HKCR:\Drive\shell\Llevar" -Recurse -Force
            Write-Host "✓ Entrada de unidades eliminada" -ForegroundColor Green
        }
        
        # Eliminar información de desinstalación
        if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Llevar") {
            Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Llevar" -Recurse -Force
            Write-Host "✓ Información de desinstalación eliminada" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "✓ Menú contextual desinstalado exitosamente" -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "✗ Error durante la desinstalación: $_" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "MODO: Instalación" -ForegroundColor Green
    Write-Host ""
    
    # Limpiar entradas antiguas duplicadas primero
    Write-Host "Limpiando entradas antiguas..." -ForegroundColor Cyan
    try {
        # Eliminar entradas antiguas si existen
        if (Test-Path "HKCR:\Directory\shell\Llevar") {
            Remove-Item "HKCR:\Directory\shell\Llevar" -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path "HKCR:\*\shell\Llevar") {
            Remove-Item "HKCR:\*\shell\Llevar" -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path "HKCR:\Drive\shell\Llevar") {
            Remove-Item "HKCR:\Drive\shell\Llevar" -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Host "  ✓ Entradas antiguas eliminadas" -ForegroundColor Green
    }
    catch {
        Write-Host "  ⚠ Error al limpiar entradas antiguas: $_" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Verificar que Llevar.ps1 y LLEVAR.CMD existen
    if (-not (Test-Path $llevarPath)) {
        Write-Host "✗ Error: No se encuentra $llevarPath" -ForegroundColor Red
        Write-Host "  Ejecute primero la instalación principal de Llevar.ps1" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
    
    if (-not (Test-Path $llevarCmd)) {
        Write-Host "✗ Error: No se encuentra $llevarCmd" -ForegroundColor Red
        Write-Host "  Ejecute primero la instalación principal de Llevar.ps1" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
    
    try {
        # Crear la unidad HKCR: si no existe (para acceder a HKEY_CLASSES_ROOT)
        if (-not (Test-Path "HKCR:")) {
            New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
        }
        
        Write-Host "Configurando menú contextual para CARPETAS..." -ForegroundColor Cyan
        
        # Crear claves para carpetas
        try {
            $null = New-Item -Path "HKCR:\Directory\shell\Llevar" -Force -ErrorAction Stop
            $null = Set-ItemProperty -Path "HKCR:\Directory\shell\Llevar" -Name "(Default)" -Value "Llevar A..." -ErrorAction Stop
            $null = Set-ItemProperty -Path "HKCR:\Directory\shell\Llevar" -Name "Icon" -Value $iconPath -ErrorAction Stop
            
            $null = New-Item -Path "HKCR:\Directory\shell\Llevar\command" -Force -ErrorAction Stop
            # Usar LLEVAR.CMD que detecta PowerShell 7 y maneja errores apropiadamente
            $null = Set-ItemProperty -Path "HKCR:\Directory\shell\Llevar\command" -Name "(Default)" -Value "`"$llevarCmd`" `"%1`"" -ErrorAction Stop
            
            Write-Host "  ✓ Menú contextual para carpetas instalado" -ForegroundColor Green
        }
        catch {
            Write-Host "  ⚠ Error al configurar menú para carpetas: $_" -ForegroundColor Yellow
        }
        
        Write-Host "Configurando menú contextual para ARCHIVOS..." -ForegroundColor Cyan
        Write-Host "  (Esto puede tardar unos segundos...)" -ForegroundColor DarkGray
        
        # Crear claves para archivos con timeout debido a que HKCR:\* puede ser lento
        $archivosJob = Start-Job -ScriptBlock {
            param($llevarCmd, $iconPath)
            
            try {
                # Crear unidad HKCR si no existe en el job
                if (-not (Test-Path "HKCR:")) {
                    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction Stop | Out-Null
                }
                
                $null = New-Item -Path "HKCR:\*\shell\Llevar" -Force -ErrorAction Stop
                $null = Set-ItemProperty -Path "HKCR:\*\shell\Llevar" -Name "(Default)" -Value "Llevar A..." -ErrorAction Stop
                $null = Set-ItemProperty -Path "HKCR:\*\shell\Llevar" -Name "Icon" -Value $iconPath -ErrorAction Stop
                
                $null = New-Item -Path "HKCR:\*\shell\Llevar\command" -Force -ErrorAction Stop
                $null = Set-ItemProperty -Path "HKCR:\*\shell\Llevar\command" -Name "(Default)" -Value "`"$llevarCmd`" `"%1`"" -ErrorAction Stop
                
                return "SUCCESS"
            }
            catch {
                return "ERROR: $_"
            }
        } -ArgumentList $llevarCmd, $iconPath
        
        # Esperar hasta 10 segundos
        $completed = Wait-Job -Job $archivosJob -Timeout 10
        
        if ($completed) {
            $result = Receive-Job -Job $archivosJob
            if ($result -eq "SUCCESS") {
                Write-Host "  ✓ Menú contextual para archivos instalado" -ForegroundColor Green
            }
            else {
                Write-Host "  ⚠ Error al configurar menú para archivos: $result" -ForegroundColor Yellow
            }
        }
        else {
            # Timeout - detener el job
            Stop-Job -Job $archivosJob
            Write-Host "  ⚠ Timeout al configurar menú para archivos (omitido)" -ForegroundColor Yellow
            Write-Host "    El menú contextual funcionará en carpetas y unidades" -ForegroundColor DarkGray
        }
        
        Remove-Job -Job $archivosJob -Force -ErrorAction SilentlyContinue
        
        Write-Host "Configurando menú contextual para UNIDADES..." -ForegroundColor Cyan
        
        # Crear claves para unidades (drives)
        try {
            $null = New-Item -Path "HKCR:\Drive\shell\Llevar" -Force -ErrorAction Stop
            $null = Set-ItemProperty -Path "HKCR:\Drive\shell\Llevar" -Name "(Default)" -Value "Llevar A..." -ErrorAction Stop
            $null = Set-ItemProperty -Path "HKCR:\Drive\shell\Llevar" -Name "Icon" -Value $iconPath -ErrorAction Stop
            
            $null = New-Item -Path "HKCR:\Drive\shell\Llevar\command" -Force -ErrorAction Stop
            $null = Set-ItemProperty -Path "HKCR:\Drive\shell\Llevar\command" -Name "(Default)" -Value "`"$llevarCmd`" `"%1`"" -ErrorAction Stop
            
            Write-Host "  ✓ Menú contextual para unidades instalado" -ForegroundColor Green
        }
        catch {
            Write-Host "  ⚠ Error al configurar menú para unidades: $_" -ForegroundColor Yellow
        }
        
        Write-Host "Registrando información de desinstalación..." -ForegroundColor Cyan
        
        # Crear entrada en Programs and Features
        try {
            $uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Llevar"
            $null = New-Item -Path $uninstallKey -Force -ErrorAction Stop
            $null = Set-ItemProperty -Path $uninstallKey -Name "DisplayName" -Value "Llevar.ps1" -ErrorAction Stop
            $null = Set-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -Value "2.0" -ErrorAction Stop
            $null = Set-ItemProperty -Path $uninstallKey -Name "Publisher" -Value "AlexSoft" -ErrorAction Stop
            $null = Set-ItemProperty -Path $uninstallKey -Name "InstallLocation" -Value "C:\Llevar" -ErrorAction Stop
            $null = Set-ItemProperty -Path $uninstallKey -Name "UninstallString" -Value "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File `"C:\Llevar\Instalar-MenuContextual.ps1`" -Uninstall" -ErrorAction Stop
            
            Write-Host "  ✓ Información de desinstalación registrada" -ForegroundColor Green
        }
        catch {
            Write-Host "  ⚠ Error al registrar desinstalación: $_" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  ✓ INSTALACIÓN COMPLETADA EXITOSAMENTE" -ForegroundColor Green
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Ahora puede:" -ForegroundColor White
        Write-Host "  1. Hacer clic derecho en cualquier carpeta" -ForegroundColor Gray
        Write-Host "  2. Seleccionar 'Llevar A...'" -ForegroundColor Gray
        Write-Host "  3. El script Llevar.ps1 se iniciará con la carpeta como origen" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Para desinstalar:" -ForegroundColor Yellow
        Write-Host "  .\Instalar-MenuContextual.ps1 -Uninstall" -ForegroundColor Gray
        Write-Host ""
    }
    catch {
        Write-Host ""
        Write-Host "✗ Error durante la instalación: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Asegúrese de ejecutar este script como ADMINISTRADOR" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
}

if (-not $SkipPause) {
    Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
