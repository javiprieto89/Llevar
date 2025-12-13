# ========================================================================== #
#                   MÓDULO: GENERADOR DE SCRIPT INSTALADOR                   #
# ========================================================================== #
# Propósito: Generar script INSTALAR.ps1 para USBs con contenido comprimido
# Funciones:
#   - New-InstallerScript: Genera INSTALAR.ps1 personalizado
# ========================================================================== #

# Importar dependencias
$ModulesPath = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $ModulesPath "Compression\BlockSplitter.psm1") -Force -Global

# ========================================================================== #
#                    PLANTILLA DEL INSTALADOR (EMBUTIDA)                     #
# ========================================================================== #

$script:InstallerBaseScript = @'
<#
INSTALAR.ps1  
Reconstruye bloques <Nombre>.alx0001 .  
Recrea archivo .7z  
Descomprime carpeta original  
Logs solo en caso de error: %TEMP%\INSTALAR_ERROR.log
#>

param(
    [string]$Destino
)

# Si no se especificó destino, usar el directorio actual de ejecución
if (-not $Destino) {
    if ($script:DefaultDestino) {
        $Destino = $script:DefaultDestino
    }
    else {
        # Usar el directorio actual desde donde se ejecuta el script
        $Destino = Get-Location | Select-Object -ExpandProperty Path
    }
}

# ========================================================================== #
#                          LOG Y MANEJO DE ERRORES                           #
# ========================================================================== #

$Global:LogFile = Join-Path $env:TEMP "INSTALAR_ERROR.log"

function Write-ErrorLog {
    param($Message, $ErrorRecord)

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $Global:LogFile ""
    Add-Content $Global:LogFile "[$time] ERROR: $Message"

    if ($ErrorRecord) {
        Add-Content $Global:LogFile "Línea: $($ErrorRecord.InvocationInfo.ScriptLineNumber)"
        Add-Content $Global:LogFile "Columna: $($ErrorRecord.InvocationInfo.OffsetInLine)"
        Add-Content $Global:LogFile "CallStack: $($ErrorRecord.InvocationInfo.PositionMessage)"
    }
}

# ========================================================================== #
#                           EXPLORADOR DOS CL�SICO                           #
# ========================================================================== #

function Select-FolderDOS {
    param([string]$Prompt)

    Write-Host ""
    Write-Host "=== $Prompt ===" -ForegroundColor Cyan

    $drives = Get-PSDrive -PSProvider FileSystem

    while ($true) {

        Write-Host ""
        Write-Host "Seleccione una unidad:"
        $i = 1
        foreach ($d in $drives) {
            Write-Host " [$i] $($d.Root)"
            $i++
        }
        Write-Host " [0] Cancelar"

        $sel = Read-Host "Opción"
        if ($sel -eq "0") { return $null }

        if ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $drives.Count) {
            $drive = $drives[[int]$sel - 1].Root

            while ($true) {
                Write-Host ""
                Write-Host "Contenido de $drive"
                $items = Get-ChildItem $drive -Directory -ErrorAction SilentlyContinue
                $j = 1
                foreach ($it in $items) {
                    Write-Host " [$j] $($it.Name)"
                    $j++
                }
                Write-Host " [..] Volver"
                Write-Host " [.] Seleccionar esta carpeta"

                $op = Read-Host "Opción"
                if ($op -eq '.') { return $drive }
                if ($op -eq '..') { break }

                if ($op -match '^\d+$' -and [int]$op -ge 1 -and [int]$op -le $items.Count) {
                    $drive = $items[[int]$op - 1].FullName
                }
            }
        }
    }
}

# ========================================================================== #
#                        DETECTAR VERSIÓN DE WINDOWS                         #
# ========================================================================== #

# Test-Windows10OrLater ahora está en Modules/Core/Validation.psm1

# Compress-WithNativeZip ahora está en Modules/Compression/NativeZip.psm1

# Get-SevenZip ahora está en Modules/Compression/SevenZip.psm1

# ========================================================================== #
#                          RECONSTRUIR ARCHIVO .7Z                           #
# ========================================================================== #

