# ========================================================================== #
#                   MÓDULO: GESTIÓN DE VOLÚMENES Y COPIA USB                 #
# ========================================================================== #
# Propósito: Manejo de volúmenes removibles y copia de bloques a USB
# Funciones:
#   - Test-VolumeWritable: Verifica si un volumen es escribible
#   - Get-TargetVolume: Obtiene volumen removible adecuado
#   - Copy-BlockWithHashCheck: Copia bloque con verificación SHA256
#   - Copy-BlocksToUSB: Orquestador de copia de bloques a múltiples USBs
# ========================================================================== #

function Test-VolumeWritable {
    <#
    .SYNOPSIS
        Verifica si un volumen es escribible y tiene espacio suficiente
    .DESCRIPTION
        Valida que el volumen sea removible, tenga espacio disponible,
        y sea escribible mediante prueba de archivo temporal.
    .PARAMETER Volume
        Objeto Volume a verificar
    .PARAMETER RequiredBytes
        Bytes requeridos (opcional)
    .OUTPUTS
        Boolean - $true si es escribible, $false en caso contrario
    #>
    param(
        [Parameter(Mandatory = $true)] $Volume,
        [long]$RequiredBytes = 0
    )

    if ($Volume.DriveType -ne 'Removable') {
        Write-Host "La unidad $($Volume.DriveLetter): no es removible." -ForegroundColor Yellow
        return $false
    }

    if ($RequiredBytes -gt 0 -and $Volume.SizeRemaining -lt $RequiredBytes) {
        Write-Host "La unidad $($Volume.DriveLetter): no tiene espacio suficiente." -ForegroundColor Yellow
        return $false
    }

    $testPath = "$($Volume.DriveLetter):\__LLEVAR_TEST__.tmp"
    try {
        "test" | Out-File -FilePath $testPath -Encoding ASCII -ErrorAction Stop
        Remove-Item $testPath -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-Host "No se pudo escribir en la unidad $($Volume.DriveLetter):" -ForegroundColor Yellow
        return $false
    }
}

function Get-TargetVolume {
    <#
    .SYNOPSIS
        Obtiene volumen removible adecuado para copia
    .DESCRIPTION
        Busca volúmenes removibles y valida que sean escribibles.
        Si se especifica letra de unidad previa, intenta reutilizarla
        o solicita confirmación para cambiar.
    .PARAMETER CurrentLetter
        Letra de unidad previa (opcional)
    .PARAMETER RequiredBytes
        Bytes mínimos requeridos
    .OUTPUTS
        Objeto Volume adecuado para escritura
    #>    
    param(
        [string]$CurrentLetter,
        [long]$RequiredBytes
    )

    while ($true) {
        $volumes = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' }
        if (-not $volumes) {
            Write-Host "No se detecta ninguna unidad removible." -ForegroundColor Yellow
            Start-Sleep 2
            continue
        }

        if ($CurrentLetter) {
            $target = $volumes | Where-Object { $_.DriveLetter -eq $CurrentLetter } | Select-Object -First 1
            if ($target -and (Test-VolumeWritable -Volume $target -RequiredBytes $RequiredBytes)) {
                return $target
            }

            $other = $volumes | Where-Object { $_.DriveLetter -ne $CurrentLetter } | Select-Object -First 1
            if ($other) {
                Write-Host ""
                Write-Host ("La unidad original era {0}:. Ahora se detecta {1}:." -f $CurrentLetter, $other.DriveLetter) -ForegroundColor Yellow
                $ans = Read-Host "¿Usar $($other.DriveLetter): como nuevo destino? (S/N)"
                if ($ans -match '^[sS]') {
                    if (Test-VolumeWritable -Volume $other -RequiredBytes $RequiredBytes) {
                        return $other
                    }
                }
                else {
                    Write-Host ("Reinserte la unidad {0}: y presione ENTER..." -f $CurrentLetter) -ForegroundColor Yellow
                    Read-Host | Out-Null
                    continue
                }
            }

            Write-Host "No se encontró ninguna unidad adecuada." -ForegroundColor Yellow
            Start-Sleep 2
            continue
        }
        else {
            $candidate = $volumes | Select-Object -First 1
            if (Test-VolumeWritable -Volume $candidate -RequiredBytes $RequiredBytes) {
                return $candidate
            }

            Write-Host "La unidad $($candidate.DriveLetter): no es adecuada. Inserte otra y presione ENTER..." -ForegroundColor Yellow
            Read-Host | Out-Null
        }
    }
}

