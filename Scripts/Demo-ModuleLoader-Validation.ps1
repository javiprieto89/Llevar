<#
.SYNOPSIS
    Demo del nuevo patrón de validación de ModuleLoader

.DESCRIPTION
    Este script demuestra:
    1. Importación exitosa con validación
    2. Manejo de errores cuando falla la importación
    3. Uso correcto del objeto de retorno
#>

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  DEMO: Validación de Importación de Módulos" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Configuración
$ModulesPath = Join-Path $PSScriptRoot "..\Modules"

Write-Host "[1] Importando ModuleLoader.psm1..." -ForegroundColor Yellow
try {
    Import-Module (Join-Path $ModulesPath "Core\ModuleLoader.psm1") -Force -Global -ErrorAction Stop
    Write-Host "    ✓ ModuleLoader cargado" -ForegroundColor Green
}
catch {
    Write-Host "    ✗ Error cargando ModuleLoader: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[2] Importando todos los módulos..." -ForegroundColor Yellow
$importResult = Import-LlevarModules -ModulesPath $ModulesPath -Categories 'All' -Global

Write-Host ""
Write-Host "[3] Validando resultado de importación..." -ForegroundColor Yellow

# VALIDACIÓN CRÍTICA
if (-not $importResult.Success) {
    Write-Host ""
    Write-Host "    ══════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "    ❌ ERROR: La importación de módulos falló" -ForegroundColor Red
    Write-Host "    ══════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-Host "    Módulos cargados: $($importResult.LoadedModules.Count)/$($importResult.TotalModules)" -ForegroundColor Yellow
    Write-Host "    Módulos fallidos: $($importResult.FailedModules.Count)" -ForegroundColor Red
    Write-Host ""
    
    if ($importResult.FailedModules.Count -gt 0) {
        Write-Host "    Módulos que fallaron:" -ForegroundColor Red
        foreach ($failed in $importResult.FailedModules) {
            Write-Host "      ✗ $failed" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    Write-Host "    El script no puede continuar sin los módulos requeridos." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "    Presione ENTER para salir"
    exit 1
}

# Importación exitosa
Write-Host "    ✓ Importación exitosa" -ForegroundColor Green
Write-Host ""

# Mostrar resumen
Write-Host "[4] Resumen de importación:" -ForegroundColor Yellow
Write-Host "    Success: " -NoNewline -ForegroundColor Gray
Write-Host $importResult.Success -ForegroundColor $(if ($importResult.Success) { 'Green' } else { 'Red' })

Write-Host "    Total módulos: " -NoNewline -ForegroundColor Gray
Write-Host $importResult.TotalModules -ForegroundColor White

Write-Host "    Módulos cargados: " -NoNewline -ForegroundColor Gray
Write-Host $importResult.LoadedModules.Count -ForegroundColor Green

Write-Host "    Módulos fallidos: " -NoNewline -ForegroundColor Gray
Write-Host $importResult.FailedModules.Count -ForegroundColor $(if ($importResult.FailedModules.Count -eq 0) { 'Green' } else { 'Red' })

Write-Host "    Tiene warnings: " -NoNewline -ForegroundColor Gray
Write-Host $importResult.HasWarnings -ForegroundColor $(if ($importResult.HasWarnings) { 'Yellow' } else { 'Green' })

Write-Host "    Tiene errores: " -NoNewline -ForegroundColor Gray
Write-Host $importResult.HasErrors -ForegroundColor $(if ($importResult.HasErrors) { 'Red' } else { 'Green' })

# Mostrar warnings si existen
if ($importResult.HasWarnings) {
    Write-Host ""
    Write-Host "[5] Advertencias detectadas:" -ForegroundColor Yellow
    foreach ($warning in $importResult.Warnings) {
        Write-Host "    ⚠ $warning" -ForegroundColor Yellow
    }
}

# Mostrar algunos módulos cargados
if ($importResult.LoadedModules.Count -gt 0) {
    Write-Host ""
    Write-Host "[6] Módulos cargados (primeros 10):" -ForegroundColor Yellow
    $count = [Math]::Min(10, $importResult.LoadedModules.Count)
    for ($i = 0; $i -lt $count; $i++) {
        Write-Host "    ✓ $($importResult.LoadedModules[$i])" -ForegroundColor Green
    }
    if ($importResult.LoadedModules.Count -gt 10) {
        Write-Host "    ... y $($importResult.LoadedModules.Count - 10) más" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ✓ DEMO COMPLETADA EXITOSAMENTE" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Verificar que las funciones están disponibles
Write-Host "[7] Verificando disponibilidad de funciones..." -ForegroundColor Yellow
$testFunctions = @('Write-Log', 'Show-Banner', 'New-TransferConfig', 'Invoke-InteractiveMenu')
foreach ($func in $testFunctions) {
    $exists = Get-Command $func -ErrorAction SilentlyContinue
    if ($exists) {
        Write-Host "    ✓ $func disponible" -ForegroundColor Green
    }
    else {
        Write-Host "    ✗ $func NO disponible" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Patrón de validación demostrado correctamente." -ForegroundColor Cyan
Write-Host "Ver Docs\MODULE-LOADER-VALIDATION.md para más detalles." -ForegroundColor Gray
Write-Host ""
