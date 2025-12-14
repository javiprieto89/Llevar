# ========================================================================== #
#                   MÓDULO: SISTEMA DE ARCHIVOS                              #
# ========================================================================== #
# Propósito: Operaciones del sistema de archivos y validación de rutas
# Funciones:
#   - Test-PathWritable: Verifica si una ruta es escribible
#   - Format-FileSize: Formatea tamaño de archivo en unidades legibles
#   - Get-DirectorySize: Calcula tamaño recursivo de directorio
#   - Get-DirectoryItems: Obtiene lista de elementos de directorio con caché
# ========================================================================== #

function Test-PathWritable {
    <#
    .SYNOPSIS
        Verifica si una ruta es escribible
    .DESCRIPTION
        Comprueba si se puede escribir en un directorio local.
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

    # Si es FTP, verificar la conexi�n
    if ($false -and $Path -match '^FTP:(.+)$') {
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

# ========================================================================== #
#                       FUNCIONES DE ANÁLISIS DE ARCHIVOS                    #
# ========================================================================== #

function Format-FileSize {
    <#
    .SYNOPSIS
        Formatea un tamaño de archivo en el formato más apropiado
    .DESCRIPTION
        Convierte un tamaño en bytes al formato más legible (B, KB, MB, GB, TB)
    .PARAMETER Size
        Tamaño en bytes
    .OUTPUTS
        String con el tamaño formateado
    .EXAMPLE
        Format-FileSize -Size 1048576
        # Retorna: "1.00 MB"
    #>
    param([long]$Size)
    
    if ($Size -ge 1TB) {
        return "{0:N2} TB" -f ($Size / 1TB)
    }
    elseif ($Size -ge 1GB) {
        return "{0:N2} GB" -f ($Size / 1GB)
    }
    elseif ($Size -ge 1MB) {
        return "{0:N2} MB" -f ($Size / 1MB)
    }
    elseif ($Size -ge 1KB) {
        return "{0:N2} KB" -f ($Size / 1KB)
    }
    else {
        return "$Size B"
    }
}

# Compatibilidad: alias usado por tests y otros m�dulos
function Format-LlevarBytes {
    <#
    .SYNOPSIS
        Compatibilidad: wrapper para `Format-FileSize` usada por tests y scripts antiguos
    .DESCRIPTION
        Llama a `Format-FileSize` para devolver un string con formato legible.
    #>
    param([long]$Bytes)

    return (Format-FileSize -Size $Bytes)
}

function Get-DirectorySize {
    <#
    .SYNOPSIS
        Calcula el tamaño de un directorio recursivamente con opción de cancelar
    .DESCRIPTION
        Recorre un directorio y todos sus subdirectorios calculando el tamaño total,
        cantidad de archivos y subdirectorios. Permite cancelación mediante variable de referencia.
    .PARAMETER Path
        Ruta del directorio a analizar
    .PARAMETER Cancelled
        Variable de referencia [ref] para indicar cancelación
    .OUTPUTS
        Hashtable con Size, FileCount y DirCount
    .EXAMPLE
        $cancelled = [ref]$false
        $result = Get-DirectorySize -Path "C:\Temp" -Cancelled $cancelled
        Write-Host "Tamaño: $($result.Size) bytes, Archivos: $($result.FileCount)"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [ref]$Cancelled
    )
    
    $totalSize = 0
    $fileCount = 0
    $dirCount = 0
    
    try {
        # Obtener archivos en el directorio actual
        $files = Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            if ($Cancelled.Value) { break }
            $totalSize += $file.Length
            $fileCount++
        }
        
        # Obtener subdirectorios y calcular recursivamente
        $dirs = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $dirs) {
            if ($Cancelled.Value) { break }
            $dirCount++
            $subResult = Get-DirectorySize -Path $dir.FullName -Cancelled $Cancelled
            $totalSize += $subResult.Size
            $fileCount += $subResult.FileCount
            $dirCount += $subResult.DirCount
        }
    }
    catch {
        # Ignorar errores de acceso
    }
    
    return @{
        Size      = $totalSize
        FileCount = $fileCount
        DirCount  = $dirCount
    }
}

function Get-DirectoryItems {
    <#
    .SYNOPSIS
        Obtiene los items (archivos y carpetas) de un directorio
    .DESCRIPTION
        Lista el contenido de un directorio con información adicional para navegadores.
        Incluye soporte para caché de tamaños calculados.
    .PARAMETER Path
        Ruta del directorio
    .PARAMETER AllowFiles
        Si es $true, incluye archivos en el resultado
    .PARAMETER SizeCache
        Hashtable con caché de tamaños calculados previamente
    .OUTPUTS
        Array de objetos PSCustomObject con información de cada item
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [bool]$AllowFiles = $false,
        
        [hashtable]$SizeCache = @{}
    )
    
    $items = @()
    
    try {
        # Detectar si estamos en la raíz de una unidad (C:\, D:\, etc.)
        $isRootDrive = $Path -match '^[A-Za-z]:\\$'
        
        if ($isRootDrive) {
            # En raíz: agregar "..." para ir al selector de unidades
            $items += [PSCustomObject]@{
                Name            = "..."
                FullName        = ""
                IsDirectory     = $true
                IsParent        = $false
                IsDriveSelector = $true
                Size            = ""
                Icon            = "💾"
            }
        }
        elseif ($Path -ne "") {
            # No estamos en raíz: agregar ".." para subir
            $items += [PSCustomObject]@{
                Name            = ".."
                FullName        = Split-Path $Path -Parent
                IsDirectory     = $true
                IsParent        = $true
                IsDriveSelector = $false
                Size            = ""
                Icon            = "▲"
            }
        }
        
        # Obtener directorios
        $dirs = @(Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue | Sort-Object Name)
        foreach ($dir in $dirs) {
            # Verificar si ya calculamos el tamaño de este directorio
            $sizeDisplay = "<DIR>"
            if ($SizeCache.ContainsKey($dir.FullName)) {
                $cachedSize = $SizeCache[$dir.FullName]
                $sizeDisplay = (Format-FileSize -Size $cachedSize) + " <DIR>"
            }
            
            $items += [PSCustomObject]@{
                Name            = $dir.Name
                FullName        = $dir.FullName
                IsDirectory     = $true
                IsParent        = $false
                IsDriveSelector = $false
                Size            = $sizeDisplay
                Icon            = "📁"
                CalculatedSize  = ($SizeCache.ContainsKey($dir.FullName))
            }
        }
        
        # Obtener archivos si está permitido
        if ($AllowFiles) {
            $files = @(Get-ChildItem -LiteralPath $Path -File -Force -ErrorAction SilentlyContinue | Sort-Object Name)
            foreach ($file in $files) {
                $sizeDisplay = Format-FileSize -Size $file.Length
                $items += [PSCustomObject]@{
                    Name            = $file.Name
                    FullName        = $file.FullName
                    IsDirectory     = $false
                    IsParent        = $false
                    IsDriveSelector = $false
                    Size            = $sizeDisplay
                    Icon            = "📄"
                    CalculatedSize  = $true
                }
            }
        }
    }
    catch {
        # Si hay error accediendo al directorio, volver atrás
    }
    
    return $items
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Test-PathWritable',
    'Format-FileSize',
    'Format-LlevarBytes',
    'Get-DirectorySize',
    'Get-DirectoryItems'
)
