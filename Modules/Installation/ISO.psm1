# ========================================================================== #
#                   MÓDULO: CREACIÓN DE IM�GENES ISO                         #
# ========================================================================== #
# Propósito: Crear imágenes ISO para distribución en CD/DVD/USB
# Funciones:
#   - Show-IsoMenu: Menú de configuración de modo ISO
#   - New-LlevarIsoImage: Crear imagen ISO usando IMAPI2
#   - New-LlevarIsoMain: Orquestador de creación ISO con volúmenes
# ========================================================================== #

function Show-IsoMenu {
    <#
    .SYNOPSIS
        Menú para configurar modo ISO y tipo de medio
    .DESCRIPTION
        Permite seleccionar entre:
        - Modo USB (normal, sin ISO)
        - Generar CD (700 MB)
        - Generar DVD (4.5 GB)
        - Generar ISO tipo USB (4.5 GB)
    .PARAMETER Config
        Objeto de configuración a modificar
    .OUTPUTS
        Objeto de configuración actualizado
    #>
    param($Config)
    
    $options = @(
        "Modo *USB (normal)",
        "Generar *CD (700 MB)",
        "Generar *DVD (4.5 GB)",
        "Generar ISO tipo *USB (4.5 GB)"
    )
    
    $selection = Show-DosMenu -Title "MODO ISO" -Items $options -CancelValue 0 -DefaultValue $(if ($Config.Iso) { 2 } else { 1 })
    
    switch ($selection) {
        0 { return $Config }
        1 {
            $Config.Iso = $false
            Show-ConsolePopup -Title "Modo USB" -Message "Modo USB activado (normal)" -Options @("*OK") | Out-Null
        }
        2 {
            $Config.Iso = $true
            $Config.IsoDestino = "cd"
            Show-ConsolePopup -Title "Modo ISO" -Message "Generará imágenes ISO de CD (700 MB)" -Options @("*OK") | Out-Null
        }
        3 {
            $Config.Iso = $true
            $Config.IsoDestino = "dvd"
            Show-ConsolePopup -Title "Modo ISO" -Message "Generará imágenes ISO de DVD (4.5 GB)" -Options @("*OK") | Out-Null
        }
        4 {
            $Config.Iso = $true
            $Config.IsoDestino = "usb"
            Show-ConsolePopup -Title "Modo ISO" -Message "Generará imágenes ISO tipo USB (4.5 GB)" -Options @("*OK") | Out-Null
        }
    }
    
    return $Config
}

