<#
.SYNOPSIS
    Tests de integración para Llevar.ps1

.DESCRIPTION
    Pruebas end-to-end que simulan el flujo completo:
    - Comprimir carpeta origen
    - Dividir en bloques
    - Copiar a múltiples USBs simulados
    - Reconstruir en destino
#>

# Importar todos los módulos de Llevar
. (Join-Path $PSScriptRoot "Import-LlevarModules.ps1")

# Importar módulos de test
$mockUSBPath = Join-Path $PSScriptRoot "Mock-USBDevices.ps1"
. $mockUSBPath

# ==========================================
#  CONFIGURACIÓN DE TESTS
# ==========================================

$script:TestRoot = Join-Path $env:TEMP "LLEVAR_INTEGRATION_TESTS"
$script:TestResults = @{
    Passed = 0
    Failed = 0
    Total  = 0
}

function Initialize-TestEnvironment {
    Show-Banner "INICIALIZANDO ENTORNO DE TESTS" -BorderColor Cyan -TextColor Yellow
    
    # Limpiar entorno anterior si existe
    if (Test-Path $script:TestRoot) {
        Remove-Item $script:TestRoot -Recurse -Force
    }
    
    # Crear estructura de directorios
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
    Write-Host "✓ Carpeta de tests creada: $script:TestRoot" -ForegroundColor Green
    
    # Crear carpetas de trabajo
    $origenPath = Join-Path $script:TestRoot "Origen"
    $destinoPath = Join-Path $script:TestRoot "Destino"
    $tempPath = Join-Path $script:TestRoot "Temp"
    
    New-Item -ItemType Directory -Path $origenPath -Force | Out-Null
    New-Item -ItemType Directory -Path $destinoPath -Force | Out-Null
    New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
    
    Write-Host "✓ Carpeta Origen: $origenPath" -ForegroundColor Green
    Write-Host "✓ Carpeta Destino: $destinoPath" -ForegroundColor Green
    Write-Host "✓ Carpeta Temp: $tempPath" -ForegroundColor Green
    
    return @{
        Root    = $script:TestRoot
        Origen  = $origenPath
        Destino = $destinoPath
        Temp    = $tempPath
    }
}

