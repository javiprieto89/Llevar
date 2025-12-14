# ============================================================================
# Instalar-MenuContextual.ps1
# Instala el menú contextual "Llevar A..." en Windows 10/11
# Ejecutar como ADMINISTRADOR
# ============================================================================

#Requires -RunAsAdministrator

param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  INSTALAR MENÚ CONTEXTUAL - LLEVAR.PS1" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$llevarPath = "C:\Llevar\Llevar.ps1"
$llevarCmd = "C:\Llevar\LLEVAR.CMD"
$iconPath = "C:\Llevar\Data\Llevar_ContextMenu.ico"

# Fallback a icono del sistema si no existe el personalizado
if (-not (Test-Path $iconPath)) {
    $iconPath = "%SystemRoot%\System32\shell32.dll,43"
    Write-Host "⚠ Icono personalizado no encontrado, usando icono del sistema" -ForegroundColor Yellow
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
        $null = New-Item -Path "HKCR:\Directory\shell\Llevar" -Force
        Set-ItemProperty -Path "HKCR:\Directory\shell\Llevar" -Name "(Default)" -Value "Llevar A..."
        Set-ItemProperty -Path "HKCR:\Directory\shell\Llevar" -Name "Icon" -Value "`"$iconPath`""
        
        $null = New-Item -Path "HKCR:\Directory\shell\Llevar\command" -Force
        Set-ItemProperty -Path "HKCR:\Directory\shell\Llevar\command" -Name "(Default)" -Value "`"$llevarCmd`" `"%1`""
        
        Write-Host "  ✓ Menú contextual para carpetas instalado" -ForegroundColor Green
        
        Write-Host "Configurando menú contextual para ARCHIVOS..." -ForegroundColor Cyan
        
        # Crear claves para archivos (AllFilesystemObjects para mayor compatibilidad)
        $null = New-Item -Path "HKCR:\*\shell\Llevar" -Force
        Set-ItemProperty -Path "HKCR:\*\shell\Llevar" -Name "(Default)" -Value "Llevar A..."
        Set-ItemProperty -Path "HKCR:\*\shell\Llevar" -Name "Icon" -Value "`"$iconPath`""
        
        $null = New-Item -Path "HKCR:\*\shell\Llevar\command" -Force
        Set-ItemProperty -Path "HKCR:\*\shell\Llevar\command" -Name "(Default)" -Value "`"$llevarCmd`" `"%1`""
        
        Write-Host "  ✓ Menú contextual para archivos instalado" -ForegroundColor Green
        
        Write-Host "Configurando menú contextual para UNIDADES..." -ForegroundColor Cyan
        
        # Crear claves para unidades (drives)
        $null = New-Item -Path "HKCR:\Drive\shell\Llevar" -Force
        Set-ItemProperty -Path "HKCR:\Drive\shell\Llevar" -Name "(Default)" -Value "Llevar A..."
        Set-ItemProperty -Path "HKCR:\Drive\shell\Llevar" -Name "Icon" -Value "`"$iconPath`""
        
        $null = New-Item -Path "HKCR:\Drive\shell\Llevar\command" -Force
        Set-ItemProperty -Path "HKCR:\Drive\shell\Llevar\command" -Name "(Default)" -Value "`"$llevarCmd`" `"%1`""
        
        Write-Host "  ✓ Menú contextual para unidades instalado" -ForegroundColor Green
        
        Write-Host "Registrando información de desinstalación..." -ForegroundColor Cyan
        
        # Crear entrada en Programs and Features
        $uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Llevar"
        $null = New-Item -Path $uninstallKey -Force
        Set-ItemProperty -Path $uninstallKey -Name "DisplayName" -Value "Llevar.ps1"
        Set-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -Value "2.0"
        Set-ItemProperty -Path $uninstallKey -Name "Publisher" -Value "AlexSoft"
        Set-ItemProperty -Path $uninstallKey -Name "InstallLocation" -Value "C:\Llevar"
        Set-ItemProperty -Path $uninstallKey -Name "UninstallString" -Value "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File `"C:\Llevar\Instalar-MenuContextual.ps1`" -Uninstall"
        
        Write-Host "  ✓ Información de desinstalación registrada" -ForegroundColor Green
        
        # Refrescar el explorador de archivos
        Write-Host "Refrescando explorador de archivos..." -ForegroundColor Cyan
        try {
            $shell = New-Object -ComObject Shell.Application
            $shell.Windows() | ForEach-Object { $_.Refresh() }
            Write-Host "  ✓ Explorador refrescado" -ForegroundColor Green
        }
        catch {
            Write-Host "  ⚠ No se pudo refrescar el explorador (reinicie manualmente)" -ForegroundColor Yellow
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

Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
