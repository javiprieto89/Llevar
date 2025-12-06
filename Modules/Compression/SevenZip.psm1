# ============================================================================ #
# Archivo: Q:\Utilidad\LLevar\Modules\Compression\SevenZip.psm1
# Descripción: Funciones para localizar y usar 7-Zip para compresión/descompresión
# ============================================================================ #

# Asegurar dependencias UI (barra de progreso)
$modulesRoot = Split-Path $PSScriptRoot -Parent
$progressModule = Join-Path $modulesRoot "UI\ProgressBar.psm1"
if (-not (Get-Command Write-LlevarProgressBar -ErrorAction SilentlyContinue)) {
    Import-Module $progressModule -Force -Global -ErrorAction SilentlyContinue
}

function Get-SevenZipLlevar {
    <#
    .SYNOPSIS
        Localiza o descarga 7-Zip para usar en compresión
    #>
    
    # 1) Intentar ejecutar 7z desde el PATH (puede estar en variables de entorno)
    try {
        $cmd = Get-Command 7z -ErrorAction SilentlyContinue
        if ($cmd) {
            # Verificar que realmente funciona ejecutándolo
            $testResult = & $cmd.Source 2>&1
            if ($LASTEXITCODE -ne 255 -and $testResult) {
                Write-Host "7-Zip encontrado en PATH: $($cmd.Source)" -ForegroundColor Green
                return $cmd.Source
            }
        }
    }
    catch {
        # Si falla, continuar con la búsqueda en rutas
    }

    # 2) Buscar 7z/7za en el directorio del script (por si ya hay portable)
    $localCandidates = @(
        (Join-Path $PSScriptRoot "..\..\7z.exe"),
        (Join-Path $PSScriptRoot "..\..\7za.exe")
    )
    foreach ($p in $localCandidates) {
        if (Test-Path $p) { return $p }
    }

    # 3) Buscar instalación estándar
    $paths = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe"
    )

    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }

    # 4) Descargar versión portable a la carpeta del script
    Write-Host "7-Zip no encontrado. Intentando descargar versión portable..." -ForegroundColor Yellow

    try {
        $url = "https://www.7-zip.org/a/7za920.zip"
        $scriptRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $zipPath = Join-Path $scriptRoot "7za_portable.zip"
        $destExe = Join-Path $scriptRoot "7za.exe"

        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $scriptRoot, $true)

        Remove-Item $zipPath -ErrorAction SilentlyContinue

        if (Test-Path $destExe) {
            Write-Host "7-Zip portable descargado en $destExe" -ForegroundColor Green
            return $destExe
        }
        else {
            Write-Host "No se pudo extraer 7za.exe del ZIP descargado." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "No se pudo descargar 7-Zip portable: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 5) Ofrecer usar compresión nativa de Windows si está disponible
    if (Test-Windows10OrLater) {
        Write-Host ""
        Write-Host "7-Zip no está disponible, pero se detectó Windows 10 o superior." -ForegroundColor Yellow
        Write-Host "Puede usar la compresión ZIP nativa de Windows (sin soporte para contraseñas)." -ForegroundColor Yellow
        Write-Host ""
        $response = Read-Host "¿Desea usar compresión ZIP nativa? (S/N)"
        
        if ($response -match '^[SsYy]') {
            return "NATIVE_ZIP"
        }
    }

    throw "7-Zip no encontrado ni descargado. No se puede continuar."
}

function Get-SevenZip {
    <#
    .SYNOPSIS
        Versión simplificada de Get-SevenZipLlevar para usar en instaladores
    #>
    
    # 1) Intentar ejecutar 7z desde el PATH (puede estar en variables de entorno)
    try {
        $cmd = Get-Command 7z -ErrorAction SilentlyContinue
        if ($cmd) {
            # Verificar que realmente funciona
            $testResult = & $cmd.Source 2>&1
            if ($LASTEXITCODE -ne 255 -and $testResult) {
                return $cmd.Source
            }
        }
    }
    catch {
        # Si falla, continuar con la búsqueda en rutas
    }

    # 2) Buscar 7z/7za junto al INSTALAR.ps1 (en la USB)
    $localCandidates = @(
        (Join-Path $PSScriptRoot "7za.exe"),
        (Join-Path $PSScriptRoot "7z.exe")
    )
    foreach ($p in $localCandidates) {
        if (Test-Path $p) { return $p }
    }

    # 3) Buscar instalación estándar en el sistema
    $paths = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe"
    )

    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }

    Write-Host "No se encontró 7-Zip ni en la USB ni en el sistema." -ForegroundColor Yellow
    throw "No se puede continuar la instalación sin 7-Zip."
}

