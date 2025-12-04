<#
.SYNOPSIS
    Test individual: Local → ISO

.DESCRIPTION
    Prueba creación de archivo ISO desde carpeta local.
    Genera 1GB+ de datos de prueba y ejecuta Llevar.ps1.

.EXAMPLE
    .\Test-LocalToISO.ps1
#>

param(
    [string]$LlevarPath = "..\Llevar.ps1"
)

# Importar módulos de Llevar para tests
. (Join-Path $PSScriptRoot "Import-LlevarModules.ps1")

Show-Banner "TEST: Local → ISO" -BorderColor Cyan -TextColor Yellow

# Verificar Llevar.ps1
$llevarScript = Join-Path $PSScriptRoot $LlevarPath
if (-not (Test-Path $llevarScript)) {
    Write-Host "✗ No se encuentra Llevar.ps1 en: $llevarScript" -ForegroundColor Red
    exit 1
}

# Crear directorio de origen con datos de prueba
$testSourcePath = Join-Path $env:TEMP "LLEVAR_TEST_ISO_SOURCE"
if (Test-Path $testSourcePath) {
    Remove-Item $testSourcePath -Recurse -Force
}
New-Item -ItemType Directory -Path $testSourcePath -Force | Out-Null

Write-Host "Generando datos de prueba (1GB)..." -ForegroundColor Cyan

# Generar 10 archivos de 100MB cada uno
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$buffer = New-Object byte[] (100 * 1024 * 1024)

for ($i = 1; $i -le 10; $i++) {
    $fileName = "TestData_ISO_{0:D2}.bin" -f $i
    $filePath = Join-Path $testSourcePath $fileName
    
    Write-Progress -Activity "Generando datos" -Status "Archivo $i de 10" -PercentComplete (($i / 10) * 100)
    
    $rng.GetBytes($buffer)
    [System.IO.File]::WriteAllBytes($filePath, $buffer)
}

Write-Progress -Activity "Generando datos" -Completed
$rng.Dispose()

# Calcular tamaño total
$tamañoTotal = (Get-ChildItem -Path $testSourcePath -File | Measure-Object -Property Length -Sum).Sum
Write-Host ("✓ Datos generados: {0:N2} GB en 10 archivos" -f ($tamañoTotal / 1GB)) -ForegroundColor Green
Write-Host ""

# Solicitar destino ISO
Write-Host "Ingrese ruta para archivo ISO (ej: C:\temp\prueba.iso): " -NoNewline -ForegroundColor Cyan
$isoDestino = Read-Host

if ([string]::IsNullOrWhiteSpace($isoDestino)) {
    $isoDestino = Join-Path $env:TEMP "LLEVAR_TEST.iso"
    Write-Host "  → Usando destino predeterminado: $isoDestino" -ForegroundColor Yellow
}

# Verificar extensión .iso
if (-not $isoDestino.EndsWith('.iso')) {
    $isoDestino = $isoDestino + '.iso'
}

# Ejecutar Llevar.ps1
Write-Host ""
Write-Host "Ejecutando Llevar.ps1..." -ForegroundColor Cyan
Write-Host "  Origen: $testSourcePath" -ForegroundColor Gray
Write-Host "  Destino: $isoDestino" -ForegroundColor Gray
Write-Host ""

$startTime = Get-Date

try {
    & $llevarScript -Origen $testSourcePath -Destino $isoDestino
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Show-Banner "✓ TEST COMPLETADO" -BorderColor Green -TextColor Green
    Write-Host "Tiempo total: " -NoNewline
    Write-Host ("{0:hh\:mm\:ss}" -f $duration) -ForegroundColor White
    
    # Verificar archivo ISO creado
    if (Test-Path $isoDestino) {
        $isoFile = Get-Item $isoDestino
        Write-Host ""
        Write-Host "Archivo ISO creado:" -ForegroundColor Cyan
        Write-Host "  Ruta: " -NoNewline
        Write-Host $isoFile.FullName -ForegroundColor White
        Write-Host "  Tamaño: " -NoNewline
        Write-Host ("{0:N2} GB" -f ($isoFile.Length / 1GB)) -ForegroundColor White
    }
    
    Write-Host ""
    
    # Preguntar si limpiar
    Write-Host "¿Eliminar datos de prueba? (S/N): " -NoNewline -ForegroundColor Yellow
    $cleanup = Read-Host
    if ($cleanup -eq 'S' -or $cleanup -eq 's') {
        Remove-Item $testSourcePath -Recurse -Force
        Write-Host "✓ Datos de prueba eliminados" -ForegroundColor Green
        
        Write-Host "¿Eliminar archivo ISO? (S/N): " -NoNewline -ForegroundColor Yellow
        $cleanupIso = Read-Host
        if ($cleanupIso -eq 'S' -or $cleanupIso -eq 's') {
            Remove-Item $isoDestino -Force
            Write-Host "✓ Archivo ISO eliminado" -ForegroundColor Green
        }
    }
    
    exit 0
}
catch {
    Write-Host ""
    Write-Host "✗ Error en ejecución: $($_.Exception.Message)" -ForegroundColor Red
    
    # Limpiar en caso de error
    if (Test-Path $testSourcePath) {
        Remove-Item $testSourcePath -Recurse -Force
    }
    
    exit 1
}
