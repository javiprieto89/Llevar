<#
.SYNOPSIS
    Simulador de dispositivos USB para tests de Llevar.ps1

.DESCRIPTION
    Crea dispositivos USB virtuales (carpetas) que simulan el comportamiento
    de múltiples USBs con diferentes capacidades y contenido.
#>

# ==========================================
#  CLASE SIMULADOR DE USB
# ==========================================

class MockUSBDevice {
    [string]$DriveLetter
    [string]$Path
    [string]$Label
    [long]$TotalSize
    [long]$UsedSize
    [long]$FreeSize
    [System.Collections.ArrayList]$Files
    
    MockUSBDevice([string]$driveLetter, [string]$label, [long]$totalSizeMB) {
        $this.DriveLetter = $driveLetter
        $this.Label = $label
        $this.TotalSize = $totalSizeMB * 1MB
        $this.UsedSize = 0
        $this.FreeSize = $this.TotalSize
        $this.Files = [System.Collections.ArrayList]::new()
        
        # Crear carpeta temporal para simular el USB
        $tempRoot = Join-Path $env:TEMP "LLEVAR_TEST_USB"
        if (-not (Test-Path $tempRoot)) {
            New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        }
        
        $this.Path = Join-Path $tempRoot $driveLetter
        if (-not (Test-Path $this.Path)) {
            New-Item -ItemType Directory -Path $this.Path -Force | Out-Null
        }
        
        # Crear archivo de metadata
        $metadata = @{
            DriveLetter = $this.DriveLetter
            Label       = $this.Label
            TotalSize   = $this.TotalSize
            CreatedAt   = Get-Date
        }
        
        $metadataPath = Join-Path $this.Path ".usb_metadata.json"
        $metadata | ConvertTo-Json | Set-Content $metadataPath
    }
    
    [bool] CanFit([long]$fileSize) {
        return ($fileSize -le $this.FreeSize)
    }
    
    [void] CopyFile([string]$sourcePath) {
        $fileInfo = Get-Item $sourcePath
        $fileName = $fileInfo.Name
        $fileSize = $fileInfo.Length
        
        if (-not $this.CanFit($fileSize)) {
            throw "No hay espacio suficiente en $($this.Label). Libre: $($this.FreeSize), Necesario: $fileSize"
        }
        
        # Copiar archivo
        $destPath = Join-Path $this.Path $fileName
        Copy-Item $sourcePath $destPath -Force
        
        # Actualizar contadores
        $this.UsedSize += $fileSize
        $this.FreeSize = $this.TotalSize - $this.UsedSize
        $this.Files.Add($fileName) | Out-Null
    }
    
    [void] CreateDummyFile([string]$fileName, [long]$sizeMB) {
        $filePath = Join-Path $this.Path $fileName
        $sizeBytes = $sizeMB * 1MB
        
        if (-not $this.CanFit($sizeBytes)) {
            throw "No hay espacio suficiente en $($this.Label)"
        }
        
        # Crear archivo dummy
        $fs = [System.IO.File]::Create($filePath)
        $fs.SetLength($sizeBytes)
        $fs.Close()
        
        # Actualizar contadores
        $this.UsedSize += $sizeBytes
        $this.FreeSize = $this.TotalSize - $this.UsedSize
        $this.Files.Add($fileName) | Out-Null
    }
    
    [string] GetInfo() {
        # Construir info dinámica con alineación correcta
        $capacidadStr = "║ Capacidad Total: $(Format-LlevarBytes $this.TotalSize)"
        $usadoStr = "║ Espacio Usado:   $(Format-LlevarBytes $this.UsedSize)"
        $libreStr = "║ Espacio Libre:   $(Format-LlevarBytes $this.FreeSize)"
        $archivosStr = "║ Archivos:        $($this.Files.Count)"
        
        # Calcular ancho máximo (52 caracteres totales con bordes)
        $maxWidth = 52
        $headerStr = "║ USB: $($this.Label) ($($this.DriveLetter))"
        
        # Rellenar con espacios hasta el borde (descontar los 2 bordes)
        $capacidadStr = $capacidadStr.PadRight($maxWidth - 1) + "║"
        $usadoStr = $usadoStr.PadRight($maxWidth - 1) + "║"
        $libreStr = $libreStr.PadRight($maxWidth - 1) + "║"
        $archivosStr = $archivosStr.PadRight($maxWidth - 1) + "║"
        $headerStr = $headerStr.PadRight($maxWidth - 1) + "║"
        
        $info = @"
╔══════════════════════════════════════════════════╗
$headerStr
╠══════════════════════════════════════════════════╣
$capacidadStr
$usadoStr
$libreStr
$archivosStr
╚══════════════════════════════════════════════════╝
"@
        return $info
    }
    
