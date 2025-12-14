# ============================================================================
# Test-PowerShellVersion.ps1
# Script de prueba para el módulo PowerShellVersion
# ============================================================================

param(
    [switch]$SimulatePowerShell5
)

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$ModulePath = Join-Path $ProjectRoot "Modules\System\PowerShellVersion.psm1"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " TEST: PowerShellVersion Module" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Importar módulo
if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force -Global
    Write-Host "✓ Módulo importado correctamente" -ForegroundColor Green
} else {
    Write-Host "✗ No se encuentra el módulo en: $ModulePath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host " Información del Sistema" -ForegroundColor White
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""

Write-Host "Versión actual de PowerShell: " -NoNewline
Write-Host "$($PSVersionTable.PSVersion)" -ForegroundColor Cyan

Write-Host "PowerShell Edition: " -NoNewline
Write-Host "$($PSVersionTable.PSEdition)" -ForegroundColor Cyan

Write-Host ""
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host " Pruebas de Funciones" -ForegroundColor White
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""

# Test: Test-IsPowerShell7
Write-Host "Test-IsPowerShell7: " -NoNewline
$isPwsh7 = Test-IsPowerShell7
if ($isPwsh7) {
    Write-Host "✓ TRUE" -ForegroundColor Green
    Write-Host "  → Ejecutándose en PowerShell 7+" -ForegroundColor Gray
} else {
    Write-Host "✗ FALSE" -ForegroundColor Yellow
    Write-Host "  → NO está ejecutándose en PowerShell 7+" -ForegroundColor Gray
}

Write-Host ""

# Test: Test-PowerShell7Available
Write-Host "Test-PowerShell7Available: " -NoNewline
$isPwsh7Available = Test-PowerShell7Available
if ($isPwsh7Available) {
    Write-Host "✓ TRUE" -ForegroundColor Green
    Write-Host "  → PowerShell 7 está instalado en el sistema" -ForegroundColor Gray
    
    # Mostrar ruta
    $pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshPath) {
        Write-Host "  → Ruta: $($pwshPath.Source)" -ForegroundColor Gray
    }
} else {
    Write-Host "✗ FALSE" -ForegroundColor Yellow
    Write-Host "  → PowerShell 7 NO está disponible en PATH" -ForegroundColor Gray
}

Write-Host ""
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host " Resumen" -ForegroundColor White
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""

if ($isPwsh7) {
    Write-Host "✓ Sistema cumple con los requisitos (PowerShell 7+)" -ForegroundColor Green
} else {
    Write-Host "✗ Sistema NO cumple con los requisitos" -ForegroundColor Red
    
    if ($isPwsh7Available) {
        Write-Host ""
        Write-Host "NOTA: PowerShell 7 está instalado pero debe ejecutar el script con:" -ForegroundColor Yellow
        Write-Host "  pwsh.exe -File Llevar.ps1" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "ACCIÓN REQUERIDA: Instale PowerShell 7 desde https://aka.ms/powershell" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
