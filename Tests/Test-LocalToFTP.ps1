<#
.SYNOPSIS
    Test individual: Local → FTP

.DESCRIPTION
    Prueba transferencia de carpeta local a servidor FTP.
    Genera 1GB de datos de prueba y ejecuta Llevar.ps1

.EXAMPLE
    .\Test-LocalToFTP.ps1
#>

param(
    [string]$LlevarPath = "..\Llevar.ps1"
)

# Importar todos los módulos de Llevar
. (Join-Path $PSScriptRoot "Import-LlevarModules.ps1")

Show-Banner "TEST: Local → FTP" -BorderColor Cyan -TextColor Yellow

# Verificar Llevar.ps1
$llevarScript = Join-Path $PSScriptRoot $LlevarPath
if (-not (Test-Path $llevarScript)) {
    Write-Host "✗ No se encuentra Llevar.ps1 en: $llevarScript" -ForegroundColor Red
    exit 1
}

# Crear directorio de prueba
$testDataPath = Join-Path $env:TEMP "LLEVAR_TEST_LOCAL_TO_FTP"
if (Test-Path $testDataPath) {
    Remove-Item $testDataPath -Recurse -Force
}
New-Item -ItemType Directory -Path $testDataPath -Force | Out-Null

Write-Host "Generando 1GB de datos de prueba..." -ForegroundColor Cyan
$filesCount = 10  # 10 archivos de 100MB
for ($i = 1; $i -le $filesCount; $i++) {
    $fileName = "TestFile_{0:D3}.dat" -f $i
    $filePath = Join-Path $testDataPath $fileName
    
    # Generar archivo de 100MB
    $buffer = New-Object byte[] (100 * 1024 * 1024)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($buffer)
    [System.IO.File]::WriteAllBytes($filePath, $buffer)
    $rng.Dispose()
    
    $progress = [math]::Round(($i / $filesCount) * 100)
    Write-Host "  [$progress%] ✓ $fileName (100 MB)" -ForegroundColor Green
}

Write-Host ""
Write-Host "✓ Datos de prueba generados: 1 GB" -ForegroundColor Green
Write-Host ""

# Solicitar destino FTP
Write-Host "Ingrese URL FTP de destino (ej: ftp://servidor.com/backup): " -NoNewline -ForegroundColor Cyan
$ftpDestino = Read-Host

if ([string]::IsNullOrWhiteSpace($ftpDestino)) {
    Write-Host "✗ URL FTP requerida" -ForegroundColor Red
    exit 1
}

# Ejecutar Llevar.ps1
Write-Host ""
Write-Host "Ejecutando Llevar.ps1..." -ForegroundColor Cyan
Write-Host "  Origen: $testDataPath" -ForegroundColor Gray
Write-Host "  Destino: $ftpDestino" -ForegroundColor Gray
Write-Host ""

$startTime = Get-Date

try {
    & $llevarScript -Origen $testDataPath -Destino $ftpDestino
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Show-Banner "✓ TEST COMPLETADO" -BorderColor Green -TextColor Green
    Write-Host "Tiempo total: " -NoNewline
    Write-Host ("{0:hh\:mm\:ss}" -f $duration) -ForegroundColor White
    Write-Host ""
    
    # Preguntar si limpiar
    Write-Host "¿Eliminar datos de prueba? (S/N): " -NoNewline -ForegroundColor Yellow
    $cleanup = Read-Host
    if ($cleanup -eq 'S' -or $cleanup -eq 's') {
        Remove-Item $testDataPath -Recurse -Force
        Write-Host "✓ Datos de prueba eliminados" -ForegroundColor Green
    }
    
    exit 0
}
catch {
    Write-Host ""
    Write-Host "✗ Error en ejecución: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