function New-LlevarIsoImage {
    <#
    .SYNOPSIS
        Crea imagen ISO usando IMAPI2 (Windows COM)
    .DESCRIPTION
        Utiliza el objeto COM IMAPI2FS.MsftFileSystemImage para crear
        imágenes ISO compatibles con CD/DVD/USB. Soporta progreso integrado.
    .PARAMETER SourceFolder
        Carpeta raíz que se incluirá en el ISO
    .PARAMETER IsoPath
        Ruta completa donde se guardará el archivo .iso
    .PARAMETER VolumeLabel
        Etiqueta del volumen (máximo 32 caracteres)
    .OUTPUTS
        String con ruta al ISO creado, o $null si falla
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFolder,
        
        [Parameter(Mandatory = $true)]
        [string]$IsoPath,
        
        [string]$VolumeLabel = "LLEVAR"
    )
    
    try {
        # Validar carpeta origen
        if (-not (Test-Path $SourceFolder -PathType Container)) {
            Write-Log "Carpeta origen no existe: $SourceFolder" "ERROR"
            return $null
        }
        
        # Limitar etiqueta a 32 caracteres
        if ($VolumeLabel.Length -gt 32) {
            $VolumeLabel = $VolumeLabel.Substring(0, 32)
        }
        
        # Crear objeto IMAPI2
        $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
        
        # Configurar formato ISO9660 + Joliet
        $fsi.FileSystemsToCreate = 3  # ISO9660 + Joliet
        $fsi.VolumeName = $VolumeLabel
        
        # Agregar árbol de directorios
        Write-Log "Agregando contenido de $SourceFolder al ISO..." "INFO"
        $fsi.Root.AddTree($SourceFolder, $false)
        
        # Crear stream de resultados
        $resultImage = $fsi.CreateResultImage()
        $imageStream = $resultImage.ImageStream
        
        # Preparar escritura con buffer de 64 KB
        $bufferSize = 2048 * 32  # 64 KB
        $buffer = New-Object byte[] $bufferSize
        $totalBytes = $resultImage.TotalBlocks * 2048
        $bytesWritten = 0L
        
        # Crear archivo de salida
        $fileStream = New-Object System.IO.FileStream($IsoPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        
        Write-Host "Escribiendo imagen ISO: $IsoPath" -ForegroundColor Cyan
        
        # Escribir con barra de progreso
        while ($true) {
            $readCount = $imageStream.Read($buffer, 0, $bufferSize)
            if ($readCount -le 0) { break }
            
            $fileStream.Write($buffer, 0, $readCount)
            $bytesWritten += $readCount
            
            # Actualizar progreso cada 1 MB
            if (($bytesWritten % 1MB) -lt $bufferSize) {
                $percent = [math]::Min(100, [math]::Round(($bytesWritten / $totalBytes) * 100, 0))
                $sizeMB = [math]::Round($bytesWritten / 1MB, 2)
                $totalMB = [math]::Round($totalBytes / 1MB, 2)
                
                Write-LlevarProgressBar -Current $percent -Total 100 -Activity "Creando ISO" `
                    -Status "$sizeMB MB / $totalMB MB"
            }
        }
        
        # Cerrar streams
        $fileStream.Close()
        $imageStream.Close()
        
        # Liberar COM
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($fsi) | Out-Null
        
        Write-Host "`n✓ Imagen ISO creada: $IsoPath" -ForegroundColor Green
        Write-Log "ISO creado exitosamente: $IsoPath ($([math]::Round((Get-Item $IsoPath).Length / 1MB, 2)) MB)" "SUCCESS"
        
        return $IsoPath
    }
    catch {
        Write-Log "Error creando imagen ISO: $($_.Exception.Message)" "ERROR"
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        
        # Limpiar archivo parcial
        if (Test-Path $IsoPath) {
            Remove-Item $IsoPath -Force -ErrorAction SilentlyContinue
        }
        
        return $null
    }
}

function New-LlevarIsoMain {
    <#
    .SYNOPSIS
        Orquestador de creación de imágenes ISO con soporte multi-volumen
    .DESCRIPTION
        Comprime archivos, genera instalador, y crea imágenes ISO.
        Si el contenido supera la capacidad del medio (CD/DVD/USB),
        divide automáticamente en múltiples volúmenes.
    .PARAMETER Origen
        Carpeta origen con archivos a incluir
    .PARAMETER Destino
        Ruta de destino para el instalador
    .PARAMETER Temp
        Carpeta temporal de trabajo
    .PARAMETER SevenZ
        Ruta a 7z.exe o "NATIVE_ZIP"
    .PARAMETER BlockSizeMB
        Tamaño de bloques para división (opcional)
    .PARAMETER Clave
        Contraseña para compresión (opcional)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Origen,
        
        [Parameter(Mandatory = $true)]
        [string]$Destino,
        
        [Parameter(Mandatory = $true)]
        [string]$Temp,
        
        [Parameter(Mandatory = $true)]
        [string]$SevenZ,
        
        [int]$BlockSizeMB,
        
        [string]$Clave,
        
        [string]$IsoDestino = 'dvd'
    )

    # Determinar capacidad del medio
    $mediaCapacity = switch ($IsoDestino) {
        'cd' { 700MB }
        'dvd' { 4500MB }  # 4.5 GB para DVD
        'usb' { 4500MB }  # Por defecto similar a DVD
        default { 4500MB }
    }

    # Comprimir archivos
    $compressionResult = Compress-Folder $Origen $Temp $SevenZ $Clave $BlockSizeMB $Destino
    $blocks = $compressionResult.Files
    $compressionType = $compressionResult.CompressionType

    $installerScript = New-InstallerScript -Temp $Temp -CompressionType $compressionType

    # Calcular tamaño total de bloques más archivos auxiliares
    $totalBlocksSize = 0L
    foreach ($block in $blocks) {
        $totalBlocksSize += (Get-Item $block).Length
    }

    # Tamaño estimado de archivos auxiliares
    $auxSize = 0L
    if ($installerScript -and (Test-Path $installerScript)) {
        $auxSize += (Get-Item $installerScript).Length
    }
    if ($SevenZ -and $SevenZ -ne "NATIVE_ZIP" -and (Test-Path $SevenZ)) {
        $auxSize += (Get-Item $SevenZ).Length
    }
    $auxSize += 1KB  # __EOF__ marker

    $totalSize = $totalBlocksSize + $auxSize

    $baseName = Split-Path $Origen -Leaf
    if (-not $baseName) { $baseName = "LLEVAR" }

    $label = $baseName
    if ($label.Length -gt 32) { $label = $label.Substring(0, 32) }

    $mediaTag = switch ($IsoDestino) {
        'cd' { 'CD' }
        'dvd' { 'DVD' }
        'usb' { 'USB' }
        default { 'ISO' }
    }

    # Si todo cabe en un solo ISO, usar lógica simple
    if ($totalSize -le $mediaCapacity) {
        Write-Host "`nGenerando imagen ISO única..." -ForegroundColor Cyan
        
        $isoRoot = Join-Path $Temp "LLEVAR_ISO_ROOT"
        if (Test-Path $isoRoot) {
            Remove-Item $isoRoot -Recurse -Force
        }
        New-Item -ItemType Directory -Path $isoRoot | Out-Null

        # Copiar bloques
        foreach ($block in $blocks) {
            Copy-Item $block $isoRoot -Force
        }

        # Copiar instalador
        if ($installerScript) {
            Copy-Item $installerScript $isoRoot -Force
        }
        
        # Copiar 7-Zip si es archivo
        if ($SevenZ -and $SevenZ -ne "NATIVE_ZIP" -and (Test-Path $SevenZ)) {
            Copy-Item $SevenZ $isoRoot -Force
        }

        # Marcador de fin
        New-Item -ItemType File -Path (Join-Path $isoRoot "__EOF__") | Out-Null

        # Generar ISO
        $isoName = "{0}_{1}.iso" -f $label, $mediaTag
        $isoPath = Join-Path $PSScriptRoot $isoName

        $isoResult = New-LlevarIsoImage -SourceFolder $isoRoot -IsoPath $isoPath -VolumeLabel $label

        if ($isoResult) {
            Write-Host "Imagen ISO creada en: $isoResult" -ForegroundColor Green
        }
        else {
            Write-Host "No se pudo crear la imagen ISO. Los archivos están en: $isoRoot" -ForegroundColor Red
        }
    }
    else {
        # Dividir en múltiples volúmenes ISO
        Write-Host "`nEl contenido supera la capacidad de un $mediaTag (~$([math]::Round($mediaCapacity/1MB, 0)) MB)." -ForegroundColor Yellow
        Write-Host "Se generarán múltiples volúmenes ISO..." -ForegroundColor Cyan

        $volumes = @()
        $currentVolume = @()
        $currentSize = 0L
        $volumeNumber = 1

        # Reservar espacio para archivos auxiliares en el primer volumen
        $firstVolumeReserve = $auxSize

        foreach ($block in $blocks) {
            $blockSize = (Get-Item $block).Length
            
            # Verificar si el bloque cabe en el volumen actual
            $requiredSpace = $blockSize
            if ($volumeNumber -eq 1) {
                $requiredSpace += $firstVolumeReserve
            }

            if ($currentSize + $requiredSpace -gt $mediaCapacity -and $currentVolume.Count -gt 0) {
                # Crear nuevo volumen
                $volumes += , @{
                    Number = $volumeNumber
                    Blocks = $currentVolume
                    Size   = $currentSize
                }
                $volumeNumber++
                $currentVolume = @()
                $currentSize = 0L
            }

            # Agregar bloque al volumen actual
            $currentVolume += $block
            $currentSize += $blockSize
        }

        # Agregar último volumen
        if ($currentVolume.Count -gt 0) {
            $volumes += , @{
                Number = $volumeNumber
                Blocks = $currentVolume
                Size   = $currentSize
            }
        }

        Write-Host "`nSe generarán $($volumes.Count) volúmenes ISO" -ForegroundColor Cyan
        Write-Host ""

        $isoFiles = @()

        # Crear cada volumen ISO
        for ($i = 0; $i -lt $volumes.Count; $i++) {
            $vol = $volumes[$i]
            $isFirst = ($i -eq 0)
            $isLast = ($i -eq ($volumes.Count - 1))

            $volumeLabel = "{0}_V{1:D2}" -f $label, $vol.Number
            if ($volumeLabel.Length -gt 32) { $volumeLabel = $volumeLabel.Substring(0, 32) }

            Write-Host "Creando volumen $($vol.Number) de $($volumes.Count)..." -ForegroundColor Cyan

            $isoRoot = Join-Path $Temp "LLEVAR_ISO_VOL_$($vol.Number)"
            if (Test-Path $isoRoot) {
                Remove-Item $isoRoot -Recurse -Force
            }
            New-Item -ItemType Directory -Path $isoRoot | Out-Null

            # Copiar bloques del volumen
            foreach ($block in $vol.Blocks) {
                Copy-Item $block $isoRoot -Force
            }

            # Primer volumen: incluir instalador y 7-Zip
            if ($isFirst) {
                if ($installerScript) {
                    Copy-Item $installerScript $isoRoot -Force
                }
                if ($SevenZ -and $SevenZ -ne "NATIVE_ZIP" -and (Test-Path $SevenZ)) {
                    Copy-Item $SevenZ $isoRoot -Force
                }
            }

            # Último volumen: incluir marcador __EOF__
            if ($isLast) {
                New-Item -ItemType File -Path (Join-Path $isoRoot "__EOF__") | Out-Null
            }

            # Generar nombre del ISO
            $isoName = "{0}_{1}_VOL{2:D2}.iso" -f $label, $mediaTag, $vol.Number
            $isoPath = Join-Path $PSScriptRoot $isoName

            # Crear imagen ISO
            $isoResult = New-LlevarIsoImage -SourceFolder $isoRoot -IsoPath $isoPath -VolumeLabel $volumeLabel

            if ($isoResult) {
                $isoFiles += $isoResult
                $sizeGB = [math]::Round((Get-Item $isoResult).Length / 1GB, 2)
                Write-Host "  ✓ $isoName ($sizeGB GB)" -ForegroundColor Green
            }
            else {
                Write-Host "  ✗ Error creando $isoName" -ForegroundColor Red
                Write-Host "    Los archivos están en: $isoRoot" -ForegroundColor Yellow
            }

            Write-Host ""
        }

        # Resumen final
        Show-Banner "✓ VOLÚMENES ISO GENERADOS" -BorderColor Green -TextColor Green
        Write-Host "Total de volúmenes: $($isoFiles.Count)" -ForegroundColor White
        Write-Host "Ubicación: $PSScriptRoot" -ForegroundColor White
        Write-Host ""
        Write-Host "Archivos generados:" -ForegroundColor Cyan
        foreach ($iso in $isoFiles) {
            Write-Host "  - $(Split-Path $iso -Leaf)" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "NOTA: Grabe cada volumen ISO en un $mediaTag separado en orden." -ForegroundColor Yellow
        Write-Host "      El instalador está en el VOL01." -ForegroundColor Yellow
        Write-Host "      El marcador __EOF__ está en el último volumen." -ForegroundColor Yellow
        Write-Host ""
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Show-IsoMenu',
    'New-LlevarIsoImage',
    'New-LlevarIsoMain'
)
