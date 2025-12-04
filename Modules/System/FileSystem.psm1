# ========================================================================== #
#                   MÓDULO: SISTEMA DE ARCHIVOS                              #
# ========================================================================== #
# Propósito: Operaciones del sistema de archivos y validación de rutas
# Funciones:
#   - Test-PathWritable: Verifica si una ruta es escribible
#   - Get-PathOrPrompt: Obtiene o solicita ruta al usuario
#   - Test-VolumeWritable: Verifica si un volumen es escribible
#   - Get-TargetVolume: Obtiene volumen removible adecuado
# ========================================================================== #

function Test-PathWritable {
    <#
    .SYNOPSIS
        Verifica si una ruta es escribible
    .DESCRIPTION
        Comprueba si se puede escribir en un directorio, soporta rutas FTP.
        Intenta crear el directorio si no existe y verifica permisos de escritura.
    .PARAMETER Path
        Ruta a validar
    .OUTPUTS
        Boolean - $true si es escribible, $false en caso contrario
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Si es FTP, verificar la conexión
    if ($Path -match '^FTP:(.+)$') {
        $driveName = $Matches[1]
        try {
            $ftpInfo = Get-FtpConnection -DriveName $driveName
            if ($ftpInfo) {
                Write-ColorOutput "Conexión FTP válida" -ForegroundColor Green
                return $true
            }
            else {
                Write-ColorOutput "Conexión FTP no encontrada: $driveName" -ForegroundColor Yellow
                return $false
            }
        }
        catch {
            Write-ColorOutput "Error verificando conexión FTP: $driveName" -ForegroundColor Yellow
            return $false
        }
    }

    # Asegurar que el directorio existe (o crearlo)
    if (-not (Test-Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
        catch {
            Write-ColorOutput "No se pudo crear el directorio destino: $Path" -ForegroundColor Yellow
            return $false
        }
    }

    # Verificar escritura con archivo temporal
    $testFile = Join-Path $Path "__LLEVAR_TEST__.tmp"
    try {
        "test" | Out-File -FilePath $testFile -Encoding ASCII -ErrorAction Stop
        Remove-Item $testFile -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-ColorOutput "No se puede escribir en: $Path" -ForegroundColor Yellow
        return $false
    }
}

function Get-PathOrPrompt {
    <#
    .SYNOPSIS
        Obtiene ruta o la solicita si no está definida
    .DESCRIPTION
        Si $Path está vacío, solicita al usuario seleccionar una carpeta.
        Si la ruta no existe, vuelve a solicitarla hasta obtener una válida.
    .PARAMETER Path
        Ruta opcional previa
    .PARAMETER Tipo
        Tipo de ruta (Origen/Destino) para mensajes
    .OUTPUTS
        String con la ruta validada
    #>
    param([string]$Path, [string]$Tipo)

    if (-not $Path) {
        $Path = Select-FolderDOS-Llevar "Seleccione carpeta de $Tipo"
    }

    while (-not (Test-Path $Path)) {
        Write-Host "Ruta no válida: $Path" -ForegroundColor Yellow
        $Path = Select-FolderDOS-Llevar "Seleccione carpeta de $Tipo"
    }

    return $Path
}

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

# Exportar funciones
Export-ModuleMember -Function @(
    'Test-PathWritable',
    'Get-PathOrPrompt',
    'Test-VolumeWritable',
    'Get-TargetVolume'
)