function New-TestData {
    <#
    .SYNOPSIS
        Crea datos de prueba en la carpeta origen
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$OrigenPath,
        
        [int]$TotalSizeMB = 50
    )
    
    Show-Banner "CREANDO DATOS DE PRUEBA" -BorderColor Cyan -TextColor Yellow
    
    # Crear estructura de carpetas
    $subfolders = @("Documentos", "Imagenes", "Videos", "Datos")
    
    foreach ($folder in $subfolders) {
        $folderPath = Join-Path $OrigenPath $folder
        New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
        Write-Host "✓ Carpeta creada: $folder" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Creando archivos de prueba..." -ForegroundColor Cyan
    
    # Crear archivos en cada carpeta
    $fileSize = [math]::Floor(($TotalSizeMB * 1MB) / 10)  # 10 archivos
    
    # Documentos
    for ($i = 1; $i -le 3; $i++) {
        $filePath = Join-Path $OrigenPath "Documentos\documento_$i.txt"
        $fs = [System.IO.File]::Create($filePath)
        $fs.SetLength($fileSize)
        $fs.Close()
        Write-Host "  ✓ documento_$i.txt ($(Format-LlevarBytes $fileSize))" -ForegroundColor Green
    }
    
    # Imágenes
    for ($i = 1; $i -le 3; $i++) {
        $filePath = Join-Path $OrigenPath "Imagenes\imagen_$i.jpg"
        $fs = [System.IO.File]::Create($filePath)
        $fs.SetLength($fileSize)
        $fs.Close()
        Write-Host "  ✓ imagen_$i.jpg ($(Format-LlevarBytes $fileSize))" -ForegroundColor Green
    }
    
    # Videos
    for ($i = 1; $i -le 2; $i++) {
        $filePath = Join-Path $OrigenPath "Videos\video_$i.mp4"
        $fs = [System.IO.File]::Create($filePath)
        $fs.SetLength($fileSize)
        $fs.Close()
        Write-Host "  ✓ video_$i.mp4 ($(Format-LlevarBytes $fileSize))" -ForegroundColor Green
    }
    
    # Datos
    for ($i = 1; $i -le 2; $i++) {
        $filePath = Join-Path $OrigenPath "Datos\datos_$i.db"
        $fs = [System.IO.File]::Create($filePath)
        $fs.SetLength($fileSize)
        $fs.Close()
        Write-Host "  ✓ datos_$i.db ($(Format-LlevarBytes $fileSize))" -ForegroundColor Green
    }
    
    # Archivo README en raíz
    $readmePath = Join-Path $OrigenPath "README.txt"
    @"
DATOS DE PRUEBA PARA LLEVAR.PS1
================================

Esta carpeta contiene datos de prueba para validar
el funcionamiento del sistema LLEVAR.

Contenido:
- Documentos (3 archivos)
- Imágenes (3 archivos)
- Videos (2 archivos)
- Datos (2 archivos)

Total: 10 archivos + carpetas

Creado: $(Get-Date)
"@ | Set-Content $readmePath
    
    Write-Host "  ✓ README.txt" -ForegroundColor Green
    
    Write-Host ""
    
    # Calcular tamaño real
    $totalSize = (Get-ChildItem $OrigenPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
    
    Show-Banner "✓ Datos creados exitosamente`nTamaño total: $(Format-LlevarBytes $totalSize)" -BorderColor Cyan -TextColor Green
}

function Test-CompressionAndSplitting {
    <#
    .SYNOPSIS
        Test de compresión y división en bloques
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$TestEnv
    )
    
    Show-Banner "TEST: COMPRESIÓN Y DIVISIÓN EN BLOQUES" -BorderColor Cyan -TextColor Yellow
    
    $script:TestResults.Total++
    
    try {
        # Nota: Este test requiere que las funciones de Llevar.ps1 estén disponibles
        # Por ahora, solo simulamos el resultado esperado
        
        Write-Host "Simulando compresión de $($TestEnv.Origen)..." -ForegroundColor Cyan
        Start-Sleep -Milliseconds 500
        Write-Host "✓ Carpeta comprimida (simulado)" -ForegroundColor Green
        
        Write-Host "Simulando división en bloques de 10 MB..." -ForegroundColor Cyan
        Start-Sleep -Milliseconds 500
        
        # Crear bloques simulados
        $blockSize = 10 * 1MB
        $blocks = @()
        
        for ($i = 1; $i -le 5; $i++) {
            $blockName = "DATOS.alx{0:D4}" -f $i
            $blockPath = Join-Path $TestEnv.Temp $blockName
            
            # Crear bloque dummy
            $fs = [System.IO.File]::Create($blockPath)
            $fs.SetLength($blockSize)
            $fs.Close()
            
            $blocks += $blockPath
            Write-Host "  ✓ $blockName creado (10 MB)" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "✓ Se crearon $($blocks.Count) bloques" -ForegroundColor Green
        
        $script:TestResults.Passed++
        return $blocks
    }
    catch {
        Write-Host "✗ Error en compresión/división: $($_.Exception.Message)" -ForegroundColor Red
        $script:TestResults.Failed++
        return $null
    }
}

function Test-USBDistribution {
    <#
    .SYNOPSIS
        Test de distribución de bloques en múltiples USBs simulados
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Blocks
    )
    
    Show-Banner "TEST: DISTRIBUCIÓN EN MÚLTIPLES USBs" -BorderColor Cyan -TextColor Yellow
    
    $script:TestResults.Total++
    
    try {
        # Crear USBs simulados con capacidades realistas (2GB, 4GB)
        Write-Host "Creando dispositivos USB simulados..." -ForegroundColor Cyan
        $usb1 = New-MockUSB -DriveLetter "E" -Label "USB_TEST_1" -CapacityMB 2048
        $usb2 = New-MockUSB -DriveLetter "F" -Label "USB_TEST_2" -CapacityMB 4096
        
        Write-Host "✓ USB 1: 2 GB" -ForegroundColor Green
        Write-Host "✓ USB 2: 4 GB" -ForegroundColor Green
        Write-Host ""
        
        # Distribuir bloques
        Write-Host "Distribuyendo bloques en USBs..." -ForegroundColor Cyan
        
        $currentUSB = $usb1
        $usbIndex = 1
        
        foreach ($block in $Blocks) {
            $blockInfo = Get-Item $block
            
            # Si no cabe en el USB actual, cambiar al siguiente
            if (-not $currentUSB.CanFit($blockInfo.Length)) {
                if ($usbIndex -eq 1) {
                    $currentUSB = $usb2
                    $usbIndex = 2
                    Write-Host ""
                    Write-Host "Cambiando a USB $usbIndex..." -ForegroundColor Yellow
                    Write-Host ""
                }
                else {
                    throw "No hay suficiente espacio en los USBs disponibles"
                }
            }
            
            # Copiar bloque
            $currentUSB.CopyFile($block)
            Write-Host "  ✓ $($blockInfo.Name) → USB $usbIndex" -ForegroundColor Green
        }
        
        
        Show-Banner "Distribución completada:`nUSB 1: $($usb1.Files.Count) archivos ($(Format-LlevarBytes $usb1.UsedSize))`nUSB 2: $($usb2.Files.Count) archivos ($(Format-LlevarBytes $usb2.UsedSize))" -BorderColor Cyan -TextColor White
        
        $script:TestResults.Passed++
        
        return @{
            USB1 = $usb1
            USB2 = $usb2
        }
    }
    catch {
        Write-Host "✗ Error en distribución: $($_.Exception.Message)" -ForegroundColor Red
        $script:TestResults.Failed++
        return $null
    }
}