function Restore-7z {
    param($Blocks, $Temp)

    # Para volúmenes nativos de 7-Zip no hay que reconstruir nada;
    # simplemente devolver la ruta del primer volumen.
    $firstKey = ($Blocks.Keys | Sort-Object)[0]
    return $Blocks[$firstKey]
}

# ========================================================================== #
#                                DESCOMPRIMIR                                #
# ========================================================================== #

function Expand-7z {
    param($SevenZ, $Destino, $7z)

    Write-Host "Descomprimiendo..." -ForegroundColor Cyan
    & $7z x $SevenZ "-o$Destino" -y | Out-Null
    Write-Host "Completado." -ForegroundColor Green
}

function Expand-NativeZip {
    param($ZipFile, $Destino)

    Write-Host "Descomprimiendo con ZIP nativo de Windows..." -ForegroundColor Cyan
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $Destino, $true)
        Write-Host "Completado." -ForegroundColor Green
    }
    catch {
        Write-Host "Error al descomprimir ZIP: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# ========================================================================== #
#                     RECONSTRUIR ZIP DESDE BLOQUES .alx                     #
# ========================================================================== #

function Restore-ZipFromBlocks {
    param($blocks, $Temp)

    Write-Host "Reconstruyendo archivo ZIP desde bloques..." -ForegroundColor Cyan
    
    $sorted = $blocks.Keys | Sort-Object
    $first = $sorted[0]
    
    # Determinar nombre base
    if ($first -match '^(?<name>.+)\.alx\d+$') {
        $baseName = $matches['name']
    }
    else {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($first)
    }
    
    $zipOutput = Join-Path $Temp "$baseName.zip"
    $outStream = [System.IO.File]::Create($zipOutput)
    
    $totalBlocks = $sorted.Count
    $current = 0
    
    foreach ($blockName in $sorted) {
        $current++
        $blockPath = $blocks[$blockName]
        
        Write-Host "Copiando bloque $current de $totalBlocks : $blockName" -ForegroundColor Gray
        
        if (-not (Test-Path $blockPath)) {
            $outStream.Close()
            throw "Falta el bloque: $blockName"
        }
        
        try {
            $inStream = [System.IO.File]::OpenRead($blockPath)
            $inStream.CopyTo($outStream)
            $inStream.Close()
        }
        catch {
            $outStream.Close()
            throw "Error al copiar bloque $blockName : $($_.Exception.Message)"
        }
    }
    
    $outStream.Close()
    Write-Host "Archivo ZIP reconstruido: $zipOutput" -ForegroundColor Green
    return $zipOutput
}

# ========================================================================== #
#                         MANEJAR CARPETA EXISTENTE                          #
# ========================================================================== #

function Resolve-ExistingFolder {
    param($Destino, $FolderName)

    $target = Join-Path $Destino $FolderName

    if (-not (Test-Path $target)) { return $target }

    Write-Host "La carpeta $FolderName ya existe." -ForegroundColor Yellow
    Write-Host "[1] Sobrescribir todo"
    Write-Host "[2] Sobrescribir solo más nuevos"
    Write-Host "[3] Elegir otra carpeta"
    Write-Host "[4] Cancelar"

    $opt = Read-Host "Opción"
    switch ($opt) {
        "1" { return $target }
        "2" { return $target } # la lógica se aplica al descomprimir
        "3" {
            $nuevo = Select-FolderDOS "Seleccione nuevo destino"
            return "$nuevo\$FolderName"
        }
        "4" { throw "Instalación cancelada" }
        default { return $target }
    }
}

# ========================================================================== #
#                       FLUJO PRINCIPAL DEL INSTALADOR                       #
# ========================================================================== #

try {

    # Determinar unidad de origen
    $myPath = $PSScriptRoot + "\"
    Write-Host "Buscando bloques en $myPath"

    $blocks = Get-AllBlocks $myPath

    if ($blocks.Count -eq 0) { throw "No hay bloques de archivo comprimido." }

    # Determinar nombre base (sin extensión de volumen)
    $first = ($blocks.Keys | Sort-Object)[0]
    if ($first -match '^(?<n>.+)\.(?<ext>7z|\d{3})$') {
        $FolderName = $matches['n']
    }
    else {
        $FolderName = [System.IO.Path]::GetFileNameWithoutExtension($first)
    }

    # Determinar destino
    # Ya viene configurado desde el bloque param() con fallback al directorio actual
    
    if (-not (Test-Path $Destino)) {
        Write-Host "Destino no existe. Creando..."
        New-Item -ItemType Directory -Path $Destino -Force | Out-Null
    }

    # Manejar carpeta existente
    $Destino = Resolve-ExistingFolder $Destino $FolderName

    # Crear temporales
    $Temp = Join-Path $env:TEMP "INSTALAR_TEMP"
    if (Test-Path $Temp) { Remove-Item $Temp -Recurse -Force }
    New-Item -ItemType Directory -Path $Temp | Out-Null

    # Verificar tipo de compresión (por defecto 7ZIP si no está definido)
    if (-not $script:CompressionType) {
        $script:CompressionType = "7ZIP"
    }

    Write-Host "Tipo de compresión detectado: $script:CompressionType" -ForegroundColor Cyan

    if ($script:CompressionType -eq "NATIVE_ZIP") {
        # Flujo para ZIP nativo
        Write-Host "Procesando archivo comprimido con ZIP nativo de Windows..." -ForegroundColor Cyan
        
        # Reconstruir ZIP desde bloques .alx
        $zipFull = Restore-ZipFromBlocks $blocks $Temp
        
        # Descomprimir con ZIP nativo
        Expand-NativeZip $zipFull $Destino
    }
    else {
        # Flujo para 7-Zip (por defecto)
        # Reconstruir 7z
        $SevenZFull = Restore-7z $blocks $Temp

        # Detectar 7z
        $7z = Get-7z

        # Descomprimir
        Expand-7z $SevenZFull $Destino $7z
    }

    # Limpieza
    Remove-Item $Temp -Recurse -Force

    Write-Host "`n✓ Instalación completada."
}
catch {
    Write-ErrorLog "Error en instalación" $_
    Write-Host "Ocurrió un error. Revise el log en $Global:LogFile" -ForegroundColor Red
}
'@

function New-InstallerScript {
    <#
    .SYNOPSIS
        Genera script INSTALAR.ps1 con destino y tipo de compresión configurados
    .DESCRIPTION
        Toma el template $InstallerBaseScript y lo modifica para incluir:
        - Destino predeterminado
        - Tipo de compresión (7ZIP o NATIVE_ZIP)
        - Función Get-SevenZip mejorada
    .PARAMETER Destino
        Ruta de destino predeterminada para la instalación
    .PARAMETER Temp
        Carpeta temporal donde se generará INSTALAR.ps1
    .PARAMETER CompressionType
        Tipo de compresión usado: "7ZIP" o "NATIVE_ZIP"
    .OUTPUTS
        String con ruta completa al INSTALAR.ps1 generado
    #>
    param(
        [string]$Destino,
        
        [Parameter(Mandatory = $true)]
        [string]$Temp,
        
        [string]$CompressionType = "7ZIP"
    )
    
    # Dividir template en líneas
    $lines = $script:InstallerBaseScript -split "`r?`n"
    
    # Buscar bloque param()
    $paramStart = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*param\(') {
            $paramStart = $i
            break
        }
    }
    
    # Si no hay param(), retornar script sin modificar
    if ($null -eq $paramStart) {
        $installerPath = Join-Path $Temp "Instalar.ps1"
        Set-Content -Path $installerPath -Value $lines -Encoding UTF8
        return $installerPath
    }
    
    # Encontrar fin del bloque param()
    $paramEnd = $paramStart
    while ($paramEnd -lt ($lines.Count - 1) -and $lines[$paramEnd] -notmatch '^\s*\)') {
        $paramEnd++
    }
    $insertIndex = $paramEnd + 1
    
    # Preparar línea de destino predeterminado
    $insertLine = "# Destino por defecto no especificado"
    if ($Destino) {
        $escaped = $Destino -replace "'", "''"
        $insertLine = "`$script:DefaultDestino = '$escaped'"
    }
    
    # Dividir en antes/después del punto de inserción
    $before = @()
    if ($insertIndex -gt 0) {
        $before = $lines[0..($insertIndex - 1)]
    }
    
    $after = @()
    if ($insertIndex -lt $lines.Count) {
        $after = $lines[$insertIndex..($lines.Count - 1)]
    }
    
    # Reconstruir con línea de destino
    $newLines = $before + $insertLine + $after
    
    # Agregar variable de tipo de compresión
    $compressionLine = "`$script:CompressionType = '$CompressionType'"
    $newLines = $newLines[0..($insertIndex)] + $compressionLine + $newLines[($insertIndex + 1)..($newLines.Count - 1)]
    
    # Inyectar función Get-SevenZip ANTES de las funciones que la usan
    # Buscar la línea "# Get-SevenZip ahora está en Modules..." para insertar después
    $get7zInsertIndex = -1
    for ($i = 0; $i -lt $newLines.Count; $i++) {
        if ($newLines[$i] -match "# Get-SevenZip ahora está en Modules") {
            $get7zInsertIndex = $i + 1
            break
        }
    }
    
    if ($get7zInsertIndex -gt 0) {
        $get7zPatch = @'

# ========================================================================== #
#                 FUNCIÓN Get-SevenZip MEJORADA (INYECTADA)                 #
# ========================================================================== #
function Get-SevenZip {
    <#
    .SYNOPSIS
        Busca 7-Zip en múltiples ubicaciones o lo descarga si es necesario
    .DESCRIPTION
        1. Busca en PATH del sistema
        2. Busca junto al script INSTALAR.ps1 (USB)
        3. Busca en instalaciones estándar (C:\Program Files)
        4. Descarga versión portable si no se encuentra
    #>
    
    # 1) Intentar ejecutar 7z desde el PATH
    try {
        $cmd = Get-Command 7z -ErrorAction SilentlyContinue
        if ($cmd) {
            # Verificar que funciona
            $testResult = & $cmd.Source 2>&1
            if ($LASTEXITCODE -ne 255 -and $testResult) {
                return $cmd.Source
            }
        }
    }
    catch {
        # Continuar con búsqueda en rutas
    }
    
    # 2) Buscar 7z/7za junto al INSTALAR.ps1 (en USB)
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
    
    # 4) Descargar versión portable a carpeta TEMP local
    Write-Host "7-Zip no encontrado. Descargando versión portable..." -ForegroundColor Yellow
    
    try {
        $url = "https://www.7-zip.org/a/7za920.zip"
        $tempRoot = Join-Path $env:TEMP "INSTALAR_7ZIP"
        if (-not (Test-Path $tempRoot)) {
            New-Item -ItemType Directory -Path $tempRoot | Out-Null
        }
        
        $zipPath = Join-Path $tempRoot "7za_portable.zip"
        $destExe = Join-Path $tempRoot "7za.exe"
        
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempRoot, $true)
        
        Remove-Item $zipPath -ErrorAction SilentlyContinue
        
        if (Test-Path $destExe) {
            Write-Host "7-Zip portable descargado: $destExe" -ForegroundColor Green
            return $destExe
        }
        else {
            Write-Host "No se pudo extraer 7za.exe del ZIP descargado" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "No se pudo descargar 7-Zip portable: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    throw "7-Zip no encontrado ni descargado. No se puede continuar la instalación."
}
'@ -split "`r?`n"
    
        # Agregar función Get-SevenZip justo después del comentario (dividir en líneas)
        $get7zLines = $get7zPatch -split "`r?`n"
        $before = $newLines[0..($get7zInsertIndex - 1)]
        $after = $newLines[$get7zInsertIndex..($newLines.Count - 1)]
        $newLines = $before + $get7zLines + $after
    }
    
    # Guardar archivo INSTALAR.ps1
    $installerPath = Join-Path $Temp "Instalar.ps1"
    Set-Content -Path $installerPath -Value $newLines -Encoding UTF8
    
    Write-Log "Script INSTALAR.ps1 generado: $installerPath" "INFO"
    Write-Log "  Destino: $(if ($Destino) { $Destino } else { 'No especificado' })" "INFO"
    Write-Log "  Compresión: $CompressionType" "INFO"
    
    return $installerPath
}

# Exportar funciones
Export-ModuleMember -Function @(
    'New-InstallerScript'
)
