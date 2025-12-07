# ============================================================================ #
# Archivo: Q:\Utilidad\LLevar\Modules\Compression\BlockSplitter.psm1
# Descripción: Funciones para dividir/reconstruir archivos en bloques
# ============================================================================ #

function Split-IntoBlocks {
    <#
    .SYNOPSIS
        Divide un archivo grande en bloques numerados
    #>
    param(
        $File, 
        $BlockSizeMB, 
        $Temp
    )

    $Name = [System.IO.Path]::GetFileNameWithoutExtension($File)
    $fs = [System.IO.File]::OpenRead($File)

    $BlockSize = $BlockSizeMB * 1MB
    $buffer = New-Object byte[] $BlockSize

    $counter = 1
    $totalRead = 0L
    $totalLength = $fs.Length
    $startTime = Get-Date
    $barTop = [console]::CursorTop
    Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Dividiendo en bloques..." -Top $barTop

    $blocks = @()

    while (($read = $fs.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $totalRead += $read
        if ($totalLength -gt 0) {
            $pct = [double](($totalRead * 100.0) / $totalLength)
            Write-LlevarProgressBar -Percent $pct -StartTime $startTime -Label "Dividiendo en bloques..." -Top $barTop
        }

        $num = "{0:D4}" -f $counter
        $OutFile = Join-Path $Temp "$Name.alx$num"
        $blocks += $OutFile

        $out = [System.IO.File]::OpenWrite($OutFile)
        $out.Write($buffer, 0, $read)
        $out.Close()

        $counter++
    }

    $fs.Close()
    Write-LlevarProgressBar -Percent 100 -StartTime $startTime -Label "Dividiendo en bloques..." -Top $barTop
    return $blocks
}

function Join-FromBlocks {
    <#
    .SYNOPSIS
        Reconstruye un archivo desde bloques numerados
    #>
    param(
        [string[]]$Blocks,
        [string]$OutputFile
    )

    $startTime = Get-Date
    $barTop = [console]::CursorTop
    Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Reconstruyendo archivo..." -Top $barTop

    $outputStream = [System.IO.File]::OpenWrite($OutputFile)
    $totalBlocks = $Blocks.Count
    $currentBlock = 0

    try {
        foreach ($block in $Blocks) {
            if (-not (Test-Path $block)) {
                throw "Bloque no encontrado: $block"
            }

            $inputStream = [System.IO.File]::OpenRead($block)
            $inputStream.CopyTo($outputStream)
            $inputStream.Close()

            $currentBlock++
            $pct = [double](($currentBlock * 100.0) / $totalBlocks)
            Write-LlevarProgressBar -Percent $pct -StartTime $startTime -Label "Reconstruyendo archivo..." -Top $barTop
        }
    }
    finally {
        $outputStream.Close()
    }

    Write-LlevarProgressBar -Percent 100 -StartTime $startTime -Label "Reconstruyendo archivo..." -Top $barTop
    Write-Host "`nArchivo reconstruido: $OutputFile" -ForegroundColor Green
}

function Get-BlocksFromUnit {
    <#
    .SYNOPSIS
        Detecta bloques en una unidad (USB, carpeta, etc.)
    #>
    param([string]$Path)

    Get-ChildItem $Path -File |
    Where-Object {
        $_.Name -match '\.7z($|\.)' -or $_.Name -match '\.\d{3}$' -or $_.Name -match '\.alx\d{4}$' -or $_.Name -match '\.zip$'
    } |
    Sort-Object Name |
    Select-Object -ExpandProperty FullName
}

function Request-NextUnit {
    <#
    .SYNOPSIS
        Solicita insertar la siguiente unidad USB con bloques faltantes
    #>
    param([string]$ExpectedBlock)

    Write-Host ""
    Write-Host "Falta el bloque: $ExpectedBlock" -ForegroundColor Yellow
    Write-Host "Inserte la unidad que lo contiene."
    Read-Host "ENTER cuando esté lista"

    $usb = $null
    while (-not $usb) {
        $usb = Get-Volume |
        Where-Object { $_.DriveType -eq 'Removable' } |
        Select-Object -First 1
        if (-not $usb) {
            Write-Host "No se detecta USB." -ForegroundColor Yellow
            Start-Sleep 2
        }
    }

    return "$($usb.DriveLetter):\"
}

function Get-AllBlocks {
    <#
    .SYNOPSIS
        Recopila todos los bloques de múltiples unidades USB
    #>
    param($InitialPath)

    $blocks = @{}
    $unit = $InitialPath

    while ($true) {

        $current = Get-BlocksFromUnit $unit
        foreach ($c in $current) {
            $name = Split-Path $c -Leaf
            $blocks[$name] = $c
        }

        # ¿Está __EOF__ aquí?
        if (Test-Path (Join-Path $unit "__EOF__")) {
            break
        }

        # Determinar el siguiente bloque esperado
        $sortedKeys = $blocks.Keys | Sort-Object
        if ($sortedKeys.Count -eq 0) {
            Write-Host "No se encontraron bloques en la unidad actual." -ForegroundColor Yellow
            $unit = Request-NextUnit "primer bloque"
            continue
        }

        $lastBlock = $sortedKeys[-1]
        
        # Inferir el siguiente bloque esperado basado en el patrón
        if ($lastBlock -match '\.alx(\d{4})$') {
            $num = [int]$matches[1]
            $nextNum = $num + 1
            $nextBlock = $lastBlock -replace '\.alx\d{4}$', ('.alx{0:D4}' -f $nextNum)
        }
        elseif ($lastBlock -match '\.7z\.(\d{3})$') {
            $num = [int]$matches[1]
            $nextNum = $num + 1
            $nextBlock = $lastBlock -replace '\.7z\.\d{3}$', ('.7z.{0:D3}' -f $nextNum)
        }
        elseif ($lastBlock -match '\.(\d{3})$') {
            $num = [int]$matches[1]
            $nextNum = $num + 1
            $nextBlock = $lastBlock -replace '\.\d{3}$', ('.{0:D3}' -f $nextNum)
        }
        else {
            # No se puede determinar el patrón, asumir que está completo
            break
        }

        # Verificar si el siguiente bloque esperado existe en la unidad actual
        $nextBlockPath = Join-Path $unit $nextBlock
        if (Test-Path $nextBlockPath) {
            # El bloque existe pero no fue detectado, agregarlo
            $blocks[$nextBlock] = $nextBlockPath
            continue
        }
        
        # Si estamos en una carpeta local (no USB), no hay más bloques
        # Detectar si es carpeta local verificando si no es unidad removible
        try {
            $driveLetter = Split-Path $unit -Qualifier
            if ($driveLetter) {
                $volume = Get-Volume -DriveLetter $driveLetter.Replace(":", "") -ErrorAction SilentlyContinue
                if (-not $volume -or $volume.DriveType -ne 'Removable') {
                    # Es carpeta local, no hay más bloques
                    Write-Host "Todos los bloques detectados ($($blocks.Count))" -ForegroundColor Green
                    break
                }
            }
        }
        catch {
            # Error al detectar tipo de unidad, asumir local
            break
        }
        
        # Solicitar siguiente unidad (solo para medios removibles)
        $unit = Request-NextUnit $nextBlock
    }

    return $blocks
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Split-IntoBlocks',
    'Join-FromBlocks',
    'Get-BlocksFromUnit',
    'Request-NextUnit',
    'Get-AllBlocks'
)