    [void] Clear() {
        # Limpiar todos los archivos (excepto metadata)
        Get-ChildItem $this.Path | Where-Object { $_.Name -ne ".usb_metadata.json" } | Remove-Item -Force -Recurse
        $this.Files.Clear()
        $this.UsedSize = 0
        $this.FreeSize = $this.TotalSize
    }
    
    [void] Dispose() {
        if (Test-Path $this.Path) {
            Remove-Item $this.Path -Recurse -Force
        }
    }
}

# ==========================================
#  FUNCIONES HELPER PARA TESTS
# ==========================================

function Format-LlevarBytes {
    <#
    .SYNOPSIS
        Formatea bytes en formato legible (B, KB, MB, GB)
    #>
    param([long]$Bytes)
    
    if ($Bytes -lt 1KB) { return "{0} B" -f $Bytes }
    elseif ($Bytes -lt 1MB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    elseif ($Bytes -lt 1GB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    else { return "{0:N2} GB" -f ($Bytes / 1GB) }
}

function New-MockUSB {
    <#
    .SYNOPSIS
        Crea un dispositivo USB simulado
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveLetter,
        
        [Parameter(Mandatory = $true)]
        [string]$Label,
        
        [Parameter(Mandatory = $true)]
        [int]$CapacityMB
    )
    
    return [MockUSBDevice]::new($DriveLetter, $Label, $CapacityMB)
}

function Get-MockUSBInfo {
    <#
    .SYNOPSIS
        Obtiene información de un USB simulado
    #>
    param(
        [Parameter(Mandatory = $true)]
        [MockUSBDevice]$USB
    )
    
    Write-Host $USB.GetInfo() -ForegroundColor Cyan
}

function Test-MockUSBScenario {
    <#
    .SYNOPSIS
        Simula un escenario completo de múltiples USBs
    #>
    
    Show-Banner "SIMULACIÓN DE MÚLTIPLES DISPOSITIVOS USB" -BorderColor Cyan -TextColor Yellow
    
    try {
        # Crear 3 USBs con diferentes capacidades
        Write-Host "Creando dispositivos USB simulados..." -ForegroundColor Cyan
        Write-Host ""
        
        $usb1 = New-MockUSB -DriveLetter "E" -Label "USB_01_DATOS" -CapacityMB 2048
        Write-Host "[OK] USB 1: 2 GB - E:\ (USB_01_DATOS)" -ForegroundColor Green
        
        $usb2 = New-MockUSB -DriveLetter "F" -Label "USB_02_BACKUP" -CapacityMB 4096
        Write-Host "[OK] USB 2: 4 GB - F:\ (USB_02_BACKUP)" -ForegroundColor Green
        
        $usb3 = New-MockUSB -DriveLetter "G" -Label "USB_03_EXTRA" -CapacityMB 8192
        Write-Host "[OK] USB 3: 8 GB - G:\ (USB_03_EXTRA)" -ForegroundColor Green
        
        Write-Host ""
        
        # Crear archivos de prueba en cada USB
        Write-Host "Creando archivos de prueba..." -ForegroundColor Cyan
        Write-Host ""
        
        # USB 1: llenar con 10 bloques de 100MB cada uno (1000MB total)
        Write-Host "USB 1 - Copiando bloques..." -ForegroundColor Gray
        for ($i = 1; $i -le 10; $i++) {
            $usb1.CreateDummyFile(("DATOS.alx{0:D4}" -f $i), 100)
            Write-Host (("  [OK] DATOS.alx{0:D4} (100 MB)" -f $i)) -ForegroundColor Green
        }
        
        Write-Host ""
        
        # USB 2: llenar con 20 bloques de 100MB cada uno (2000MB total)
        Write-Host "USB 2 - Copiando bloques..." -ForegroundColor Gray
        for ($i = 11; $i -le 30; $i++) {
            $usb2.CreateDummyFile(("DATOS.alx{0:D4}" -f $i), 100)
            Write-Host (("  [OK] DATOS.alx{0:D4} (100 MB)" -f $i)) -ForegroundColor Green
        }
        
        Write-Host ""
        
        # USB 3: llenar con 30 bloques de 100MB cada uno (3000MB total) y archivos de instalación
        Write-Host "USB 3 - Copiando bloques y archivos del sistema..." -ForegroundColor Gray
        for ($i = 31; $i -le 60; $i++) {
            $usb3.CreateDummyFile(("DATOS.alx{0:D4}" -f $i), 100)
            Write-Host (("  [OK] DATOS.alx{0:D4} (100 MB)" -f $i)) -ForegroundColor Green
        }
        
        # Crear archivos del sistema
        New-Item -ItemType File -Path (Join-Path $usb3.Path "INSTALAR.ps1") -Force | Out-Null
        Write-Host "  [OK] INSTALAR.ps1" -ForegroundColor Green
        
        New-Item -ItemType File -Path (Join-Path $usb3.Path "__EOF__") -Force | Out-Null
        Write-Host "  [OK] __EOF__ (marcador de fin)" -ForegroundColor Green
        
        Write-Host ""
        
        # Mostrar información de cada USB
        Get-MockUSBInfo -USB $usb1
        Write-Host ""
        Get-MockUSBInfo -USB $usb2
        Write-Host ""
        Get-MockUSBInfo -USB $usb3
        Write-Host ""
        
        # Resumen
        Show-Banner "RESUMEN DEL ESCENARIO" -BorderColor Cyan -TextColor Yellow
        
        $totalCapacity = $usb1.TotalSize + $usb2.TotalSize + $usb3.TotalSize
        $totalUsed = $usb1.UsedSize + $usb2.UsedSize + $usb3.UsedSize
        $totalFiles = $usb1.Files.Count + $usb2.Files.Count + $usb3.Files.Count
        
        Write-Host "Total de USBs:       3" -ForegroundColor White
        Write-Host "Capacidad total:     $(Format-LlevarBytes $totalCapacity)" -ForegroundColor White
        Write-Host "Espacio utilizado:   $(Format-LlevarBytes $totalUsed)" -ForegroundColor White
        Write-Host "Total de archivos:   $totalFiles" -ForegroundColor White
        Write-Host "Archivos .alx:       60 bloques" -ForegroundColor White
        Write-Host ""
        
        Write-Host "Rutas de los USBs simulados:" -ForegroundColor Cyan
        Write-Host "  USB 1: $($usb1.Path)" -ForegroundColor Gray
        Write-Host "  USB 2: $($usb2.Path)" -ForegroundColor Gray
        Write-Host "  USB 3: $($usb3.Path)" -ForegroundColor Gray
        Write-Host ""
        
        # Retornar los USBs para uso posterior
        return @{
            USB1 = $usb1
            USB2 = $usb2
            USB3 = $usb3
        }
    }
    catch {
        Write-Host "✗ Error en simulación: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Remove-AllMockUSBs {
    <#
    .SYNOPSIS
        Elimina todos los USBs simulados
    #>
    
    $tempRoot = Join-Path $env:TEMP "LLEVAR_TEST_USB"
    if (Test-Path $tempRoot) {
        Write-Host "Limpiando dispositivos USB simulados..." -ForegroundColor Yellow
        Remove-Item $tempRoot -Recurse -Force
        Write-Host "✓ USBs simulados eliminados" -ForegroundColor Green
    }
}

# ==========================================
#  FUNCIONES DISPONIBLES PÚBLICAMENTE
# ==========================================

# Las funciones están definidas arriba y están disponibles automáticamente
# cuando se dot-source este archivo con: . .\Mock-USBDevices.ps1

# Si se ejecuta directamente (no dot-sourced), mostrar ejemplo
if ($MyInvocation.InvocationName -notmatch '^\.' -and $PSCommandPath) {
    try {
        Test-MockUSBScenario | Out-Null
        
        Write-Host "Presione cualquier tecla para limpiar y salir..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        
        Remove-AllMockUSBs
        
        # Retornar éxito
        exit 0
    }
    catch {
        Write-Host "`n✗ ERROR EN LA SIMULACIÓN DE USB" -ForegroundColor Red
        Write-Host ""
        Write-Host "Mensaje de error:" -ForegroundColor Yellow
        Write-Host "  $($_.Exception.Message)" -ForegroundColor White
        Write-Host ""
        Write-Host "Línea del error:" -ForegroundColor Yellow
        Write-Host "  Línea $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor White
        Write-Host ""
        Write-Host "Comando que falló:" -ForegroundColor Yellow
        Write-Host "  $($_.InvocationInfo.Line.Trim())" -ForegroundColor White
        Write-Host ""
        Write-Host "Stack trace:" -ForegroundColor Yellow
        Write-Host "$($_.ScriptStackTrace)" -ForegroundColor Gray
        Write-Host ""
        
        Remove-AllMockUSBs
        exit 1
    }
}
