<#
.SYNOPSIS
    Test individual: FTP → Local

.DESCRIPTION
    Prueba descarga desde servidor FTP a carpeta local.
    Ejecuta Llevar.ps1 validando conexión FTP.

.EXAMPLE
    .\Test-FTPToLocal.ps1
#>

param(
    [string]$LlevarPath = "..\Llevar.ps1"
)

# Importar módulos de Llevar para tests
. (Join-Path $PSScriptRoot "Import-LlevarModules.ps1")

Show-Banner "TEST: FTP → Local" -BorderColor Cyan -TextColor Yellow

# Verificar Llevar.ps1
$llevarScript = Join-Path $PSScriptRoot $LlevarPath
if (-not (Test-Path $llevarScript)) {
    Write-Host "✗ No se encuentra Llevar.ps1 en: $llevarScript" -ForegroundColor Red
    exit 1
}

# Crear directorio de destino
$testDestPath = Join-Path $env:TEMP "LLEVAR_TEST_FTP_TO_LOCAL"
if (Test-Path $testDestPath) {
    Remove-Item $testDestPath -Recurse -Force
}
New-Item -ItemType Directory -Path $testDestPath -Force | Out-Null

# Solicitar origen FTP
Write-Host "Ingrese URL FTP de origen (ej: ftp://servidor.com/datos): " -NoNewline -ForegroundColor Cyan
$ftpOrigen = Read-Host

if ([string]::IsNullOrWhiteSpace($ftpOrigen)) {
    Write-Host "✗ URL FTP requerida" -ForegroundColor Red
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

# Ejecutar Llevar.ps1
Write-Host ""
Write-Host "Ejecutando Llevar.ps1..." -ForegroundColor Cyan
Write-Host "  Origen: $ftpOrigen" -ForegroundColor Gray
Write-Host "  Destino: $testDestPath" -ForegroundColor Gray
Write-Host ""

$startTime = Get-Date

try {
    & $llevarScript -Origen $ftpOrigen -Destino $testDestPath
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Show-Banner "✓ TEST COMPLETADO" -BorderColor Green -TextColor Green
    Write-Host "Tiempo total: " -NoNewline
    Write-Host ("{0:hh\:mm\:ss}" -f $duration) -ForegroundColor White
    
    # Mostrar archivos descargados
    if (Test-Path $testDestPath) {
        $archivos = Get-ChildItem -Path $testDestPath -File -Recurse
        $tamañoTotal = ($archivos | Measure-Object -Property Length -Sum).Sum
        
        Write-Host ""
        Write-Host "Archivos descargados:" -ForegroundColor Cyan
        Write-Host "  Cantidad: " -NoNewline
        Write-Host $archivos.Count -ForegroundColor White
        Write-Host "  Tamaño: " -NoNewline
        Write-Host ("{0:N2} GB" -f ($tamañoTotal / 1GB)) -ForegroundColor White
        Write-Host ""
        
        $archivos | Select-Object -First 10 | ForEach-Object {
            Write-Host ("  - {0,-40} ({1,8:N2} MB)" -f $_.Name, ($_.Length / 1MB)) -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    
    # Preguntar si limpiar
    Write-Host "¿Eliminar archivos descargados? (S/N): " -NoNewline -ForegroundColor Yellow
    $cleanup = Read-Host
    if ($cleanup -eq 'S' -or $cleanup -eq 's') {
        Remove-Item $testDestPath -Recurse -Force
        Write-Host "✓ Archivos eliminados" -ForegroundColor Green
    }
    
    exit 0
}
catch {
    Write-Host ""
    Write-Host "✗ Error en ejecución: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