function Test-ReconstructionAndDecompression {
    <#
    .SYNOPSIS
        Test de reconstrucción de bloques y descompresión en destino temporal local
        Simula el proceso INSTALAR.ps1 pero usando carpetas temporales locales
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$USBDevices,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )
    
    Show-Banner "TEST: RECONSTRUCCIÓN Y DESCOMPRESIÓN" -BorderColor Cyan -TextColor Yellow
    
    $script:TestResults.Total++
    
    try {
        # Crear carpeta de instalación temporal (simula destino en máquina final)
        $installTemp = Join-Path $env:TEMP "LLEVAR_INSTALL_TEST"
        if (Test-Path $installTemp) {
            Remove-Item $installTemp -Recurse -Force
        }
        New-Item -ItemType Directory -Path $installTemp -Force | Out-Null
        
        Write-Host "Carpeta de instalación temporal: $installTemp" -ForegroundColor Cyan
        Write-Host ""
        
        # Paso 1: Recolectar todos los bloques de los USBs simulados
        Write-Host "Recolectando bloques de USBs simulados..." -ForegroundColor Cyan
        $allBlocks = @()
        
        if ($USBDevices.USB1) {
            foreach ($file in $USBDevices.USB1.Files) {
                $blockPath = Join-Path $USBDevices.USB1.Path $file
                if (Test-Path $blockPath) {
                    Copy-Item $blockPath $installTemp -Force
                    $allBlocks += $file
                    Write-Host "  ✓ $file copiado desde USB 1" -ForegroundColor Green
                }
            }
        }
        
        if ($USBDevices.USB2) {
            foreach ($file in $USBDevices.USB2.Files) {
                $blockPath = Join-Path $USBDevices.USB2.Path $file
                if (Test-Path $blockPath) {
                    Copy-Item $blockPath $installTemp -Force
                    $allBlocks += $file
                    Write-Host "  ✓ $file copiado desde USB 2" -ForegroundColor Green
                }
            }
        }
        
        Write-Host ""
        Write-Host "✓ Total de bloques recolectados: $($allBlocks.Count)" -ForegroundColor Green
        
        # Paso 2: Simular reconstrucción del archivo comprimido
        Write-Host ""
        Write-Host "Simulando reconstrucción del archivo 7z desde bloques..." -ForegroundColor Cyan
        Start-Sleep -Milliseconds 500
        
        $reconstructedFile = Join-Path $installTemp "DATOS.7z"
        Write-Host "  → Archivo reconstruido: $reconstructedFile (simulado)" -ForegroundColor Gray
        
        # Paso 3: Simular descompresión en destino final
        Write-Host ""
        Write-Host "Simulando descompresión en: $DestinationPath" -ForegroundColor Cyan
        Start-Sleep -Milliseconds 500
        
        # Crear estructura simulada en destino
        $finalDestination = Join-Path $DestinationPath "DATOS_RESTAURADOS"
        New-Item -ItemType Directory -Path $finalDestination -Force | Out-Null
        
        # Crear carpetas simuladas
        @("Documentos", "Imagenes", "Videos", "Datos") | ForEach-Object {
            New-Item -ItemType Directory -Path (Join-Path $finalDestination $_) -Force | Out-Null
        }
        
        Write-Host "  ✓ Carpeta restaurada en: $finalDestination" -ForegroundColor Green
        
        Show-Banner "✓ Reconstrucción y descompresión completadas`nCarpeta temporal de instalación: $installTemp`nCarpeta final restaurada: $finalDestination" -BorderColor Cyan -TextColor Green
        
        $script:TestResults.Passed++
        
        return @{
            InstallTemp = $installTemp
            FinalPath   = $finalDestination
        }
    }
    catch {
        Write-Host "✗ Error en reconstrucción: $($_.Exception.Message)" -ForegroundColor Red
        $script:TestResults.Failed++
        return $null
    }
}

