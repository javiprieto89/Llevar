<#
.SYNOPSIS
    Test individual: Local → USB

.DESCRIPTION
    Prueba transferencia desde carpeta local a dispositivo USB.
    Genera 1GB+ de datos de prueba y ejecuta Llevar.ps1.

.EXAMPLE
    .\Test-LocalToUSB.ps1
#>

param(
    [string]$LlevarPath = "..\Llevar.ps1",
    [switch]$MockUSB
)

# Importar todos los módulos de Llevar
. (Join-Path $PSScriptRoot "Import-LlevarModules.ps1")

Show-Banner "TEST: Local → USB" -BorderColor Cyan -TextColor Yellow

# Verificar Llevar.ps1
$llevarScript = Join-Path $PSScriptRoot $LlevarPath
if (-not (Test-Path $llevarScript)) {
    Write-Host "✗ No se encuentra Llevar.ps1 en: $llevarScript" -ForegroundColor Red
    exit 1
}

# Crear directorio de origen con datos de prueba
$testSourcePath = Join-Path $env:TEMP "LLEVAR_TEST_USB_SOURCE"
if (Test-Path $testSourcePath) {
    Remove-Item $testSourcePath -Recurse -Force
}
New-Item -ItemType Directory -Path $testSourcePath -Force | Out-Null

Write-Host "Generando datos de prueba (1GB)..." -ForegroundColor Cyan

# Generar 10 archivos de 100MB cada uno
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$buffer = New-Object byte[] (100 * 1024 * 1024)

for ($i = 1; $i -le 10; $i++) {
    $fileName = "TestData_USB_{0:D2}.bin" -f $i
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

# Determinar destino USB
if ($MockUSB) {
    # Usar directorio temporal como mock de USB
    $usbDestino = Join-Path $env:TEMP "LLEVAR_TEST_MOCK_USB"
    if (Test-Path $usbDestino) {
        Remove-Item $usbDestino -Recurse -Force
    }
    New-Item -ItemType Directory -Path $usbDestino -Force | Out-Null
    Write-Host "✓ Usando destino simulado (MockUSB): $usbDestino" -ForegroundColor Yellow
}
else {
    # Listar dispositivos USB disponibles
    Write-Host "Dispositivos USB detectados:" -ForegroundColor Cyan
    $usbDrives = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter }
    
    if ($usbDrives) {
        $usbDrives | ForEach-Object {
            $freeGB = [math]::Round($_.SizeRemaining / 1GB, 2)
            $sizeGB = [math]::Round($_.Size / 1GB, 2)
            Write-Host ("  {0}:\ - {1} ({2:N2} GB libre de {3:N2} GB)" -f $_.DriveLetter, $_.FileSystemLabel, $freeGB, $sizeGB) -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "Ingrese letra de unidad USB (ej: E): " -NoNewline -ForegroundColor Cyan
        $driveLetter = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($driveLetter)) {
            Write-Host "✗ Letra de unidad requerida" -ForegroundColor Red
            Remove-Item $testSourcePath -Recurse -Force
            exit 1
        }
        
        $usbDestino = "$($driveLetter.TrimEnd(':')):\LLEVAR_TEST"
        
        # Verificar si la unidad existe
        if (-not (Test-Path "$($driveLetter.TrimEnd(':')):\")) {
            Write-Host "✗ Unidad no encontrada: $($driveLetter.TrimEnd(':')):" -ForegroundColor Red
            Remove-Item $testSourcePath -Recurse -Force
            exit 1
        }
    }
    else {
        Write-Host "  (No se detectaron dispositivos USB)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Ingrese ruta de destino manualmente: " -NoNewline -ForegroundColor Cyan
        $usbDestino = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($usbDestino)) {
            Write-Host "✗ Ruta de destino requerida" -ForegroundColor Red
            Remove-Item $testSourcePath -Recurse -Force
            exit 1
        }
    }
}

# Ejecutar Llevar.ps1
Write-Host ""
Write-Host "Ejecutando Llevar.ps1..." -ForegroundColor Cyan
Write-Host "  Origen: $testSourcePath" -ForegroundColor Gray
Write-Host "  Destino: $usbDestino" -ForegroundColor Gray
Write-Host ""

$startTime = Get-Date

try {
    & $llevarScript -Origen $testSourcePath -Destino $usbDestino
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Show-Banner "✓ TEST COMPLETADO" -BorderColor Green -TextColor Green
    Write-Host "Tiempo total: " -NoNewline
    Write-Host ("{0:hh\:mm\:ss}" -f $duration) -ForegroundColor White
    
    # Verificar archivos copiados
    if (Test-Path $usbDestino) {
        $archivos = Get-ChildItem -Path $usbDestino -File -Recurse
        $tamañoCopiado = ($archivos | Measure-Object -Property Length -Sum).Sum
        
        Write-Host ""
        Write-Host "Archivos transferidos:" -ForegroundColor Cyan
        Write-Host "  Cantidad: " -NoNewline
        Write-Host $archivos.Count -ForegroundColor White
        Write-Host "  Tamaño: " -NoNewline
        Write-Host ("{0:N2} GB" -f ($tamañoCopiado / 1GB)) -ForegroundColor White
    }
    
    Write-Host ""
    
    # Preguntar si limpiar
    Write-Host "¿Eliminar datos de prueba? (S/N): " -NoNewline -ForegroundColor Yellow
    $cleanup = Read-Host
    if ($cleanup -eq 'S' -or $cleanup -eq 's') {
        Remove-Item $testSourcePath -Recurse -Force
        Write-Host "✓ Datos de origen eliminados" -ForegroundColor Green
        
        Write-Host "¿Eliminar archivos del USB? (S/N): " -NoNewline -ForegroundColor Yellow
        $cleanupUsb = Read-Host
        if ($cleanupUsb -eq 'S' -or $cleanupUsb -eq 's') {
            Remove-Item $usbDestino -Recurse -Force
            Write-Host "✓ Archivos del USB eliminados" -ForegroundColor Green
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