function Compress-Folder {
    <#
    .SYNOPSIS
        Comprime una carpeta usando 7-Zip o ZIP nativo
    #>
    param(
        $Origen, 
        $Temp, 
        $SevenZ, 
        $Clave, 
        [int]$BlockSizeMB,
        [string]$DestinoFinal = ""
    )

    $Name = Split-Path $Origen -Leaf
    
    # Verificar si se usa ZIP nativo
    if ($SevenZ -eq "NATIVE_ZIP") {
        $zipFile = Compress-WithNativeZip -Origen $Origen -Temp $Temp -Clave $Clave -DestinoFinal $DestinoFinal -BlockSizeMB $BlockSizeMB
        
        # Si BlockSizeMB > 0, dividir el ZIP en bloques
        if ($BlockSizeMB -gt 0) {
            Write-Host "`nDividiendo archivo ZIP en bloques de ${BlockSizeMB}MB..." -ForegroundColor Cyan
            $blocks = Split-IntoBlocks -File $zipFile -BlockSizeMB $BlockSizeMB -Temp $Temp
            return @{
                Files           = $blocks
                CompressionType = "NATIVE_ZIP"
                OriginalArchive = $zipFile
            }
        }
        else {
            return @{
                Files           = @($zipFile)
                CompressionType = "NATIVE_ZIP"
                OriginalArchive = $zipFile
            }
        }
    }
    
    # Proceso normal con 7-Zip
    $Out = Join-Path $Temp "$Name.7z"

    # Mostrar información de origen y destino
    Write-Host ""
    Write-Host "Comprimiendo:" -ForegroundColor Cyan
    Write-Host "  Origen:  $Origen" -ForegroundColor Gray
    Write-Host "  Destino: $(if ($DestinoFinal) { $DestinoFinal } else { $Temp })" -ForegroundColor Gray
    Write-Host "  Método:  7-Zip" -ForegroundColor Gray
    Write-Host "  Bloques: ${BlockSizeMB}MB" -ForegroundColor Gray
    Write-Host ""

    $startTime = Get-Date
    $barTop = [console]::CursorTop
    Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Compresión..." -Top $barTop

    $sevenArgs = @("a", "-t7z", "-mx=9", "-bsp1", "-bso0")
    if ($BlockSizeMB -gt 0) {
        $sevenArgs += ("-v{0}m" -f $BlockSizeMB)   # volúmenes en MB
    }
    if ($Clave) {
        $sevenArgs += ("-p$Clave")
    }
    $sevenArgs += @($Out, $Origen)

    & $SevenZ @sevenArgs 2>&1 | ForEach-Object {
        if ($_ -match '(\d+)%') {
            $pct = [double]$matches[1]
            Write-LlevarProgressBar -Percent $pct -StartTime $startTime -Label "Compresión..." -Top $barTop
        }
    }

    Write-LlevarProgressBar -Percent 100 -StartTime $startTime -Label "Compresión..." -Top $barTop

    # Sin división: un solo .7z
    if ($BlockSizeMB -le 0) {
        return @{
            Files           = @($Out)
            CompressionType = "7ZIP"
        }
    }

    # Con división: devolver los volúmenes nativos Nombre.7z.001, .002, ...
    $pattern = "$Name.7z.*"
    $volumes = Get-ChildItem -Path $Temp -Filter $pattern -File | Sort-Object Name

    if (-not $volumes -or $volumes.Count -eq 0) {
        throw "7-Zip no generó volúmenes divididos con -v${BlockSizeMB}m."
    }

    return @{
        Files           = ($volumes | Select-Object -ExpandProperty FullName)
        CompressionType = "7ZIP"
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Get-SevenZipLlevar',
    'Get-SevenZip',
    'Compress-Folder'
)
