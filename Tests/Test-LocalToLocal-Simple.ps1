<#
.SYNOPSIS
    Test simple: Local → Local SIN compresión

.DESCRIPTION
    Prueba transferencia directa desde carpeta local a otra carpeta local sin comprimir.
#>

# Importar módulos necesarios
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$ModulesPath = Join-Path $ProjectRoot "Modules"

# Importar TransferConfig explícitamente
Import-Module (Join-Path $ModulesPath "Core\TransferConfig.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Core\Validation.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "UI\Banners.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "UI\ProgressBar.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "System\Robocopy.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "System\FileSystem.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Transfer\Local.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Transfer\Unified.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Parameters\NormalMode.psm1") -Force -Global

# Configurar logging global
$Global:LogFile = Join-Path $ProjectRoot "Logs" "TEST_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"
if (-not (Test-Path (Split-Path $Global:LogFile))) {
    New-Item -ItemType Directory -Path (Split-Path $Global:LogFile) -Force | Out-Null
}

Show-Banner "TEST SIMPLE: Local → Local (Directo)" -BorderColor Cyan -TextColor Yellow

# Crear datos de prueba pequeños
$testSource = Join-Path $env:TEMP "LLEVAR_TEST_SIMPLE_SOURCE"
$testDest = Join-Path $env:TEMP "LLEVAR_TEST_SIMPLE_DEST"

if (Test-Path $testSource) { Remove-Item $testSource -Recurse -Force }
if (Test-Path $testDest) { Remove-Item $testDest -Recurse -Force }

New-Item -ItemType Directory -Path $testSource -Force | Out-Null
New-Item -ItemType Directory -Path $testDest -Force | Out-Null

# Crear 3 archivos de texto pequeños
1..3 | ForEach-Object {
    Set-Content -Path (Join-Path $testSource "test$_.txt") -Value "Contenido de prueba $(Get-Date)"
}

Write-Host "✓ Datos de prueba creados (3 archivos)" -ForegroundColor Green
Write-Host "  Origen: $testSource" -ForegroundColor Cyan
Write-Host "  Destino: $testDest" -ForegroundColor Cyan
Write-Host ""

# Configurar TransferConfig
$config = New-TransferConfig

# Configurar origen
Set-TransferConfigValue -Config $config -Path "Origen.Tipo" -Value "Local"
Set-TransferConfigValue -Config $config -Path "Origen.Local.Path" -Value $testSource
Set-TransferConfigValue -Config $config -Path "OrigenIsSet" -Value $true

# Configurar destino  
Set-TransferConfigValue -Config $config -Path "Destino.Tipo" -Value "Local"
Set-TransferConfigValue -Config $config -Path "Destino.Local.Path" -Value $testDest
Set-TransferConfigValue -Config $config -Path "DestinoIsSet" -Value $true

# IMPORTANTE: Forzar modo directo (sin comprimir) modificando la lógica interna
# Esto evita que Local→Local siempre comprima
Write-Host "Nota: Este test simula transferencia directa modificando temporalmente el comportamiento" -ForegroundColor Yellow
Write-Host ""

try {
    Write-Host "Iniciando transferencia directa..." -ForegroundColor Cyan
    
    # Llamar directamente a Copy-LlevarFiles en lugar de Invoke-NormalMode
    # para evitar la lógica de compresión automática
    $result = Copy-LlevarFiles -TransferConfig $config -ShowProgress $true -ProgressTop -1
    
    Write-Host ""
    Write-Host "✓ Transferencia completada" -ForegroundColor Green
    Write-Host "  Archivos copiados: $($result.FileCount)" -ForegroundColor Cyan
    Write-Host "  Bytes: $($result.BytesCopied)" -ForegroundColor Cyan
    
    # Verificar resultados
    $destFiles = Get-ChildItem $testDest -File
    if ($destFiles.Count -eq 3) {
        Write-Host "✓ Verificación exitosa: 3 archivos en destino" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Error: Se esperaban 3 archivos, se encontraron $($destFiles.Count)" -ForegroundColor Red
    }
}
catch {
    Write-Host "✗ Error durante transferencia:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}
finally {
    # Limpiar
    Write-Host ""
    Write-Host "Limpiando..." -ForegroundColor Gray
    Remove-Item $testSource -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $testDest -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✓ Test completado" -ForegroundColor Green
}