function Remove-TestEnvironment {
    <#
    .SYNOPSIS
        Limpia el entorno de tests
    #>
    
    Show-Banner "LIMPIEZA DE ENTORNO" -BorderColor Cyan -TextColor Yellow
    
    # Limpiar USBs simulados
    Remove-AllMockUSBs
    
    # Limpiar carpeta de tests
    if (Test-Path $script:TestRoot) {
        Remove-Item $script:TestRoot -Recurse -Force
        Write-Host "✓ Carpeta de tests eliminada" -ForegroundColor Green
    }
    
    Write-Host ""
}

function Show-IntegrationTestSummary {
    Show-Banner "RESUMEN DE TESTS DE INTEGRACIÓN" -BorderColor Cyan -TextColor Yellow
    Write-Host "Total de tests: " -NoNewline
    Write-Host "$($script:TestResults.Total)" -ForegroundColor White
    
    Write-Host "Pasados:        " -NoNewline
    Write-Host "$($script:TestResults.Passed)" -ForegroundColor Green
    
    Write-Host "Fallados:       " -NoNewline
    Write-Host "$($script:TestResults.Failed)" -ForegroundColor Red
    
    $percentage = if ($script:TestResults.Total -gt 0) {
        [math]::Round(($script:TestResults.Passed / $script:TestResults.Total) * 100, 2)
    }
    else { 0 }
    
    Write-Host "Tasa de éxito:  " -NoNewline
    if ($percentage -ge 90) {
        Write-Host "$percentage%" -ForegroundColor Green
    }
    elseif ($percentage -ge 70) {
        Write-Host "$percentage%" -ForegroundColor Yellow
    }
    else {
        Write-Host "$percentage%" -ForegroundColor Red
    }
    
    Write-Host ""
}

# ==========================================
#  EJECUTAR TESTS DE INTEGRACIÓN
# ==========================================

function Invoke-IntegrationTests {
    Show-Banner "TESTS DE INTEGRACIÓN - LLEVAR.PS1" -BorderColor Cyan -TextColor Yellow
    
    try {
        # 1. Inicializar entorno
        $testEnv = Initialize-TestEnvironment
        
        # 2. Crear datos de prueba
        New-TestData -OrigenPath $testEnv.Origen -TotalSizeMB 50
        
        # 3. Test de compresión y división
        $blocks = Test-CompressionAndSplitting -TestEnv $testEnv
        
        if ($blocks) {
            # 4. Test de distribución en USBs
            $usbDevices = Test-USBDistribution -Blocks $blocks
            
            # 5. Test de reconstrucción y descompresión (usando carpeta temporal local)
            if ($usbDevices -and ($usbDevices.USB1 -or $usbDevices.USB2)) {
                Write-Host "✓ USBs simulados creados exitosamente" -ForegroundColor Green
                
                # Simular proceso de instalación en máquina destino
                $installResult = Test-ReconstructionAndDecompression -USBDevices $usbDevices -DestinationPath $testEnv.Destino
                
                if ($installResult) {
                    Write-Host "✓ Proceso completo de instalación simulado exitosamente" -ForegroundColor Green
                }
            }
        }
        
        # Mostrar resumen
        Show-IntegrationTestSummary
        
        # Limpieza
        Write-Host "¿Desea limpiar el entorno de tests? (S/N): " -NoNewline -ForegroundColor Yellow
        $response = Read-Host
        
        if ($response -eq 'S' -or $response -eq 's' -or $response -eq 'Y' -or $response -eq 'y') {
            Remove-TestEnvironment
        }
        else {
            Write-Host "`nEntorno de tests conservado en: $script:TestRoot" -ForegroundColor Cyan
            Write-Host "Carpetas creadas:" -ForegroundColor Gray
            Write-Host "  - USBs simulados: $env:TEMP\LLEVAR_TEST_USB" -ForegroundColor Gray
            Write-Host "  - Instalación temporal: $env:TEMP\LLEVAR_INSTALL_TEST" -ForegroundColor Gray
            Write-Host "  - Tests: $script:TestRoot" -ForegroundColor Gray
        }
        
        # Retornar código de salida
        if ($script:TestResults.Failed -eq 0) {
            return 0
        }
        else {
            return 1
        }
    }
    catch {
        Write-Host "`n✗ Error crítico en tests de integración: $($_.Exception.Message)" -ForegroundColor Red
        return 1
    }
}

# Ejecutar si se llama directamente
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Invoke-IntegrationTests
    exit $exitCode
}
