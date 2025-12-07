# ============================================================================ #
# Archivo: Q:\Utilidad\LLevar\Modules\Compression\NativeZip.psm1
# Descripción: Funciones para compresión/descompresión con ZIP nativo de Windows
# ============================================================================ #

function Compress-WithNativeZip {
    <#
    .SYNOPSIS
        Comprime una carpeta usando la API nativa de ZIP de Windows
    #>
    param(
        [string]$Origen,
        [string]$Temp,
        [string]$Clave,
        [string]$DestinoFinal = "",
        [int]$BlockSizeMB = 0
    )

    if (-not (Test-Windows10OrLater)) {
        throw "La compresión nativa requiere Windows 10 o superior."
    }

    $Name = Split-Path $Origen -Leaf
    $zipFile = Join-Path $Temp "$Name.zip"

    # Mostrar información de origen y destino
    Write-Host ""
    Write-Host "Comprimiendo:" -ForegroundColor Cyan
    Write-Host "  Origen:  $Origen" -ForegroundColor Gray
    Write-Host "  Destino: $(if ($DestinoFinal) { $DestinoFinal } else { $Temp })" -ForegroundColor Gray
    Write-Host "  Método:  ZIP Nativo (Windows)" -ForegroundColor Gray
    Write-Host "  Bloques: ${BlockSizeMB}MB" -ForegroundColor Gray
    Write-Host ""

    $startTime = Get-Date
    $barTop = [console]::CursorTop
    Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Compresión ZIP..." -Top $barTop

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        # Si hay clave, mostrar advertencia
        if ($Clave) {
            Write-Host "ADVERTENCIA: ZIP nativo de Windows no soporta encriptación con contraseña." -ForegroundColor Yellow
            Write-Host "El archivo se comprimirá SIN protección de contraseña." -ForegroundColor Yellow
        }

        # Comprimir con progreso simulado
        $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
        [System.IO.Compression.ZipFile]::CreateFromDirectory($Origen, $zipFile, $compressionLevel, $false)
        
        Write-LlevarProgressBar -Percent 100 -StartTime $startTime -Label "Compresión ZIP..." -Top $barTop
        Write-Host "`nCompresión completada: $zipFile" -ForegroundColor Green
        
        return $zipFile
    }
    catch {
        Write-Host "Error al comprimir con ZIP nativo: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Expand-WithNativeZip {
    <#
    .SYNOPSIS
        Descomprime un archivo ZIP usando la API nativa de Windows
    #>
    param(
        [string]$ZipFile,
        [string]$Destination
    )

    if (-not (Test-Windows10OrLater)) {
        throw "La descompresión nativa requiere Windows 10 o superior."
    }

    Write-Host "Descomprimiendo con ZIP nativo de Windows..." -ForegroundColor Cyan
    $startTime = Get-Date
    $barTop = [console]::CursorTop
    Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Descompresión ZIP..." -Top $barTop

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        # Descomprimir
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $Destination, $true)
        
        Write-LlevarProgressBar -Percent 100 -StartTime $startTime -Label "Descompresión ZIP..." -Top $barTop
        Write-Host "`nDescompresión completada: $Destination" -ForegroundColor Green
    }
    catch {
        Write-Host "Error al descomprimir con ZIP nativo: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Compress-WithNativeZip',
    'Expand-WithNativeZip'
)
