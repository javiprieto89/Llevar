<#
.SYNOPSIS
    Test individual: FTP → FTP

.DESCRIPTION
    Prueba transferencia entre dos servidores FTP.
    Ejecuta Llevar.ps1 validando ambas conexiones FTP.

.EXAMPLE
    .\Test-FTPToFTP.ps1
#>

param(
    [string]$LlevarPath = "..\Llevar.ps1"
)

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  TEST: FTP → FTP" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Verificar Llevar.ps1
$llevarScript = Join-Path $PSScriptRoot $LlevarPath
if (-not (Test-Path $llevarScript)) {
    Write-Host "✗ No se encuentra Llevar.ps1 en: $llevarScript" -ForegroundColor Red
    exit 1
}

# Solicitar origen FTP
Write-Host "ORIGEN FTP" -ForegroundColor Cyan
Write-Host "Ingrese URL FTP de origen (ej: ftp://servidor1.com/datos): " -NoNewline
$ftpOrigen = Read-Host

if ([string]::IsNullOrWhiteSpace($ftpOrigen)) {
    Write-Host "✗ URL FTP de origen requerida" -ForegroundColor Red
    exit 1
}

# Preguntar si generar archivo de prueba
Write-Host ""
Write-Host "¿Generar archivo de prueba de 1GB en origen FTP? (S/N): " -NoNewline -ForegroundColor Yellow
$generarPrueba = Read-Host

if ($generarPrueba -eq 'S' -or $generarPrueba -eq 's') {
    Write-Host ""
    Write-Host "Generando archivo de prueba temporal (1GB)..." -ForegroundColor Cyan
    
    # Crear archivo local temporal
    $tempLocalPath = Join-Path $env:TEMP "LLEVAR_FTP_TEST_1GB"
    if (Test-Path $tempLocalPath) {
        Remove-Item $tempLocalPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempLocalPath -Force | Out-Null
    
    # Generar 10 archivos de 100MB
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $buffer = New-Object byte[] (100 * 1024 * 1024)
    
    for ($i = 1; $i -le 10; $i++) {
        $fileName = "FTP_TestData_{0:D2}.bin" -f $i
        $filePath = Join-Path $tempLocalPath $fileName
        
        Write-Progress -Activity "Generando datos" -Status "Archivo $i de 10" -PercentComplete (($i / 10) * 100)
        
        $rng.GetBytes($buffer)
        [System.IO.File]::WriteAllBytes($filePath, $buffer)
    }
    
    Write-Progress -Activity "Generando datos" -Completed
    $rng.Dispose()
    
    Write-Host "✓ Archivo de prueba generado: 1.00 GB" -ForegroundColor Green
    Write-Host ""
    Write-Host "Subiendo archivos a FTP origen..." -ForegroundColor Cyan
    
    # Subir a FTP usando Llevar.ps1
    try {
        & $llevarScript -Origen $tempLocalPath -Destino $ftpOrigen
        Write-Host "✓ Archivos subidos a FTP" -ForegroundColor Green
        
        # Limpiar temporal
        Remove-Item $tempLocalPath -Recurse -Force
    }
    catch {
        Write-Host "✗ Error subiendo archivos: $($_.Exception.Message)" -ForegroundColor Red
        Remove-Item $tempLocalPath -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }
}

Write-Host ""

# Solicitar destino FTP
Write-Host "DESTINO FTP" -ForegroundColor Cyan
Write-Host "Ingrese URL FTP de destino (ej: ftp://servidor2.com/destino): " -NoNewline
$ftpDestino = Read-Host

if ([string]::IsNullOrWhiteSpace($ftpDestino)) {
    Write-Host "✗ URL FTP de destino requerida" -ForegroundColor Red
    exit 1
}

# Verificar que no sean el mismo servidor
if ($ftpOrigen -eq $ftpDestino) {
    Write-Host ""
    Write-Host "⚠ ADVERTENCIA: Origen y destino son el mismo servidor" -ForegroundColor Yellow
    Write-Host "¿Continuar de todos modos? (S/N): " -NoNewline
    $continuar = Read-Host
    if ($continuar -ne 'S' -and $continuar -ne 's') {
        Write-Host "✗ Test cancelado" -ForegroundColor Red
        exit 1
    }
}

# Ejecutar Llevar.ps1
Write-Host ""
Write-Host "Ejecutando Llevar.ps1..." -ForegroundColor Cyan
Write-Host "  Origen: $ftpOrigen" -ForegroundColor Gray
Write-Host "  Destino: $ftpDestino" -ForegroundColor Gray
Write-Host ""

$startTime = Get-Date

try {
    & $llevarScript -Origen $ftpOrigen -Destino $ftpDestino
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  ✓ TEST COMPLETADO" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Tiempo total: " -NoNewline
    Write-Host ("{0:hh\:mm\:ss}" -f $duration) -ForegroundColor White
    Write-Host ""
    Write-Host "Nota: Verificar manualmente en servidor destino" -ForegroundColor Yellow
    
    exit 0
}
catch {
    Write-Host ""
    Write-Host "✗ Error en ejecución: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
