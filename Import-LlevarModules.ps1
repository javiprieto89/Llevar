<#
.SYNOPSIS
    Módulo común para importar todas las dependencias necesarias en los tests.

.DESCRIPTION
    Este archivo centraliza todos los imports necesarios para que los tests
    funcionen correctamente con la arquitectura modularizada de Llevar.ps1.
#>

# Ruta al directorio raíz del proyecto
$ProjectRoot = $PSScriptRoot
$ModulesPath = Join-Path $ProjectRoot "Modules"

# Verificar PowerShell 7 antes de importar módulos
$psVersionPath = Join-Path $ModulesPath "System\PowerShellVersion.psm1"
if (Test-Path $psVersionPath) {
    Import-Module $psVersionPath -Force -Global -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if (-not (Assert-PowerShell7)) { exit 1 }
}
elseif ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "⚠ PowerShell 7 requerido" -ForegroundColor Yellow
    exit 1
}

# ========================================================================== #
#                        IMPORTAR TODOS LOS MÓDULOS                          #
# ========================================================================== #

# Importar módulo central de carga
Import-Module (Join-Path $ModulesPath "Core\ModuleLoader.psm1") -Force -Global -ErrorAction Stop

# Importar todos los módulos
$importResult = Import-LlevarModules -ModulesPath $ModulesPath -Categories 'All' -Global

# Verificar que la importación fue exitosa
if (-not $importResult.Success) {
    Write-Host "✗ Error crítico durante importación de módulos" -ForegroundColor Red
    Write-Host "Los tests no pueden ejecutarse sin los módulos requeridos." -ForegroundColor Yellow
    exit 1
}

# Mostrar advertencias si las hay (solo para tests)
if ($importResult.HasWarnings) {
    Write-Host "⚠ Advertencias durante importación ($($importResult.Warnings.Count))" -ForegroundColor Yellow
    foreach ($warning in $importResult.Warnings) {
        Write-Host "  - $warning" -ForegroundColor Gray
    }
}

Write-Host "✓ Módulos de Llevar cargados para tests ($($importResult.LoadedModules.Count)/$($importResult.TotalModules))" -ForegroundColor Green