function Copy-BlockWithHashCheck {
    <#
    .SYNOPSIS
        Copia bloque a USB con verificación de integridad SHA256
    .DESCRIPTION
        Copia archivo bloque por bloque mostrando progreso local y global,
        y verifica integridad con hash SHA256. Reintentar si falla.
    .PARAMETER BlockPath
        Ruta del bloque a copiar
    .PARAMETER Volume
        Volumen destino
    .PARAMETER LocalBarTop
        Posición vertical de barra de progreso local
    .PARAMETER GlobalBarTop
        Posición vertical de barra de progreso global
    .PARAMETER GlobalCopiedBytes
        Referencia a bytes copiados totales
    .PARAMETER GlobalTotalBytes
        Total de bytes a copiar
    .PARAMETER GlobalStartTime
        Tiempo de inicio global
    #>
    param(
        [string]$BlockPath,
        $Volume,
        [int]$LocalBarTop = -1,
        [int]$GlobalBarTop = -1,
        [ref]$GlobalCopiedBytes = $(New-Object int64 0),
        [long]$GlobalTotalBytes = 0,
        [datetime]$GlobalStartTime = $(Get-Date)
    )

    $destPath = Join-Path ("$($Volume.DriveLetter):\") (Split-Path $BlockPath -Leaf)

    $srcInfo = Get-Item $BlockPath
    $totalSize = $srcInfo.Length

    $localStart = Get-Date
    if ($LocalBarTop -ge 0) {
        Write-LlevarProgressBar -Percent 0 -StartTime $localStart -Label ("Copia bloque {0}" -f (Split-Path $BlockPath -Leaf)) -Top $LocalBarTop
    }
    if ($GlobalBarTop -ge 0 -and $GlobalTotalBytes -gt 0) {
        Write-LlevarProgressBar -Percent ([double](($GlobalCopiedBytes.Value * 100.0) / $GlobalTotalBytes)) -StartTime $GlobalStartTime -Label "Copia total..." -Top $GlobalBarTop
    }

    $bufferSize = 1024 * 1024
    $buffer = New-Object byte[] $bufferSize
    $copiedLocal = 0L

    $inStream = [System.IO.File]::OpenRead($BlockPath)
    $outStream = [System.IO.File]::Open($destPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try {
        while (($read = $inStream.Read($buffer, 0, $bufferSize)) -gt 0) {
            $outStream.Write($buffer, 0, $read)
            $copiedLocal += $read
            $GlobalCopiedBytes.Value += $read

            if ($LocalBarTop -ge 0 -and $totalSize -gt 0) {
                $localPct = [double](($copiedLocal * 100.0) / $totalSize)
                Write-LlevarProgressBar -Percent $localPct -StartTime $localStart -Label ("Copia bloque {0}" -f (Split-Path $BlockPath -Leaf)) -Top $LocalBarTop
            }

            if ($GlobalBarTop -ge 0 -and $GlobalTotalBytes -gt 0) {
                $globalPct = [double](($GlobalCopiedBytes.Value * 100.0) / $GlobalTotalBytes)
                Write-LlevarProgressBar -Percent $globalPct -StartTime $GlobalStartTime -Label "Copia total..." -Top $GlobalBarTop
            }
        }
    }
    finally {
        $inStream.Close()
        $outStream.Close()
    }

    if ($LocalBarTop -ge 0) {
        Write-LlevarProgressBar -Percent 100 -StartTime $localStart -Label ("Copia bloque {0}" -f (Split-Path $BlockPath -Leaf)) -Top $LocalBarTop
    }

    try {
        $srcHash = Get-FileHash -Path $BlockPath -Algorithm SHA256
        $dstHash = Get-FileHash -Path $destPath -Algorithm SHA256

        if ($srcHash.Hash -ne $dstHash.Hash) {
            Write-Host "AVISO: el hash no coincide para $($srcHash.Path)." -ForegroundColor Yellow
            $ans = Read-Host "¿Volver a copiar este bloque? (S/N)"
            if ($ans -match '^[sS]') {
                Copy-Item $BlockPath $destPath -Force
                $srcHash = Get-FileHash -Path $BlockPath -Algorithm SHA256
                $dstHash = Get-FileHash -Path $destPath -Algorithm SHA256
                if ($srcHash.Hash -ne $dstHash.Hash) {
                    throw "Hash no coincide después de reintentar la copia."
                }
            }
            else {
                throw "Hash de copia de bloque no coincide."
            }
        }
    }
    catch {
        Write-Host "Error verificando la copia del bloque: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Copy-BlocksToUSB {
    <#
    .SYNOPSIS
        Copia bloques a múltiples USBs o FTP
    .DESCRIPTION
        Orquestador que maneja la copia de bloques a USBs removibles
        o sube a FTP según el destino. Incluye marcador __EOF__ y
        copia de instalador y 7-Zip en primera USB.
    .PARAMETER Blocks
        Array de rutas de bloques a copiar
    .PARAMETER InstallerPath
        Ruta del INSTALAR.ps1 generado
    .PARAMETER SevenZPath
        Ruta de 7z.exe portable
    .PARAMETER CompressionType
        Tipo de compresión ("7ZIP" o "NATIVE_ZIP")
    .PARAMETER DestinationPath
        Ruta de destino para carpetas locales (cuando no es FTP)
    .PARAMETER TransferConfig
        Objeto TransferConfig completo cuando el destino es FTP
    #>
    param(
        $Blocks,
        [string]$InstallerPath,
        [string]$SevenZPath,
        [string]$CompressionType = "7ZIP",
        [string]$DestinationPath = $null,
        $TransferConfig
    )

    # Si el destino es FTP, usar TransferConfig y el dispatcher unificado
    if ($TransferConfig -and $TransferConfig.Destino.Tipo -eq "FTP") {
        Write-Host "`nSubiendo bloques a FTP usando TransferConfig..." -ForegroundColor Cyan

        # Crear carpeta temporal que contenga todos los archivos a subir
        $uploadRoot = Join-Path $env:TEMP "LLEVAR_FTP_UPLOAD"
        if (Test-Path $uploadRoot) {
            Remove-Item $uploadRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $uploadRoot | Out-Null

        try {
            # Copiar bloques al directorio temporal
            foreach ($block in $Blocks) {
                $fileName = [System.IO.Path]::GetFileName($block)
                Copy-Item -Path $block -Destination (Join-Path $uploadRoot $fileName) -Force
            }

            # Copiar INSTALAR.ps1 si existe
            if ($InstallerPath -and (Test-Path $InstallerPath)) {
                $installerName = [System.IO.Path]::GetFileName($InstallerPath)
                Copy-Item -Path $InstallerPath -Destination (Join-Path $uploadRoot $installerName) -Force
            }

            # Copiar 7-Zip si es necesario
            if ($SevenZPath -and $CompressionType -ne "NATIVE_ZIP" -and (Test-Path $SevenZPath)) {
                $sevenZName = [System.IO.Path]::GetFileName($SevenZPath)
                Copy-Item -Path $SevenZPath -Destination (Join-Path $uploadRoot $sevenZName) -Force
            }

            # Construir TransferConfig específico para Local -> FTP
            $ftpConfig = New-TransferConfig
            $ftpConfig.Origen.Tipo = "Local"
            $ftpConfig.Origen.Local.Path = $uploadRoot

            $ftpConfig.Destino.Tipo = "FTP"
            foreach ($prop in $TransferConfig.Destino.FTP.PSObject.Properties) {
                $ftpConfig.Destino.FTP.$($prop.Name) = $prop.Value
            }

            # Mantener opciones generales relevantes
            $ftpConfig.Opciones.BlockSizeMB = $TransferConfig.Opciones.BlockSizeMB
            $ftpConfig.Opciones.Clave = $TransferConfig.Opciones.Clave

            # Usar dispatcher unificado
            $modulesRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
            $dispatcherPath = Join-Path $modulesRoot "Transfer\Unified.psm1"
            if (-not (Get-Command Copy-LlevarFiles -ErrorAction SilentlyContinue)) {
                Import-Module $dispatcherPath -Force -Global
            }

            $null = Copy-LlevarFiles -TransferConfig $ftpConfig
            Write-Host "`nV Todos los archivos subidos a FTP correctamente" -ForegroundColor Green
        }
        finally {
            if (Test-Path $uploadRoot) {
                Remove-Item $uploadRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        return
    }

    # Si el destino es una carpeta local existente, copiar directamente
    if ($DestinationPath -and (Test-Path $DestinationPath -PathType Container)) {
        Write-Host "`nCopiando bloques a carpeta local: $DestinationPath" -ForegroundColor Cyan
        
        $totalBytes = 0L
        foreach ($b in $Blocks) {
            $info = Get-Item $b
            $totalBytes += $info.Length
        }
        
        $copied = 0
        foreach ($block in $Blocks) {
            $fileName = [System.IO.Path]::GetFileName($block)
            $destFile = Join-Path $DestinationPath $fileName
            
            Write-Host "Copiando: $fileName" -ForegroundColor Gray
            Copy-Item -Path $block -Destination $destFile -Force
            $copied++
        }
        
        # Copiar el instalador
        if ($InstallerPath -and (Test-Path $InstallerPath)) {
            Write-Host "Copiando: INSTALAR.ps1" -ForegroundColor Gray
            Copy-Item -Path $InstallerPath -Destination $DestinationPath -Force
        }
        
        # Copiar 7-Zip si es necesario
        if ($SevenZPath -and $CompressionType -ne "NATIVE_ZIP" -and (Test-Path $SevenZPath)) {
            Write-Host "Copiando: 7z.exe" -ForegroundColor Gray
            Copy-Item -Path $SevenZPath -Destination $DestinationPath -Force
        }
        
        # NO crear marcador __EOF__ para carpetas locales
        # (todos los archivos están juntos, no se necesita marcador)
        
        Write-Host "`n✓ Todos los archivos copiados a $DestinationPath correctamente" -ForegroundColor Green
        return
    }
    
    # Si el destino es FTP, subir archivos directamente (rama legacy deshabilitada)
    if ($false -and $DestinationPath -match '^FTP:(.+)$') {
        $driveName = $Matches[1]
        Write-Host "`nSubiendo bloques a FTP..." -ForegroundColor Cyan
        
        $totalBytes = 0L
        foreach ($b in $Blocks) {
            $info = Get-Item $b
            $totalBytes += $info.Length
        }
        
        $uploaded = 0
        foreach ($block in $Blocks) {
            $fileName = [System.IO.Path]::GetFileName($block)
            $success = Send-FtpFile -LocalPath $block -DriveName $driveName -RemoteFileName $fileName
            
            if (-not $success) {
                Write-Host "Error al subir $fileName. ¿Desea reintentar?" -ForegroundColor Yellow
                $choice = Read-Host "S/N"
                if ($choice -eq 'S' -or $choice -eq 's') {
                    $success = Send-FtpFile -LocalPath $block -DriveName $driveName -RemoteFileName $fileName
                }
                
                if (-not $success) {
                    throw "Fallo al subir bloques a FTP"
                }
            }
            $uploaded++
        }
        
        # Subir el instalador
        if ($InstallerPath -and (Test-Path $InstallerPath)) {
            $installerName = [System.IO.Path]::GetFileName($InstallerPath)
            Send-FtpFile -LocalPath $InstallerPath -DriveName $driveName -RemoteFileName $installerName
        }
        
        # Subir 7-Zip si es necesario
        if ($SevenZPath -and $CompressionType -ne "NATIVE_ZIP" -and (Test-Path $SevenZPath)) {
            $sevenZName = [System.IO.Path]::GetFileName($SevenZPath)
            Send-FtpFile -LocalPath $SevenZPath -DriveName $driveName -RemoteFileName $sevenZName
        }
        
        Write-Host "`n✓ Todos los archivos subidos a FTP correctamente" -ForegroundColor Green
        return
    }

    # Lógica original para USB
    $firstUSB = $null
    $totalBytes = 0L
    foreach ($b in $Blocks) {
        $info = Get-Item $b
        $totalBytes += $info.Length
    }

    $globalCopied = 0L
    $globalStart = Get-Date

    $globalBarTop = [console]::CursorTop
    Write-Host ""
    $localBarTop = [console]::CursorTop
    Write-Host ""

    foreach ($block in $Blocks) {
        while ($true) {
            Write-Host ""
            Write-Host "Inserte una unidad USB para copiar el bloque:"
            Write-Host "  $([System.IO.Path]::GetFileName($block))"
            Read-Host "Presione ENTER cuando esté lista"

            $usb = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.SizeRemaining -gt 0 } | Select-Object -First 1
            if (-not $usb) {
                Write-Host "No se detecta una USB válida." -ForegroundColor Yellow
                continue
            }

            $free = $usb.SizeRemaining
            $size = (Get-Item $block).Length

            if ($size -gt $free) {
                Write-Host "La USB no tiene espacio suficiente." -ForegroundColor Yellow
                continue
            }

            $refGlobal = [ref]$globalCopied
            Copy-BlockWithHashCheck -BlockPath $block -Volume $usb -LocalBarTop $localBarTop -GlobalBarTop $globalBarTop -GlobalCopiedBytes $refGlobal -GlobalTotalBytes $totalBytes -GlobalStartTime $globalStart
            Write-Host "Copiado a $($usb.DriveLetter):\" -ForegroundColor Green

            if (-not $firstUSB) { $firstUSB = $usb }

            break
        }
    }

    # Último disco → __EOF__
    Write-Host ""
    Write-Host "Inserte la última USB para marcar el final."
    Read-Host "ENTER cuando esté lista"

    $last = $null
    while (-not $last) {
        $last = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.SizeRemaining -gt 0 } | Select-Object -First 1
    }

    New-Item -ItemType File -Path "$($last.DriveLetter):\__EOF__" | Out-Null

    # Copiar instalador y 7-Zip portable en la PRIMERA USB (solo si no es ZIP nativo)
    if ($firstUSB) {
        if ($InstallerPath) {
            Copy-Item $InstallerPath "$($firstUSB.DriveLetter):\" -Force
        }
        if ($SevenZPath -and $CompressionType -ne "NATIVE_ZIP" -and (Test-Path $SevenZPath)) {
            Copy-Item $SevenZPath "$($firstUSB.DriveLetter):\" -Force
        }
    }

    Write-Host "`nProceso completado."
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Test-VolumeWritable',
    'Get-TargetVolume',
    'Copy-BlockWithHashCheck',
    'Copy-BlocksToUSB'
)
