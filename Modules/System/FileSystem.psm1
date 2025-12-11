# ========================================================================== #
#                   M�DULO: SISTEMA DE ARCHIVOS                              #
# ========================================================================== #
# Prop�sito: Operaciones del sistema de archivos y validaci�n de rutas
# Funciones:
#   - Test-PathWritable: Verifica si una ruta es escribible
#   - Format-FileSize: Formatea tama�o de archivo en unidades legibles
#   - Get-DirectorySize: Calcula tama�o recursivo de directorio
#   - Get-DirectoryItems: Obtiene lista de elementos de directorio con cach�
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
                Write-ColorOutput "Conexi�n FTP v�lida" -ForegroundColor Green
                return $true
            }
            else {
                Write-ColorOutput "Conexi�n FTP no encontrada: $driveName" -ForegroundColor Yellow
                return $false
            }
        }
        catch {
            Write-ColorOutput "Error verificando conexi�n FTP: $driveName" -ForegroundColor Yellow
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
#                       FUNCIONES DE AN�LISIS DE ARCHIVOS                    #
# ========================================================================== #

function Format-FileSize {
    <#
    .SYNOPSIS
        Formatea un tama�o de archivo en el formato m�s apropiado
    .DESCRIPTION
        Convierte un tama�o en bytes al formato m�s legible (B, KB, MB, GB, TB)
    .PARAMETER Size
        Tama�o en bytes
    .OUTPUTS
        String con el tama�o formateado
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
        Calcula el tama�o de un directorio recursivamente con opci�n de cancelar
    .DESCRIPTION
        Recorre un directorio y todos sus subdirectorios calculando el tama�o total,
        cantidad de archivos y subdirectorios. Permite cancelaci�n mediante variable de referencia.
    .PARAMETER Path
        Ruta del directorio a analizar
    .PARAMETER Cancelled
        Variable de referencia [ref] para indicar cancelaci�n
    .OUTPUTS
        Hashtable con Size, FileCount y DirCount
    .EXAMPLE
        $cancelled = [ref]$false
        $result = Get-DirectorySize -Path "C:\Temp" -Cancelled $cancelled
        Write-Host "Tama�o: $($result.Size) bytes, Archivos: $($result.FileCount)"
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
        Lista el contenido de un directorio con informaci�n adicional para navegadores.
        Incluye soporte para cach� de tama�os calculados.
    .PARAMETER Path
        Ruta del directorio
    .PARAMETER AllowFiles
        Si es $true, incluye archivos en el resultado
    .PARAMETER SizeCache
        Hashtable con cach� de tama�os calculados previamente
    .OUTPUTS
        Array de objetos PSCustomObject con informaci�n de cada item
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [bool]$AllowFiles = $false,
        
        [hashtable]$SizeCache = @{}
    )
    
    $items = @()
    
    try {
        # Detectar si estamos en la ra�z de una unidad (C:\, D:\, etc.)
        $isRootDrive = $Path -match '^[A-Za-z]:\\$'
        
        if ($isRootDrive) {
            # En ra�z: agregar "..." para ir al selector de unidades
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
            # No estamos en ra�z: agregar ".." para subir
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
        $dirs = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue | Sort-Object Name
        foreach ($dir in $dirs) {
            # Verificar si ya calculamos el tama�o de este directorio
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
                Icon            = "�"
                CalculatedSize  = ($SizeCache.ContainsKey($dir.FullName))
            }
        }
        
        # Obtener archivos si est� permitido
        if ($AllowFiles) {
            $files = Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue | Sort-Object Name
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
        # Si hay error accediendo al directorio, volver atr�s
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
